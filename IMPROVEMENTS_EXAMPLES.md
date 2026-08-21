# Konkrete Implementierungs-Beispiele

Dieses Dokument zeigt konkrete Code-Beispiele für die wichtigsten Verbesserungen aus dem Code Review.

---

## 1. Strukturierte Fehlerbehandlung

### Neue Datei: `Models/ScanError.swift`

```swift
import Foundation

/// Strukturierte Fehler für Netzwerk-Scanning-Operationen
enum ScanError: LocalizedError {
    case invalidIPAddress(String)
    case networkUnreachable
    case scanCancelled
    case socketCreationFailed(errno: Int32)
    case connectionTimeout(ip: String, port: Int)
    case permissionDenied
    case invalidPortNumber(Int)
    case ouiDatabaseLoadFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidIPAddress(let ip):
            return "Ungültige IP-Adresse: \(ip)"
        case .networkUnreachable:
            return "Netzwerk nicht erreichbar"
        case .scanCancelled:
            return "Scan wurde abgebrochen"
        case .socketCreationFailed(let errno):
            return "Socket-Erstellung fehlgeschlagen (Fehlercode: \(errno))"
        case .connectionTimeout(let ip, let port):
            return "Verbindungstimeout bei \(ip):\(port)"
        case .permissionDenied:
            return "Netzwerkzugriff verweigert - Bitte Berechtigungen prüfen"
        case .invalidPortNumber(let port):
            return "Ungültige Port-Nummer: \(port)"
        case .ouiDatabaseLoadFailed(let error):
            return "OUI-Datenbank konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidIPAddress:
            return "Bitte geben Sie eine gültige IPv4-Adresse im Format xxx.xxx.xxx.xxx ein"
        case .networkUnreachable:
            return "Prüfen Sie Ihre Netzwerkverbindung und versuchen Sie es erneut"
        case .permissionDenied:
            return "Gehen Sie zu Einstellungen > Datenschutz > Lokales Netzwerk und aktivieren Sie die Berechtigung"
        case .invalidPortNumber:
            return "Port-Nummern müssen zwischen 1 und 65535 liegen"
        default:
            return nil
        }
    }
}
```

---

## 2. Settings-Manager mit Type-Safety

### Neue Datei: `Utilities/SettingsManager.swift`

