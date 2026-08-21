import Foundation

/// Thread-safe DNS-Cache mit automatischer Invalidierung
///
/// DNSCache verwendet Swift's Actor-Model für Thread-Safety und speichert
/// DNS-Lookups mit Zeitstempel. Einträge werden nach einer konfigurierbaren
/// Dauer automatisch als ungültig betrachtet.
///
/// # Verwendung
/// ```swift
/// let cache = DNSCache()
///
/// // Prüfe Cache vor DNS-Lookup
/// if let cached = await cache.get("192.168.1.1") {
///     return cached
/// }
///
/// // Führe DNS-Lookup durch
/// let hostname = performDNSLookup(ip)
///
/// // Speichere im Cache
/// await cache.set(hostname, for: ip)
/// ```
actor DNSCache {
    // MARK: - Types
    
    /// Cache-Eintrag mit Hostname und Zeitstempel
    private struct CacheEntry {
        let hostname: String
        let timestamp: Date
        
        /// Prüft ob der Eintrag noch gültig ist
        func isValid(validityDuration: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < validityDuration
        }
    }
    
    // MARK: - Properties
    
    /// Interner Cache-Speicher
    private var cache: [String: CacheEntry] = [:]
    
    /// Gültigkeitsdauer eines Cache-Eintrags in Sekunden
    private let cacheValidityDuration: TimeInterval
    
    /// Maximale Anzahl von Einträgen im Cache
    private let maxCacheSize: Int
    
    /// Statistiken für Monitoring
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    // MARK: - Initialization
    
    /// Initialisiert einen neuen DNS-Cache
    ///
    /// - Parameters:
    ///   - validityDuration: Gültigkeitsdauer in Sekunden (Standard: 300s / 5 Minuten)
    ///   - maxSize: Maximale Anzahl von Cache-Einträgen (Standard: 1000)
    init(validityDuration: TimeInterval = 300, maxSize: Int = 1000) {
        self.cacheValidityDuration = validityDuration
        self.maxCacheSize = maxSize
    }
    
    // MARK: - Public Methods
    
    /// Ruft einen gecachten Hostname ab, falls noch gültig
    ///
    /// - Parameter ip: IP-Adresse als String
    /// - Returns: Gecachter Hostname oder `nil` wenn nicht gefunden oder abgelaufen
    func get(_ ip: String) -> String? {
        guard let entry = cache[ip], entry.isValid(validityDuration: cacheValidityDuration) else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return entry.hostname
    }
    
    /// Speichert einen Hostname im Cache
    ///
    /// Wenn der Cache voll ist, werden automatisch die ältesten Einträge entfernt.
    ///
    /// - Parameters:
    ///   - hostname: Der zu speichernde Hostname
    ///   - ip: Die zugehörige IP-Adresse
    func set(_ hostname: String, for ip: String) {
        // Wenn Cache voll, entferne älteste Einträge
        if cache.count >= maxCacheSize {
            pruneOldestEntries()
        }
        
        cache[ip] = CacheEntry(hostname: hostname, timestamp: Date())
    }
    
    /// Entfernt einen spezifischen Eintrag aus dem Cache
    ///
    /// - Parameter ip: IP-Adresse des zu entfernenden Eintrags
    func remove(_ ip: String) {
        cache.removeValue(forKey: ip)
    }
    
    /// Leert den gesamten Cache und setzt Statistiken zurück
    func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }
    
    /// Entfernt alle abgelaufenen Einträge aus dem Cache
    ///
    /// Diese Methode kann periodisch aufgerufen werden, um Memory zu sparen.
    func pruneExpired() {
        cache = cache.filter { $0.value.isValid(validityDuration: cacheValidityDuration) }
    }
    
    /// Gibt Cache-Statistiken zurück
    ///
    /// - Returns: Tuple mit Hits, Misses, Size und Hit-Rate
    var statistics: (hits: Int, misses: Int, size: Int, hitRate: Double) {
        let total = hitCount + missCount
        let hitRate = total > 0 ? Double(hitCount) / Double(total) : 0
        return (hitCount, missCount, cache.count, hitRate)
    }
    
    /// Exportiert alle Cache-Einträge für Debugging
    ///
    /// - Returns: Dictionary mit IP → (Hostname, Alter in Sekunden)
    func debugExport() -> [String: (hostname: String, ageSeconds: TimeInterval)] {
        let now = Date()
        return cache.mapValues { entry in
            (entry.hostname, now.timeIntervalSince(entry.timestamp))
        }
    }
    
    // MARK: - Private Methods
    
    /// Entfernt die ältesten 25% der Einträge wenn Cache voll ist
    private func pruneOldestEntries() {
        let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let toRemove = sortedEntries.prefix(maxCacheSize / 4) // Entferne 25%
        for (ip, _) in toRemove {
            cache.removeValue(forKey: ip)
        }
    }
}

// MARK: - Extensions

extension DNSCache {
    /// Formatierte Statistik-String für UI-Anzeige
    func formattedStatistics() -> String {
        let stats = statistics
        return """
        DNS Cache Statistiken:
        • Hits: \(stats.hits)
        • Misses: \(stats.misses)
        • Cache Size: \(stats.size) Einträge
        • Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100))
        """
    }
    
    /// Gibt Memory-Schätzung des Caches zurück
    ///
    /// Grobe Schätzung basierend auf durchschnittlicher String-Länge
    func estimatedMemoryUsage() -> String {
        let stats = statistics
        let avgBytesPerEntry = 100 // IP (15) + Hostname (~40) + Overhead (~45)
        let totalBytes = stats.size * avgBytesPerEntry
        
        if totalBytes < 1024 {
            return "\(totalBytes) Bytes"
        } else if totalBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalBytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(totalBytes) / (1024.0 * 1024.0))
        }
    }
}
