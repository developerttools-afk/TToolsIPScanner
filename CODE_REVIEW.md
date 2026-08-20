# Code Review - TToolsIPScanner

**Datum:** 20. August 2026  
**Reviewer:** Cloud Agent  
**Projekt:** TToolsIPScanner (iOS/macOS IP-Scanner)

---

## Zusammenfassung

Das Projekt ist insgesamt gut strukturiert und zeigt solide Swift/SwiftUI-Praktiken. Der Code ist funktional und die Architektur mit Extensions zur Modularisierung ist sinnvoll. Es gibt jedoch mehrere Bereiche, in denen Verbesserungen vorgenommen werden können, um die Wartbarkeit, Performance und Robustheit zu erhöhen.

**Gesamtbewertung:** 7/10

---

## 🎯 Hauptverbesserungsvorschläge

### 1. **Modernisierung der Concurrency (Hoch-Priorität)**

**Problem:**
- Der Code verwendet veraltete Concurrency-Patterns wie `DispatchQueue` und `OperationQueue`
- Extensive Verwendung von Callbacks und `@escaping`-Closures
- Komplexe Thread-Synchronisation mit `NSLock`

**Lösung:**
Migration zu Swift Concurrency (async/await):

```swift
// Vorher (NetworkScanner+Scanning.swift, Zeile 11-41):
func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) {
    // ...
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
        guard let self, self.isScanActive(generation) else { return }
        self.beginScanPipeline(ipToScan: ipToScan, mode: mode, generation: generation)
    }
}

// Nachher:
func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) async throws {
    let ipToScan = baseIP ?? currentNetwork
    scanError = nil
    
    guard IPAddressValidator.isValidIPv4(ipToScan) else {
        throw ScanError.invalidIPAddress(ipToScan)
    }
    
    // ...
    
    #if os(iOS) || os(visionOS)
    LocalNetworkAccess.requestIfNeeded()
    try await Task.sleep(for: .milliseconds(800))
    #endif
    
    try await beginScanPipeline(ipToScan: ipToScan, mode: mode)
}
```

**Vorteile:**
- Einfacherer, lesbarer Code
- Automatisches Cancellation-Handling mit `Task`
- Bessere Fehlerbehandlung mit `throws`
- Keine Race Conditions mehr durch strukturierte Concurrency

---

### 2. **Fehlerbehandlung verbessern (Hoch-Priorität)**

**Problem:**
- Fehler werden oft stillschweigend ignoriert (z.B. Socket-Operationen)
- Keine strukturierte Fehler-Typen
- Fehler werden nur in String-Properties gespeichert

**Lösung:**
Einführung eines strukturierten Error-Typs:

```swift
// Neue Datei: Models/ScanError.swift
enum ScanError: LocalizedError {
    case invalidIPAddress(String)
    case networkUnreachable
    case scanCancelled
    case socketCreationFailed(Int32)
    case connectionTimeout(String, Int)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidIPAddress(let ip):
            return "Ungültige IP-Adresse: \(ip)"
        case .networkUnreachable:
            return "Netzwerk nicht erreichbar"
        case .scanCancelled:
            return "Scan wurde abgebrochen"
        case .socketCreationFailed(let code):
            return "Socket-Erstellung fehlgeschlagen (Code: \(code))"
        case .connectionTimeout(let ip, let port):
            return "Verbindungstimeout: \(ip):\(port)"
        case .permissionDenied:
            return "Netzwerkzugriff verweigert"
        }
    }
}
```

**In NetworkScanner+Socket.swift:**

```swift
// Zeile 36-99
internal func isPortOpen(ip: String, port: Int, timeout: TimeInterval) throws -> Bool {
    let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard socket >= 0 else {
        throw ScanError.socketCreationFailed(errno)
    }
    
    // ... Rest der Implementierung mit proper error propagation
}
```

---

### 3. **Code-Duplizierung reduzieren (Mittel-Priorität)**

**Problem:**
- Ähnlicher Code in `probeOpenDiscoveryPorts` und `probeOpenPorts`
- Redundante Manufacturer-Detection-Logik
- Mehrfache UserDefaults-Zugriffsmuster

**Lösung:**