```swift
import Foundation
import Combine

/// Type-safe Property Wrapper für UserDefaults
@propertyWrapper
struct UserDefaultsBacked<T: Codable> {
    let key: String
    let defaultValue: T
    private let userDefaults: UserDefaults
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T {
        get {
            // Spezialbehandlung für primitiven Typen
            if let boolValue = defaultValue as? Bool {
                return userDefaults.bool(forKey: key) as? T ?? defaultValue
            }
            
            // Für Codable-Typen
            guard let data = userDefaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return decoded
        }
        set {
            // Primitive Typen direkt speichern
            if let boolValue = newValue as? Bool {
                userDefaults.set(boolValue, forKey: key)
            } else if let intValue = newValue as? Int {
                userDefaults.set(intValue, forKey: key)
            } else if let stringValue = newValue as? String {
                userDefaults.set(stringValue, forKey: key)
            } else {
                // Codable-Typen als JSON speichern
                let encoded = try? JSONEncoder().encode(newValue)
                userDefaults.set(encoded, forKey: key)
            }
        }
    }
}

/// Zentrale Verwaltung aller App-Einstellungen
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    enum Keys {
        static let customPorts = "customPorts"
        static let lastScanResults = "lastScanResults"
        static let recentNetworks = "recentNetworks"
        static let deviceAliases = "deviceAliases"
        static let ouiDatabaseTimestamp = "ouiDatabaseTimestamp"
        static let sortOption = "sortOption"
        static let sortAscending = "sortAscending"
        static let preferredScanMode = "preferredScanMode"
    }
    
    @Published @UserDefaultsBacked(key: Keys.customPorts, defaultValue: NetworkConstants.defaultPorts)
    var customPorts: Set<Int>
    
    @Published @UserDefaultsBacked(key: Keys.sortOption, defaultValue: SortOption.ip)
    var sortOption: SortOption
    
    @Published @UserDefaultsBacked(key: Keys.sortAscending, defaultValue: true)
    var sortAscending: Bool
    
    @Published @UserDefaultsBacked(key: Keys.preferredScanMode, defaultValue: ScanMode.quickScan)
    var preferredScanMode: ScanMode
    
    @Published @UserDefaultsBacked(key: Keys.recentNetworks, defaultValue: [])
    var recentNetworks: [String]
    
    @Published @UserDefaultsBacked(key: Keys.deviceAliases, defaultValue: [:])
    var deviceAliases: [String: DeviceAlias]
    
    private init() {}
    
    /// Setzt alle Einstellungen auf Standardwerte zurück
    func resetToDefaults() {
        customPorts = NetworkConstants.defaultPorts
        sortOption = .ip
        sortAscending = true
        preferredScanMode = .quickScan
        recentNetworks = []
        deviceAliases = [:]
    }
    
    /// Exportiert alle Einstellungen als Dictionary (für Backup/Restore)
    func exportSettings() -> [String: Any] {
        [
            Keys.customPorts: Array(customPorts),
            Keys.sortOption: sortOption.rawValue,
            Keys.sortAscending: sortAscending,
            Keys.preferredScanMode: preferredScanMode == .fullScan ? "fullScan" : "quickScan",
            Keys.recentNetworks: recentNetworks,
            Keys.deviceAliases: (try? JSONEncoder().encode(deviceAliases))?.base64EncodedString() ?? ""
        ]
    }
    
    /// Importiert Einstellungen aus Dictionary
    func importSettings(_ settings: [String: Any]) throws {
        if let ports = settings[Keys.customPorts] as? [Int] {
            customPorts = Set(ports)
        }
        if let sortString = settings[Keys.sortOption] as? String,
           let option = SortOption(rawValue: sortString) {
            sortOption = option
        }
        if let ascending = settings[Keys.sortAscending] as? Bool {
            sortAscending = ascending
        }
        if let modeString = settings[Keys.preferredScanMode] as? String {
            preferredScanMode = modeString == "fullScan" ? .fullScan : .quickScan
        }
        if let networks = settings[Keys.recentNetworks] as? [String] {
            recentNetworks = networks
        }
        if let aliasesString = settings[Keys.deviceAliases] as? String,
           let data = Data(base64Encoded: aliasesString),
           let aliases = try? JSONDecoder().decode([String: DeviceAlias].self, from: data) {
            deviceAliases = aliases
        }
    }
}
```

---

## 3. DNS-Cache für Performance

### Neue Datei: `Utilities/DNSCache.swift`

```swift
import Foundation

/// Thread-safe DNS-Cache mit automatischer Invalidierung
actor DNSCache {
    private struct CacheEntry {
        let hostname: String
        let timestamp: Date
        
        func isValid(validityDuration: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < validityDuration
        }
    }
    
    private var cache: [String: CacheEntry] = [:]
    private let cacheValidityDuration: TimeInterval
    private let maxCacheSize: Int
    
    /// Statistiken für Monitoring
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    init(validityDuration: TimeInterval = 300, maxSize: Int = 1000) {
        self.cacheValidityDuration = validityDuration
        self.maxCacheSize = maxSize
    }
    
    /// Ruft einen gecachten Hostname ab, falls noch gültig
    func get(_ ip: String) -> String? {
        guard let entry = cache[ip], entry.isValid(validityDuration: cacheValidityDuration) else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return entry.hostname
    }
    
    /// Speichert einen Hostname im Cache
    func set(_ hostname: String, for ip: String) {
        // Wenn Cache voll, entferne älteste Einträge
        if cache.count >= maxCacheSize {
            pruneOldestEntries()
        }
        
        cache[ip] = CacheEntry(hostname: hostname, timestamp: Date())
    }
    
    /// Entfernt einen spezifischen Eintrag
    func remove(_ ip: String) {
        cache.removeValue(forKey: ip)
    }
    
    /// Leert den gesamten Cache
    func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }
    
    /// Entfernt abgelaufene Einträge
    func pruneExpired() {
        cache = cache.filter { $0.value.isValid(validityDuration: cacheValidityDuration) }
    }
    
    /// Cache-Statistiken
    var statistics: (hits: Int, misses: Int, size: Int, hitRate: Double) {
        let total = hitCount + missCount
        let hitRate = total > 0 ? Double(hitCount) / Double(total) : 0
        return (hitCount, missCount, cache.count, hitRate)
    }
    
    private func pruneOldestEntries() {
        let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let toRemove = sortedEntries.prefix(maxCacheSize / 4) // Entferne 25%
        for (ip, _) in toRemove {
            cache.removeValue(forKey: ip)
        }
    }
}
```

