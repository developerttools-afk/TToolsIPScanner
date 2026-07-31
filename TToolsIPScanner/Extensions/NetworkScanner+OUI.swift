import Foundation

extension NetworkScanner {
    private var ouiCacheFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = support.appendingPathComponent("TToolsIPScanner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("oui-cache.json")
    }
    
    private var ouiTimestampFileURL: URL {
        ouiCacheFileURL.deletingLastPathComponent().appendingPathComponent("oui-cache-timestamp.json")
    }
    
    func loadOUIDatabase() {
        if let cached = loadOUICacheFromDisk() {
            ouiDatabaseTimestamp = cached.timestamp
            let age = Date().timeIntervalSince(cached.timestamp)
            isOUIDatabaseValid = age < ouiDatabaseValidityDuration
            
            if isOUIDatabaseValid {
                ouiDatabase = cached.database
                ouiDatabaseCount = cached.database.count
                log("Loaded \(cached.database.count) OUI entries from cache (age: \(Int(age/86400)) days)")
                return
            } else {
                log("OUI cache expired (\(Int(age/86400)) days old)")
            }
        }
        
        // Migrate legacy UserDefaults cache once, then clear it.
        migrateLegacyOUIUserDefaultsCache()
        if !ouiDatabase.isEmpty, isOUIDatabaseValid {
            return
        }
        
        loadLocalOUIDatabase()
    }
    
    func updateOUIDatabase(useFullList: Bool = false) {
        isUpdatingOUI = true
        log("Starte OUI-Datenbank Update...")
        
        let urlString = useFullList
            ? "https://standards-oui.ieee.org/oui/oui.txt"
            : "https://gitlab.com/wireshark/wireshark/-/raw/master/manuf"
        
        guard let url = URL(string: urlString) else {
            log("Ungültige URL")
            isUpdatingOUI = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.log("Fehler beim Download: \(error.localizedDescription)")
                    self.isUpdatingOUI = false
                }
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.log("Keine Daten empfangen")
                    self.isUpdatingOUI = false
                }
                return
            }
            
            var database = OUIParser.parse(content: content)
            database.merge(NetworkConstants.additionalOUIs) { current, _ in current }
            
            DispatchQueue.main.async {
                self.ouiDatabase = database
                self.ouiDatabaseCount = database.count
                self.ouiDatabaseTimestamp = Date()
                self.isOUIDatabaseValid = true
                self.persistOUICache(database: database, timestamp: Date())
                self.log("OUI-Datenbank aktualisiert (\(database.count) Einträge)")
                self.isUpdatingOUI = false
            }
        }.resume()
    }
    
    private func loadLocalOUIDatabase() {
        if let path = Bundle.main.path(forResource: "oui", ofType: "txt"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            let database = OUIParser.parse(content: content)
            ouiDatabase = database
            ouiDatabaseCount = database.count
            log("Lokale OUI-Datenbank geladen (\(database.count) Einträge)")
        }
    }
    
    func clearOUICache() {
        try? FileManager.default.removeItem(at: ouiCacheFileURL)
        try? FileManager.default.removeItem(at: ouiTimestampFileURL)
        UserDefaults.standard.removeObject(forKey: "ouiDatabase")
        UserDefaults.standard.removeObject(forKey: ouiDatabaseTimestampKey)
        ouiDatabase.removeAll()
        ouiDatabaseCount = 0
        ouiDatabaseTimestamp = nil
        isOUIDatabaseValid = false
        loadLocalOUIDatabase()
        log("OUI-Cache gelöscht")
    }
    
    private func persistOUICache(database: [String: String], timestamp: Date) {
        guard let data = try? JSONEncoder().encode(database) else { return }
        try? data.write(to: ouiCacheFileURL, options: .atomic)
        if let ts = try? JSONEncoder().encode(timestamp) {
            try? ts.write(to: ouiTimestampFileURL, options: .atomic)
        }
    }
    
    private func loadOUICacheFromDisk() -> (database: [String: String], timestamp: Date)? {
        guard let data = try? Data(contentsOf: ouiCacheFileURL),
              let database = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        
        let timestamp: Date
        if let tsData = try? Data(contentsOf: ouiTimestampFileURL),
           let decoded = try? JSONDecoder().decode(Date.self, from: tsData) {
            timestamp = decoded
        } else {
            timestamp = Date.distantPast
        }
        
        return (database, timestamp)
    }
    
    private func migrateLegacyOUIUserDefaultsCache() {
        let legacyKey = "ouiDatabase"
        guard let savedData = UserDefaults.standard.data(forKey: legacyKey),
              let timestamp = UserDefaults.standard.object(forKey: ouiDatabaseTimestampKey) as? Date,
              let savedDatabase = try? JSONDecoder().decode([String: String].self, from: savedData) else {
            return
        }
        
        let age = Date().timeIntervalSince(timestamp)
        if age < ouiDatabaseValidityDuration {
            ouiDatabase = savedDatabase
            ouiDatabaseCount = savedDatabase.count
            ouiDatabaseTimestamp = timestamp
            isOUIDatabaseValid = true
            persistOUICache(database: savedDatabase, timestamp: timestamp)
        }
        
        UserDefaults.standard.removeObject(forKey: legacyKey)
        UserDefaults.standard.removeObject(forKey: ouiDatabaseTimestampKey)
    }
}