```swift
// Refactoring in NetworkScanner+Socket.swift
internal func probeOpenDiscoveryPorts(_ ip: String) -> [Int] {
    probeOpenPorts(
        ip, 
        ports: NetworkConstants.discoveryPorts, 
        timeout: NetworkConstants.discoveryTimeout,
        earlyExit: { $0.count >= 2 }
    )
}

internal func probeOpenPorts(
    _ ip: String,
    ports: [Int],
    timeout: TimeInterval = 0.5,
    earlyExit: (([Int]) -> Bool)? = nil
) -> [Int] {
    var open: [Int] = []
    for port in ports {
        if isPortOpen(ip: ip, port: port, timeout: timeout) {
            open.append(port)
            if let shouldExit = earlyExit, shouldExit(open) {
                break
            }
        }
    }
    return open
}
```

---

### 4. **UserDefaults-Abstraction (Mittel-Priorität)**

**Problem:**
- Direkte UserDefaults-Zugriffe sind über die Klasse verteilt
- Keine Type-Safety
- Schwer zu testen

**Lösung:**
Einführung eines Settings-Managers:

```swift
// Neue Datei: Utilities/SettingsManager.swift
@propertyWrapper
struct UserDefaultsBacked<T: Codable> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            if T.self == Bool.self {
                return UserDefaults.standard.bool(forKey: key) as? T ?? defaultValue
            }
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValue
            }
            return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
}

final class SettingsManager {
    @UserDefaultsBacked(key: "customPorts", defaultValue: NetworkConstants.defaultPorts)
    var customPorts: Set<Int>
    
    @UserDefaultsBacked(key: "sortOption", defaultValue: .ip)
    var sortOption: SortOption
    
    @UserDefaultsBacked(key: "sortAscending", defaultValue: true)
    var sortAscending: Bool
    
    // ...
}
```

---

### 5. **Memory und Resource Management (Hoch-Prioritität)**

**Problem:**
- Socket-Resources werden nicht immer korrekt freigegeben bei Fehlern
- Potentielle Memory Leaks bei Scan-Abbruch
- Große Operation Queues ohne Memory-Limits

**Lösung:**

```swift
// NetworkScanner+Socket.swift, Zeile 36-99
internal func isPortOpen(ip: String, port: Int, timeout: TimeInterval) -> Bool {
    let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard socket >= 0 else { return false }
    
    // Verwende defer für garantierte Cleanup
    defer {
        // Sicherstellen, dass Socket immer geschlossen wird
        Darwin.shutdown(socket, SHUT_RDWR)
        Darwin.close(socket)
    }
    
    // Setzt Optionen mit Error-Handling
    var linger = linger(l_onoff: 1, l_linger: 0)
    guard setsockopt(
        socket,
        SOL_SOCKET,
        SO_LINGER,
        &linger,
        socklen_t(MemoryLayout<linger>.size)
    ) == 0 else {
        return false
    }
    
    // ... Rest der Implementierung
}
```

**Scan-Abbruch verbessern:**

```swift
// NetworkScanner.swift
func stopScan() {
    scanGeneration += 1
    
    // Cancel alle laufenden Tasks
    currentScanTask?.cancel()
    currentScanTask = nil
    
    isScanning = false
    scanPhase = .idle
    progressPercentage = 0
    scanProgress = "Scan abgebrochen"
    currentScanIP = ""
    saveSettings()
}
```

---

### 6. **Test-Coverage verbessern (Mittel-Priorität)**

**Problem:**
- Minimale Unit-Tests vorhanden
- Keine Tests für kritische Komponenten wie IP-Validierung, Port-Scanning
- Keine Integration-Tests

**Lösung:**

```swift
// Neue Datei: TToolsIPScannerTests/IPAddressValidatorTests.swift
import XCTest
@testable import TToolsIPScanner

final class IPAddressValidatorTests: XCTestCase {
    func testValidIPv4Addresses() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4("192.168.1.1"))
        XCTAssertTrue(IPAddressValidator.isValidIPv4("10.0.0.1"))
        XCTAssertTrue(IPAddressValidator.isValidIPv4("172.16.0.1"))
        XCTAssertTrue(IPAddressValidator.isValidIPv4("255.255.255.255"))
        XCTAssertTrue(IPAddressValidator.isValidIPv4("0.0.0.0"))
    }
    
    func testInvalidIPv4Addresses() {
        XCTAssertFalse(IPAddressValidator.isValidIPv4("256.1.1.1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("192.168.1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("192.168.1.1.1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("192.168.01.1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4(""))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("abc.def.ghi.jkl"))
    }
    
    func testLeadingZerosRejected() {
        XCTAssertFalse(IPAddressValidator.isValidIPv4("192.168.001.1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("01.0.0.1"))
        XCTAssertTrue(IPAddressValidator.isValidIPv4("0.0.0.0")) // "0" ist OK
    }
}

// Neue Datei: TToolsIPScannerTests/NetworkScannerTests.swift
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
    
    func testDefaultNetworkIsValid() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4(scanner.currentNetwork))
    }
    
    func testCustomPortsUpdate() {
        let newPorts: Set<Int> = [80, 443, 8080]
        scanner.updateCustomPorts(newPorts)
        XCTAssertEqual(scanner.customPorts, newPorts)
    }
    
    func testSortOptionPersistence() {
        scanner.sortOption = .hostname
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "sortOption"),
            "hostname"
        )
    }
}
```