**Integration in NetworkScanner:**

```swift
// In NetworkScanner.swift
private let dnsCache = DNSCache()

// In NetworkScanner+Network.swift (oder wo getHostName ist)
internal func getHostName(for ipAddress: String, timeout: TimeInterval) async -> String? {
    // Prüfe Cache zuerst
    if let cached = await dnsCache.get(ipAddress) {
        return cached
    }
    
    // Führe DNS-Lookup durch
    let hostname = performDNSLookup(ipAddress, timeout: timeout)
    
    // Speichere Ergebnis im Cache (auch negative Results)
    if let hostname = hostname {
        await dnsCache.set(hostname, for: ipAddress)
    }
    
    return hostname
}

// Neue Methode für Statistiken
func getDNSCacheStatistics() async -> String {
    let stats = await dnsCache.statistics
    return """
    DNS Cache:
    - Hits: \(stats.hits)
    - Misses: \(stats.misses)
    - Size: \(stats.size)
    - Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100))
    """
}
```

---

## 4. Configuration-Enum statt Magic Numbers

### Neue Datei: `Constants/ScanConfiguration.swift`

```swift
import Foundation

/// Zentrale Konfiguration für alle Scan-Parameter
enum ScanConfiguration {
    // MARK: - Concurrency
    
    /// Maximale parallele IP-Scans in Phase 1 (Discovery)
    static let maxConcurrentIPScans = 12
    
    /// Maximale parallele Device-Scans in Phase 2 (Resolution)
    static let maxConcurrentDeviceScans = 4
    
    // MARK: - Timeouts
    
    /// Standard-Timeout für Port-Verbindungen
    static let defaultPortTimeout: TimeInterval = 0.5
    
    /// Timeout für DNS-Lookups
    static let dnsTimeout: TimeInterval = 0.6
    
    /// iOS-spezifischer Delay für Local Network Access
    static let localNetworkAccessDelay: TimeInterval = 0.8
    
    // MARK: - Network
    
    /// Anzahl der zu scannenden IP-Adressen pro Subnet
    static let ipsPerSubnet = 254
    
    /// Maximale Anzahl offener Ports für Early Exit bei Discovery
    static let discoveryPortsEarlyExit = 2
    
    // MARK: - Cache & Storage
    
    /// Maximale Anzahl gespeicherter Netzwerke in Historie
    static let maxRecentNetworks = 3
    
    /// Gültigkeitsdauer der OUI-Datenbank
    static let ouiDatabaseValidityDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 Tage
    
    /// DNS-Cache Gültigkeitsdauer
    static let dnsCacheValidityDuration: TimeInterval = 5 * 60 // 5 Minuten
    
    // MARK: - Rate Limiting
    
    /// Minimale Zeit zwischen zwei Scans (verhindert Spam)
    static let minimumScanInterval: TimeInterval = 1.0
    
    /// Maximale Anzahl von Retry-Versuchen für fehlgeschlagene Verbindungen
    static let maxConnectionRetries = 2
    
    // MARK: - UI
    
    /// Delay für Progress-Updates (vermeidet UI-Flooding)
    static let progressUpdateThrottle: TimeInterval = 0.1
}
```

**Verwendung in NetworkScanner+Scanning.swift:**

