import Foundation

extension NetworkScanner {
    nonisolated static let wiresharkManufURL = "https://www.wireshark.org/download/automated/data/manuf"
    nonisolated static let ieeeOuiURL = "https://standards-oui.ieee.org/oui/oui.txt"
    nonisolated static let ouiDownloadUserAgent = "TToolsIPScanner/1.36 (Macintosh; network scanner OUI update)"
    nonisolated static let minimumOUIEntries = 10_000
    
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
        if let cached = loadOUICacheFromDisk(), !cached.database.isEmpty {
            applyOUIDatabase(cached.database, timestamp: cached.timestamp, persist: false)
            let age = Date().timeIntervalSince(cached.timestamp)
            let fresh = age < ouiDatabaseValidityDuration && cached.database.count > Self.minimumOUIEntries
            isOUIDatabaseValid = fresh
            if !fresh || cached.database.count < 5_000 {
                updateOUIDatabase(useFullList: false)
            }
            return
        }
        
        if migrateLegacyOUIUserDefaultsCache() {
            return
        }
        
        loadLocalOUIDatabase()
    }
    
    func updateOUIDatabase(useFullList: Bool = false) {
        isUpdatingOUI = true
        ouiUpdateError = nil
        log("Starte OUI-Datenbank Update...")
        
        let urlString = useFullList ? Self.ieeeOuiURL : Self.wiresharkManufURL
        guard let url = URL(string: urlString) else {
            noteOUIFailure("Letztes Update fehlgeschlagen: ungültige URL", error: .ouiDatabaseCorrupted)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(Self.ouiDownloadUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 90
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            
            if let error {
                Task { @MainActor in
                    self.noteOUIFailure(
                        "Letztes Update fehlgeschlagen: \(error.localizedDescription)",
                        error: .ouiDatabaseLoadFailed(underlying: error)
                    )
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let statusCode = httpResponse.statusCode
                Task { @MainActor in
                    self.noteOUIFailure(
                        "Letztes Update fehlgeschlagen: \(statusCode)",
                        error: .ouiDatabaseDownloadFailed(statusCode: statusCode)
                    )
                }
                return
            }
            
            guard let data,
                  let content = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                Task { @MainActor in
                    self.noteOUIFailure(
                        "Letztes Update fehlgeschlagen: Kodierung",
                        error: .ouiDatabaseCorrupted
                    )
                }
                return
            }
            
            let parsed = OUIParser.parse(content: content)
            guard parsed.count > Self.minimumOUIEntries else {
                let count = parsed.count
                Task { @MainActor in
                    self.noteOUIFailure(
                        "Letztes Update fehlgeschlagen: nur \(count) Einträge",
                        error: .ouiDatabaseCorrupted
                    )
                }
                return
            }
            
            var database = parsed
            database.merge(NetworkConstants.additionalOUIs) { current, _ in current }
            let timestamp = Date()
            
            Task { @MainActor in
                self.applyOUIDatabase(database, timestamp: timestamp, persist: true)
                self.isOUIDatabaseValid = true
                self.ouiUpdateError = nil
                self.clearOUIRelatedScanError()
                self.reassignManufacturers()
                self.log("OUI-Datenbank aktualisiert (\(database.count) Einträge)")
                self.isUpdatingOUI = false
            }
        }.resume()
    }
    
    private func loadLocalOUIDatabase(startUpdate: Bool = true) {
        var database: [String: String] = [:]
        if let path = Bundle.main.path(forResource: "oui", ofType: "txt"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            database = OUIParser.parse(content: content)
        }
        database.merge(NetworkConstants.additionalOUIs) { current, _ in current }
        ouiDatabase = database
        ouiDatabaseCount = database.count
        isOUIDatabaseValid = false
        #if DEBUG
        print("Local OUI database: \(database.count) entries")
        #endif
        
        if startUpdate {
            updateOUIDatabase(useFullList: false)
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
        ouiUpdateError = nil
        loadLocalOUIDatabase(startUpdate: false)
        updateOUIDatabase(useFullList: false)
        log("OUI-Cache gelöscht, Update gestartet")
    }
    
    private func applyOUIDatabase(_ database: [String: String], timestamp: Date, persist: Bool) {
        var merged = database
        merged.merge(NetworkConstants.additionalOUIs) { current, _ in current }
        ouiDatabase = merged
        ouiDatabaseCount = merged.count
        ouiDatabaseTimestamp = timestamp
        if persist {
            persistOUICache(database: merged, timestamp: timestamp)
        }
    }
    
    /// Fill manufacturers that were still unknown when the OUI list finished loading.
    private func reassignManufacturers() {
        guard !devices.isEmpty else { return }
        var copy = devices
        var changed = false
        for index in copy.indices {
            let device = copy[index]
            let proposed = resolveManufacturer(
                mac: device.macAddress,
                names: [
                    device.hostName,
                    device.bonjourName,
                    device.mdnsName,
                    device.dnsName,
                    device.netbiosName,
                    device.detailHint
                ],
                bonjour: nil,
                ouiDB: ouiDatabase
            )
            if shouldUpgradeManufacturer(current: device.manufacturer, proposed: proposed) {
                copy[index].manufacturer = proposed
                changed = true
            }
        }
        if changed {
            devices = copy
        }
    }
    
    private func noteOUIFailure(_ message: String, error: ScanError) {
        ouiUpdateError = message
        scanError = error
        log(message)
        isUpdatingOUI = false
    }
    
    private func clearOUIRelatedScanError() {
        switch scanError {
        case .ouiDatabaseLoadFailed, .ouiDatabaseDownloadFailed, .ouiDatabaseCorrupted:
            scanError = nil
        default:
            break
        }
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
    
    /// Returns true when a legacy cache was applied (fresh or stale). A stale cache is kept and refreshed.
    @discardableResult
    private func migrateLegacyOUIUserDefaultsCache() -> Bool {
        let legacyKey = "ouiDatabase"
        guard let savedData = UserDefaults.standard.data(forKey: legacyKey),
              let savedDatabase = try? JSONDecoder().decode([String: String].self, from: savedData),
              !savedDatabase.isEmpty else {
            return false
        }
        
        let timestamp = UserDefaults.standard.object(forKey: ouiDatabaseTimestampKey) as? Date ?? Date.distantPast
        applyOUIDatabase(savedDatabase, timestamp: timestamp, persist: true)
        let age = Date().timeIntervalSince(timestamp)
        isOUIDatabaseValid = age < ouiDatabaseValidityDuration && savedDatabase.count > Self.minimumOUIEntries
        
        UserDefaults.standard.removeObject(forKey: legacyKey)
        UserDefaults.standard.removeObject(forKey: ouiDatabaseTimestampKey)
        
        if !isOUIDatabaseValid || savedDatabase.count < 5_000 {
            updateOUIDatabase(useFullList: false)
        }
        return true
    }
}