---

### 7. **Code-Dokumentation (Niedrig-Priorität)**

**Problem:**
- Fehlende DocStrings für öffentliche APIs
- Komplexe Algorithmen ohne Erklärungen
- Keine Verwendungsbeispiele

**Lösung:**

```swift
// NetworkScanner.swift
/// Haupt-Scanner-Klasse für Netzwerk-Discovery und Port-Scanning.
///
/// Diese Klasse koordiniert den gesamten Scan-Prozess in zwei Phasen:
/// 1. Discovery-Phase: Schnelles Finden von Hosts im Netzwerk
/// 2. Resolution-Phase: Detailliertes Scannen von Ports, MAC-Adressen und Hostnamen
///
/// # Verwendung
/// ```swift
/// let scanner = NetworkScanner()
/// scanner.startScan(baseIP: "192.168.1.0", mode: .quickScan)
/// ```
///
/// - Important: Die Klasse verwendet eine Generation-basierte Abbruch-Strategie.
///   Jeder neue Scan erhöht `scanGeneration`, wodurch laufende Operations ihre
///   Arbeit einstellen können.
class NetworkScanner: ObservableObject {
    // ...
    
    /// Startet einen Netzwerk-Scan für das angegebene Basis-Netzwerk.
    ///
    /// - Parameters:
    ///   - baseIP: Die Basis-IP-Adresse des zu scannenden Netzwerks (z.B. "192.168.1.0").
    ///             Falls `nil`, wird die aktuelle Netzwerk-IP verwendet.
    ///   - mode: Der Scan-Modus - `.quickScan` für Standard-Ports oder `.fullScan`
    ///           für einen umfassenden Port-Scan.
    ///
    /// - Note: Auf iOS/visionOS wird vor dem Scan automatisch Local Network Access
    ///         angefordert (TN3179).
    func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) {
        // ...
    }
}
```

---

### 8. **Performance-Optimierungen (Mittel-Priorität)**

**Problem:**
- Socket-Timeouts könnten dynamisch angepasst werden
- Keine Caching-Strategie für DNS-Lookups
- Ineffiziente Array-Operationen bei großen Device-Listen

**Lösung:**

```swift
// Neue Datei: Utilities/DNSCache.swift
actor DNSCache {
    private var cache: [String: (hostname: String, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5 Minuten
    
    func get(_ ip: String) -> String? {
        guard let entry = cache[ip],
              Date().timeIntervalSince(entry.timestamp) < cacheValidityDuration else {
            return nil
        }
        return entry.hostname
    }
    
    func set(_ hostname: String, for ip: String) {
        cache[ip] = (hostname, Date())
    }
    
    func clear() {
        cache.removeAll()
    }
}

// In NetworkScanner
private let dnsCache = DNSCache()

internal func getHostName(for ipAddress: String, timeout: TimeInterval) -> String? {
    // Prüfe Cache zuerst
    if let cached = await dnsCache.get(ipAddress) {
        return cached
    }
    
    // Fallback auf DNS-Lookup
    // ... existing implementation ...
    
    // Cache das Ergebnis
    if let hostname = resolvedName {
        await dnsCache.set(hostname, for: ipAddress)
    }
    
    return resolvedName
}
```

**Array-Performance:**

```swift
// NetworkScanner+Scanning.swift, Zeile 138
// Vorher:
self.devices = self.devices + [newDevice]

// Nachher (vermeidet Copy):
self.devices.append(newDevice)
```

---

### 9. **Accessibility und Localization (Niedrig-Priorität)**

**Problem:**
- Hardcodierte deutsche Strings im Code
- Keine Unterstützung für andere Sprachen
- Fehlende Accessibility-Labels

**Lösung:**

```swift
// Neue Datei: Resources/Localizable.strings (de)
"scan.started" = "Scan gestartet…";
"scan.completed" = "Scan abgeschlossen";
"scan.cancelled" = "Scan abgebrochen";
"error.invalid_ip" = "Ungültige IP-Adresse: %@";
"device.not_available" = "Nicht mehr verfügbar";
"status.checking_network_access" = "Lokalen Netzwerkzugriff prüfen…";

// Im Code:
scanProgress = String(localized: "scan.started")
scanError = String(localized: "error.invalid_ip", arguments: [ipToScan])
```

---

### 10. **Security-Überlegungen (Mittel-Priorität)**

**Problem:**
- Raw socket operations ohne zusätzliche Security-Checks
- Keine Rate-Limiting bei Port-Scans
- Fehlende Input-Sanitization in manchen Bereichen

**Lösung:**

```swift
// Neue Datei: Utilities/ScanRateLimiter.swift
actor ScanRateLimiter {
    private var lastScanTime: Date?
    private let minimumInterval: TimeInterval = 1.0
    
    func canScan() -> Bool {
        guard let last = lastScanTime else {
            lastScanTime = Date()
            return true
        }
        
        let elapsed = Date().timeIntervalSince(last)
        if elapsed >= minimumInterval {
            lastScanTime = Date()
            return true
        }
        
        return false
    }
}

// In NetworkScanner
private let rateLimiter = ScanRateLimiter()

func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) {
    guard await rateLimiter.canScan() else {
        scanError = "Bitte warten Sie zwischen Scans"
        return
    }
    // ...
}
```

---

## 📊 Detaillierte Datei-Reviews

### NetworkScanner.swift
**Bewertung:** 8/10

**Positiv:**
- Gute Trennung von Verantwortlichkeiten mit Extensions
- Klare Property-Organisation mit MARK-Kommentaren
- Sinnvolle Published-Properties für SwiftUI

**Verbesserungsbedarf:**
- Zu viele Properties (42 published + internal) - könnte in Sub-Objekte aufgeteilt werden
- UserDefaults-Keys als Strings - sollten in Enum
- Init-Methode macht zu viel (I/O, Netzwerk-Checks)

### NetworkScanner+Scanning.swift
**Bewertung:** 6/10

**Positiv:**
- Gut strukturierter zwei-Phasen-Scan-Prozess
- Generation-basierte Abbruch-Strategie ist clever
- Caching von vorherigen Scan-Ergebnissen

**Verbesserungsbedarf:**
- Zu lange Methoden (bis zu 170 Zeilen)
- Verschachtelte Closures schwer zu lesen
- Keine Fehlerbehandlung bei Netzwerkproblemen
- Hardcodierte Werte (z.B. maxConcurrentOperationCount: 12)

### NetworkScanner+Socket.swift
**Bewertung:** 7/10

**Positiv:**
- Korrekte Low-Level Socket-Implementierung
- Gutes Error-Handling mit `defer`
- Platform-spezifische Timeouts

**Verbesserungsbedarf:**
- Keine Fehler-Propagation (gibt nur Bool zurück)
- Schwer zu testen (direkte Darwin-Calls)
- Könnte in Protocol wrapped werden für Testability

### NetworkScanner+MAC.swift
**Bewertung:** 7/10

**Positiv:**
- Elegante sysctl-Implementierung für macOS
- Vermeidung von subprocess-Overhead
- Gutes Fallback-System für Manufacturer-Detection

**Verbesserungsbedarf:**
- Port-basierte Manufacturer-Detection ist fehleranfällig
- Hardcodierte Port-Listen
- Keine iOS-Implementierung für MAC-Adressen

### DeviceInfo.swift
**Bewertung:** 9/10

**Positiv:**
- Sauber definiertes Model
- Korrekte Hashable/Equatable-Implementierung
- Sinnvolle `aliasKey`-Logik

**Verbesserungsbedarf:**
- `isExpanded` sollte nicht im Model sein (View-State)
- Könnte als `Sendable` markiert werden für Thread-Safety

### IPAddressValidator.swift
**Bewertung:** 8/10

**Positiv:**
- Korrekte IPv4-Validierung
- Lehnt führende Nullen ab (Security best practice)
- Einfach und testbar

**Verbesserungsbedarf:**
- Fehlen von IPv6-Unterstützung
- Keine Validierung von Broadcast/Multicast-Adressen
- Könnte CIDR-Notation unterstützen

### ContentView.swift
**Bewertung:** 8/10

**Positiv:**
- Saubere Platform-Abstraktion
- Minimaler View-Code

**Verbesserungsbedarf:**
- Scanner sollte nicht in ContentView erstellt werden (Dependency Injection)

---

## 🔧 Quick Wins (Einfache Verbesserungen)

1. **Constants als Enums:**
```swift
enum UserDefaultsKeys {
    static let customPorts = "customPorts"
    static let lastScanResults = "lastScanResults"
    // ...
}
```

2. **Magic Numbers entfernen:**
```swift
// Vorher:
workerQueue.maxConcurrentOperationCount = 12

// Nachher:
enum ScanConfiguration {
    static let maxConcurrentIPScans = 12
    static let maxConcurrentDeviceScans = 4
    static let maxRecentNetworks = 3
}
```

3. **Optional-Handling verbessern:**
```swift
// Vorher:
let hostName = self.rememberedHostName(ip: device.ipAddress, mac: macAddress)
    ?? self.usefulHostName(resolvedDNS)
    ?? self.usefulHostName(cached?.hostName)
    ?? self.usefulHostName(device.hostName)
    ?? "Unknown"

// Nachher:
let hostName = [
    rememberedHostName(ip: device.ipAddress, mac: macAddress),
    usefulHostName(resolvedDNS),
    cached.flatMap(\.hostName).flatMap(usefulHostName),
    usefulHostName(device.hostName)
].first(where: { $0 != nil }) ?? "Unknown"
```

4. **Computed Properties statt Methoden:**
```swift
// DeviceInfo.swift ist hier gut, aber könnte erweitert werden:
var displayName: String {
    rememberedAlias ?? hostName
}

var isReachable: Bool {
    status != .missing
}
```

---

## 📈 Metriken

### Code-Komplexität
- **Zyklomatische Komplexität:** Hoch in `resolveAndScanDevices` (>15)
- **Lines of Code:** ~1500 (ohne Tests)
- **Anzahl Extensions:** 11 (gut modularisiert)

### Test-Coverage
- **Unit Tests:** ~5% (sehr niedrig)
- **Integration Tests:** 0%
- **UI Tests:** Minimal (nur LaunchTests)

**Empfehlung:** Erhöhung auf mindestens 60% Coverage

---

## 🎯 Priorisierte Roadmap

### Phase 1: Stabilität (1-2 Wochen)
1. ✅ Fehlerbehandlung verbessern
2. ✅ Memory Leaks beheben
3. ✅ Unit Tests für kritische Komponenten

### Phase 2: Modernisierung (2-3 Wochen)
1. ✅ Migration zu Swift Concurrency
2. ✅ Refactoring der langen Methoden
3. ✅ UserDefaults-Abstraction

### Phase 3: Features & Polish (1-2 Wochen)
1. ✅ Performance-Optimierungen
2. ✅ Localization
3. ✅ Accessibility

---

## 🌟 Positive Aspekte

1. **Architektur:** Gute Verwendung von Extensions zur Modularisierung
2. **SwiftUI Integration:** Saubere Observable-Pattern-Nutzung
3. **Platform Support:** Gute iOS/macOS-Abstraktion
4. **Feature-Kompletheit:** Umfassende Scanning-Funktionalität
5. **Low-Level-Code:** Solide Socket-Programmierung

---

## 📝 Abschließende Bemerkungen

Das Projekt zeigt insgesamt eine solide Code-Qualität und ist funktional gut umgesetzt. Die größten Verbesserungspotenziale liegen in:

1. **Modernisierung der Concurrency-Patterns**
2. **Robustere Fehlerbehandlung**
3. **Erhöhung der Test-Coverage**
4. **Code-Dokumentation**

Mit den vorgeschlagenen Verbesserungen kann die Code-Qualität auf 9/10 gehoben werden.

---

**Nächste Schritte:**
- [ ] Priorisierung der Verbesserungsvorschläge mit dem Team
- [ ] Erstellung von Issues für jede Kategorie
- [ ] Implementierung der Quick Wins
- [ ] Planung der Modernisierung (Swift Concurrency)