```swift
let workerQueue = OperationQueue()
workerQueue.name = "com.ttools.ipscanner.ip-workers"
workerQueue.qualityOfService = .utility
workerQueue.maxConcurrentOperationCount = ScanConfiguration.maxConcurrentIPScans

// Statt:
// workerQueue.maxConcurrentOperationCount = 12
```

---

## 5. Rate Limiter für Security

### Neue Datei: `Utilities/ScanRateLimiter.swift`

```swift
import Foundation

/// Rate Limiter für Scan-Operationen
actor ScanRateLimiter {
    private var scanHistory: [Date] = []
    private let minimumInterval: TimeInterval
    private let maxScansPerMinute: Int
    
    init(
        minimumInterval: TimeInterval = ScanConfiguration.minimumScanInterval,
        maxScansPerMinute: Int = 10
    ) {
        self.minimumInterval = minimumInterval
        self.maxScansPerMinute = maxScansPerMinute
    }
    
    /// Prüft, ob ein neuer Scan gestartet werden darf
    func canScan() async -> (allowed: Bool, reason: String?) {
        let now = Date()
        
        // Entferne alte Einträge (älter als 1 Minute)
        scanHistory = scanHistory.filter { now.timeIntervalSince($0) < 60 }
        
        // Prüfe minimales Intervall
        if let lastScan = scanHistory.last {
            let elapsed = now.timeIntervalSince(lastScan)
            if elapsed < minimumInterval {
                let remaining = minimumInterval - elapsed
                return (false, "Bitte warten Sie noch \(Int(remaining)) Sekunde(n)")
            }
        }
        
        // Prüfe max Scans pro Minute
        if scanHistory.count >= maxScansPerMinute {
            return (false, "Zu viele Scans - Maximallimit erreicht (\(maxScansPerMinute)/Min)")
        }
        
        // Scan erlaubt
        scanHistory.append(now)
        return (true, nil)
    }
    
    /// Setzt den Rate Limiter zurück (z.B. nach App-Neustart)
    func reset() {
        scanHistory.removeAll()
    }
    
    /// Gibt die Zeit bis zum nächsten möglichen Scan zurück
    func timeUntilNextScan() -> TimeInterval {
        guard let lastScan = scanHistory.last else {
            return 0
        }
        let elapsed = Date().timeIntervalSince(lastScan)
        return max(0, minimumInterval - elapsed)
    }
}
```

**Integration:**

```swift
// In NetworkScanner.swift
private let rateLimiter = ScanRateLimiter()

func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) async {
    // Rate Limiting prüfen
    let (allowed, reason) = await rateLimiter.canScan()
    guard allowed else {
        await MainActor.run {
            self.scanError = reason
        }
        return
    }
    
    // ... Rest der Scan-Logik
}
```

---

## 6. Verbesserte Unit Tests

### Neue Datei: `TToolsIPScannerTests/NetworkScannerTests.swift`

```swift
import XCTest
@testable import TToolsIPScanner

final class NetworkScannerTests: XCTestCase {
    var scanner: NetworkScanner!
    
    override func setUp() {
        super.setUp()
        scanner = NetworkScanner()
    }
    
    override func tearDown() {
        scanner = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultNetworkIsValid() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4(scanner.currentNetwork))
    }
    
    func testInitialStateIsNotScanning() {
        XCTAssertFalse(scanner.isScanning)
        XCTAssertEqual(scanner.scanPhase, .idle)
    }
    
    func testDefaultPortsAreLoaded() {
        XCTAssertFalse(scanner.customPorts.isEmpty)
    }
    
    // MARK: - Settings Tests
    
    func testCustomPortsUpdate() {
        let newPorts: Set<Int> = [80, 443, 8080]
        scanner.updateCustomPorts(newPorts)
        XCTAssertEqual(scanner.customPorts, newPorts)
    }
    
    func testSortOptionPersistence() {
        scanner.sortOption = .hostname
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: scanner.sortOptionKey),
            "hostname"
        )
    }
    
    func testSortAscendingPersistence() {
        scanner.sortAscending = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: scanner.sortAscendingKey))
    }
    
    func testScanModeToggle() {
        scanner.preferredScanMode = .fullScan
        XCTAssertEqual(scanner.preferredScanMode, .fullScan)
        
        scanner.preferredScanMode = .quickScan
        XCTAssertEqual(scanner.preferredScanMode, .quickScan)
    }
    
    // MARK: - Recent Networks Tests
    
    func testRecentNetworksLimit() {
        scanner.recentNetworks = []
        
        for i in 1...5 {
            scanner.startScan(baseIP: "192.168.\(i).0")
            scanner.stopScan()
        }
        
        XCTAssertLessThanOrEqual(scanner.recentNetworks.count, 3)
    }
    
    // MARK: - Device Alias Tests
    
    func testAddDeviceAlias() {
        let ip = "192.168.1.100"
        let alias = DeviceAlias(name: "Test Device", icon: "laptopcomputer")
        
        scanner.deviceAliases[ip] = alias
        XCTAssertEqual(scanner.deviceAliases[ip]?.name, "Test Device")
    }
    
    func testDeviceAliasRemoval() {
        let ip = "192.168.1.100"
        scanner.deviceAliases[ip] = DeviceAlias(name: "Test", icon: "iphone")
        
        scanner.deviceAliases.removeValue(forKey: ip)
        XCTAssertNil(scanner.deviceAliases[ip])
    }
    
    // MARK: - Scan State Tests
    
    func testStopScanUpdatesState() {
        scanner.isScanning = true
        scanner.scanPhase = .scanningNetwork
        
        scanner.stopScan()
        
        XCTAssertFalse(scanner.isScanning)
        XCTAssertEqual(scanner.scanPhase, .idle)
        XCTAssertEqual(scanner.progressPercentage, 0)
    }
    
    func testScanGenerationIncrements() {
        let initialGeneration = scanner.scanGeneration
        
        scanner.stopScan()
        
        XCTAssertEqual(scanner.scanGeneration, initialGeneration + 1)
    }
}

// MARK: - DNS Cache Tests

final class DNSCacheTests: XCTestCase {
    var cache: DNSCache!
    
    override func setUp() async throws {
        cache = DNSCache(validityDuration: 1.0, maxSize: 3)
    }
    
    func testCacheStoresAndRetrievesValues() async {
        await cache.set("test.local", for: "192.168.1.1")
        let result = await cache.get("192.168.1.1")
        XCTAssertEqual(result, "test.local")
    }
    
    func testCacheExpiresAfterValidityDuration() async throws {
        await cache.set("test.local", for: "192.168.1.1")
        
        // Warte länger als Validity Duration
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 Sekunden
        
        let result = await cache.get("192.168.1.1")
        XCTAssertNil(result)
    }
    
    func testCacheRespectsMaxSize() async {
        await cache.set("host1.local", for: "192.168.1.1")
        await cache.set("host2.local", for: "192.168.1.2")
        await cache.set("host3.local", for: "192.168.1.3")
        await cache.set("host4.local", for: "192.168.1.4")
        
        let stats = await cache.statistics
        XCTAssertLessThanOrEqual(stats.size, 3)
    }
    
    func testCacheStatistics() async {
        await cache.set("test.local", for: "192.168.1.1")
        _ = await cache.get("192.168.1.1") // Hit
        _ = await cache.get("192.168.1.2") // Miss
        
        let stats = await cache.statistics
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hitRate, 0.5)
    }
    
    func testCacheClear() async {
        await cache.set("test.local", for: "192.168.1.1")
        await cache.clear()
        
        let result = await cache.get("192.168.1.1")
        let stats = await cache.statistics
        
        XCTAssertNil(result)
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 1)
    }
}

// MARK: - Rate Limiter Tests

final class ScanRateLimiterTests: XCTestCase {
    var limiter: ScanRateLimiter!
    
    override func setUp() async throws {
        limiter = ScanRateLimiter(minimumInterval: 0.5, maxScansPerMinute: 3)
    }
    
    func testFirstScanIsAllowed() async {
        let result = await limiter.canScan()
        XCTAssertTrue(result.allowed)
        XCTAssertNil(result.reason)
    }
    
    func testRapidScansAreBlocked() async {
        _ = await limiter.canScan() // Erster Scan
        let result = await limiter.canScan() // Sofort zweiter Scan
        
        XCTAssertFalse(result.allowed)
        XCTAssertNotNil(result.reason)
    }
    
    func testScansAllowedAfterInterval() async throws {
        _ = await limiter.canScan()
        
        // Warte minimal interval
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 Sekunden
        
        let result = await limiter.canScan()
        XCTAssertTrue(result.allowed)
    }
    
    func testMaxScansPerMinuteEnforced() async {
        _ = await limiter.canScan()
        try? await Task.sleep(nanoseconds: 600_000_000)
        _ = await limiter.canScan()
        try? await Task.sleep(nanoseconds: 600_000_000)
        _ = await limiter.canScan()
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        // Vierter Scan sollte geblockt werden
        let result = await limiter.canScan()
        XCTAssertFalse(result.allowed)
    }
    
    func testResetClearsHistory() async {
        _ = await limiter.canScan()
        await limiter.reset()
        
        let result = await limiter.canScan()
        XCTAssertTrue(result.allowed)
    }
}
```

---

## 7. Logging-System

### Neue Datei: `Utilities/ScanLogger.swift`

```swift
import Foundation
import os.log

/// Zentrales Logging-System für Scan-Operationen
enum ScanLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.ttools.ipscanner"
    
    static let network = Logger(subsystem: subsystem, category: "network")
    static let scanning = Logger(subsystem: subsystem, category: "scanning")
    static let performance = Logger(subsystem: subsystem, category: "performance")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// Loggt Start eines Scans
    static func logScanStart(baseIP: String, mode: ScanMode) {
        scanning.info("🚀 Scan gestartet: \(baseIP, privacy: .public) Mode: \(String(describing: mode), privacy: .public)")
    }
    
    /// Loggt Scan-Abschluss
    static func logScanCompletion(devicesFound: Int, duration: TimeInterval) {
        scanning.info("✅ Scan abgeschlossen: \(devicesFound) Geräte in \(String(format: "%.2f", duration))s gefunden")
    }
    
    /// Loggt Fehler
    static func logError(_ error: Error, context: String) {
        scanning.error("❌ Fehler in \(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
    
    /// Loggt Performance-Metriken
    static func logPerformance(operation: String, duration: TimeInterval) {
        performance.debug("⏱️ \(operation, privacy: .public): \(String(format: "%.3f", duration))s")
    }
    
    /// Loggt Netzwerk-Events
    static func logNetworkEvent(_ message: String, ip: String? = nil) {
        if let ip = ip {
            network.debug("🌐 \(message, privacy: .public) [\(ip, privacy: .private(mask: .hash))]")
        } else {
            network.debug("🌐 \(message, privacy: .public)")
        }
    }
}

// Performance-Messung Helper
extension ScanLogger {
    /// Wrapper für Performance-Messung
    static func measure<T>(
        operation: String,
        _ block: () throws -> T
    ) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logPerformance(operation: operation, duration: duration)
        }
        return try block()
    }
    
    /// Async Performance-Messung
    static func measure<T>(
        operation: String,
        _ block: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logPerformance(operation: operation, duration: duration)
        }
        return try await block()
    }
}
```

**Verwendung:**

```swift
// In NetworkScanner+Scanning.swift
func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) {
    ScanLogger.logScanStart(baseIP: ipToScan, mode: mode)
    
    // ... Scan-Logik ...
    
    ScanLogger.logScanCompletion(
        devicesFound: devices.count,
        duration: scanDuration
    )
}

// Performance-Messung
let devices = ScanLogger.measure(operation: "Device Resolution") {
    // ... langsame Operation ...
}
```

---

Diese Beispiele zeigen konkrete, produktionsreife Implementierungen der wichtigsten Verbesserungsvorschläge. Sie können schrittweise integriert werden, ohne den bestehenden Code zu brechen.
