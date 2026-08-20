import XCTest
@testable import TToolsIPScanner

/// Umfassende Integration Tests für Zusammenspiel der Komponenten.
final class IntegrationTests: XCTestCase {
    
    var scanner: NetworkScanner!
    
    override func setUp() {
        super.setUp()
        scanner = NetworkScanner()
    }
    
    override func tearDown() {
        scanner = nil
        super.tearDown()
    }
    
    // MARK: - Device Alias Integration
    
    func testIntegration_AliasLifecycle() {
        // Given: Device
        let device = DeviceInfo(
            ipAddress: "192.168.1.100",
            hostName: "original-hostname",
            macAddress: "AA:BB:CC:DD:EE:01",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        
        // When: Alias wird gesetzt
        let alias = DeviceAlias(customName: "My Device", notes: "Test notes")
        scanner.setDeviceAlias(for: device, alias: alias)
        
        // Then: Alias kann über IP und MAC abgerufen werden
        XCTAssertEqual(
            scanner.rememberedHostName(ip: device.ipAddress, mac: device.macAddress),
            "My Device"
        )
        XCTAssertEqual(
            scanner.rememberedHostName(ip: device.ipAddress),
            "My Device"
        )
        
        // When: Alias wird entfernt
        scanner.removeDeviceAlias(for: device)
        
        // Then: Alias ist nicht mehr vorhanden
        XCTAssertNil(scanner.rememberedHostName(ip: device.ipAddress, mac: device.macAddress))
    }
    
    func testIntegration_AliasMigration() {
        // Given: Device ohne MAC, Alias wird über IP gesetzt
        var device = DeviceInfo(
            ipAddress: "192.168.1.100",
            hostName: "hostname",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        
        let alias = DeviceAlias(customName: "Device Name", notes: "")
        scanner.setDeviceAlias(for: device, alias: alias)
        
        // When: MAC wird später entdeckt und migriert
        device.macAddress = "AA:BB:CC:DD:EE:02"
        scanner.migrateAliasIfNeeded(ip: device.ipAddress, mac: device.macAddress)
        
        // Then: Alias ist über beide Keys erreichbar
        XCTAssertEqual(scanner.rememberedHostName(ip: device.ipAddress), "Device Name")
        XCTAssertEqual(scanner.rememberedHostName(ip: device.ipAddress, mac: device.macAddress), "Device Name")
        
        // And: Auch wenn IP sich ändert, ist Alias über MAC noch verfügbar
        XCTAssertEqual(scanner.rememberedHostName(ip: "192.168.1.999", mac: device.macAddress), "Device Name")
    }
    
    func testIntegration_AliasPersistence() {
        // Given: Alias wird gesetzt
        let device = DeviceInfo(
            ipAddress: "192.168.1.100",
            hostName: "hostname",
            macAddress: "AA:BB:CC:DD:EE:03",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        
        scanner.setDeviceAlias(for: device, alias: DeviceAlias(customName: "Persistent Device", notes: ""))
        
        // Then: Alias ist im deviceAliases Dictionary
        XCTAssertNotNil(scanner.deviceAliases[device.aliasKey])
        XCTAssertEqual(scanner.deviceAliases[device.aliasKey]?.customName, "Persistent Device")
    }
    
    // MARK: - Sorting Integration
    
    func testIntegration_SortingByIP() {
        // Given: Unsortierte Devices
        scanner.devices = [
            DeviceInfo(ipAddress: "192.168.1.20", hostName: "B", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.2", hostName: "A", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.100", hostName: "C", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false)
        ]
        
        // When: Nach IP sortiert (aufsteigend)
        scanner.sortOption = .ip
        scanner.sortAscending = true
        scanner.sortDevices()
        
        // Then: Numerisch korrekt sortiert
        let ips = scanner.devices.map { $0.ipAddress }
        XCTAssertEqual(ips, ["192.168.1.2", "192.168.1.20", "192.168.1.100"])
    }
    
    func testIntegration_SortingByHostname() {
        // Given: Devices mit verschiedenen Hostnamen
        scanner.devices = [
            DeviceInfo(ipAddress: "192.168.1.1", hostName: "Zebra", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.2", hostName: "Alpha", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.3", hostName: "Beta", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false)
        ]
        
        // When: Nach Hostname sortiert
        scanner.sortOption = .hostname
        scanner.sortAscending = true
        scanner.sortDevices()
        
        // Then: Alphabetisch sortiert
        let hostnames = scanner.devices.map { $0.hostName }
        XCTAssertEqual(hostnames, ["Alpha", "Beta", "Zebra"])
    }
    
    func testIntegration_SortingDescending() {
        // Given: Devices
        scanner.devices = [
            DeviceInfo(ipAddress: "192.168.1.1", hostName: "A", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.2", hostName: "B", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.3", hostName: "C", macAddress: "", manufacturer: "", openPorts: [], status: .current, isExpanded: false)
        ]
        
        // When: Descending sortiert
        scanner.sortOption = .hostname
        scanner.sortAscending = false
        scanner.sortDevices()
        
        // Then: Umgekehrt sortiert
        let hostnames = scanner.devices.map { $0.hostName }
        XCTAssertEqual(hostnames, ["C", "B", "A"])
    }
    
    // MARK: - Device Status Integration
    
    func testIntegration_DeviceStatusTracking() {
        // Given: Erster Scan
        let firstScanIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        scanner.previousDevices = firstScanIPs
        
        // When: Zweiter Scan mit neuen und fehlenden Devices
        let secondScanIPs = ["192.168.1.1", "192.168.1.2", "192.168.1.99"]
        
        let newDevices = secondScanIPs.map { ip in
            DeviceInfo(
                ipAddress: ip,
                hostName: "",
                macAddress: "",
                manufacturer: "",
                openPorts: [],
                status: DeviceStatusResolver.status(for: ip, previousIPs: firstScanIPs),
                isExpanded: false
            )
        }
        
        // Then: Status wird korrekt zugewiesen
        let currentCount = newDevices.filter { $0.status == .current }.count
        let newCount = newDevices.filter { $0.status == .new }.count
        XCTAssertEqual(currentCount, 2)  // 192.168.1.1 und .2
        XCTAssertEqual(newCount, 1)      // 192.168.1.99
        
        // And: Fehlende Devices werden identifiziert
        let missing = DeviceStatusResolver.missingIPs(
            previousIPs: firstScanIPs,
            foundIPs: Set(secondScanIPs)
        )
        XCTAssertEqual(missing, ["192.168.1.3"])
    }
    
    // MARK: - OUI Lookup Integration
    
    func testIntegration_OUILookup() {
        // Given: OUI Database mit Test-Entries
        scanner.ouiDatabase = [
            "AABBCC": "Test Vendor",
            "001A11": "Google",
            "B827EB": "Raspberry Pi Foundation"
        ]
        
        // When: Device mit MACs
        let macs = [
            "AA:BB:CC:DD:EE:FF",
            "00:1A:11:22:33:44",
            "B8:27:EB:99:88:77",
            "XX:XX:XX:XX:XX:XX"  // Unbekannt
        ]
        
        // Then: OUI-Lookup funktioniert
        for mac in macs {
            let oui = String(mac.prefix(8).filter { $0 != ":" }).uppercased()
            let vendor = scanner.ouiDatabase[oui]
            
            switch mac {
            case "AA:BB:CC:DD:EE:FF":
                XCTAssertEqual(vendor, "Test Vendor")
            case "00:1A:11:22:33:44":
                XCTAssertEqual(vendor, "Google")
            case "B8:27:EB:99:88:77":
                XCTAssertEqual(vendor, "Raspberry Pi Foundation")
            default:
                XCTAssertNil(vendor)
            }
        }
    }
    
    // MARK: - Port Scanning Integration
    
    func testIntegration_CustomPorts() {
        // Given: Custom Ports werden gesetzt
        let customPorts: Set<Int> = [22, 80, 443, 8080, 3389]
        scanner.updateCustomPorts(customPorts)
        
        // Then: Ports sind gesetzt
        XCTAssertEqual(scanner.customPorts, customPorts)
        
        // When: Ports werden formatiert
        let formatted = PortListParser.format(scanner.customPorts)
        
        // Then: Format ist korrekt
        XCTAssertEqual(formatted, "22, 80, 443, 3389, 8080")
        
        // When: Ports werden wieder geparst
        let reparsed = PortListParser.parse(formatted)
        
        // Then: Identisch mit Original
        XCTAssertEqual(reparsed, customPorts)
    }
    
    // MARK: - Network Validation Integration
    
    func testIntegration_NetworkValidation() {
        // Given: Verschiedene Netzwerk-Inputs
        let validNetworks = [
            "192.168.1.0",
            "10.0.0.0",
            "172.16.0.0"
        ]
        
        let invalidNetworks = [
            "256.1.1.0",
            "192.168.1",
            "abc.def.ghi.jkl"
        ]
        
        // Then: Validation funktioniert
        for network in validNetworks {
            XCTAssertTrue(
                IPAddressValidator.isValidIPv4(network),
                "Expected '\(network)' to be valid"
            )
        }
        
        for network in invalidNetworks {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(network),
                "Expected '\(network)' to be invalid"
            )
        }
    }
    
    // MARK: - Scan Settings Integration
    
    func testIntegration_ScanModePreference() {
        // Given: Initial Mode (kann aus UserDefaults geladen sein)
        let initialMode = scanner.preferredScanMode
        
        // When: Mode wird gewechselt
        let newMode: ScanMode = (initialMode == .quickScan) ? .fullScan : .quickScan
        scanner.preferredScanMode = newMode
        
        // Then: Mode ist geändert
        XCTAssertEqual(scanner.preferredScanMode, newMode)
        
        // When: Zurück zum anderen Mode
        let otherMode: ScanMode = (newMode == .quickScan) ? .fullScan : .quickScan
        scanner.preferredScanMode = otherMode
        
        // Then: Mode ist wieder geändert
        XCTAssertEqual(scanner.preferredScanMode, otherMode)
    }
    
    // MARK: - Full Workflow Integration
    
    func testIntegration_CompleteWorkflow() {
        // Scenario: Kompletter Scan-Workflow
        
        // 1. Initial Setup
        scanner.updateCustomPorts([80, 443, 22])
        scanner.sortOption = .ip
        scanner.sortAscending = true
        
        // 2. Erster Scan (simuliert)
        let firstScanDevices = [
            DeviceInfo(ipAddress: "192.168.1.1", hostName: "Router", macAddress: "AA:BB:CC:00:00:01", manufacturer: "", openPorts: [80, 443], status: .new, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.10", hostName: "PC", macAddress: "AA:BB:CC:00:00:02", manufacturer: "", openPorts: [22], status: .new, isExpanded: false)
        ]
        scanner.devices = firstScanDevices
        scanner.previousDevices = Set(firstScanDevices.map { $0.ipAddress })
        
        // 3. Alias wird für Router gesetzt
        scanner.setDeviceAlias(
            for: firstScanDevices[0],
            alias: DeviceAlias(customName: "Main Router", notes: "Living room")
        )
        
        // 4. Zweiter Scan (simuliert) - PC offline, neues Gerät online
        let secondScanIPs = ["192.168.1.1", "192.168.1.99"]
        let secondScanDevices = secondScanIPs.map { ip in
            DeviceInfo(
                ipAddress: ip,
                hostName: ip == "192.168.1.1" ? "Router" : "New Device",
                macAddress: ip == "192.168.1.1" ? "AA:BB:CC:00:00:01" : "AA:BB:CC:00:00:03",
                manufacturer: "",
                openPorts: [],
                status: DeviceStatusResolver.status(for: ip, previousIPs: scanner.previousDevices),
                isExpanded: false
            )
        }
        scanner.devices = secondScanDevices
        
        // Assertions:
        
        // Router hat Status .current
        let router = scanner.devices.first { $0.ipAddress == "192.168.1.1" }
        XCTAssertNotNil(router)
        XCTAssertEqual(router?.status, .current)
        
        // Router Alias ist noch vorhanden
        XCTAssertEqual(
            scanner.rememberedHostName(ip: "192.168.1.1", mac: "AA:BB:CC:00:00:01"),
            "Main Router"
        )
        
        // Neues Gerät hat Status .new
        let newDevice = scanner.devices.first { $0.ipAddress == "192.168.1.99" }
        XCTAssertNotNil(newDevice)
        XCTAssertEqual(newDevice?.status, .new)
        
        // PC fehlt
        let missing = DeviceStatusResolver.missingIPs(
            previousIPs: scanner.previousDevices,
            foundIPs: Set(secondScanIPs)
        )
        XCTAssertTrue(missing.contains("192.168.1.10"))
    }
    
    // MARK: - Recent Networks Integration
    
    func testIntegration_RecentNetworksTracking() {
        // Given: Initial count (kann bereits Networks aus UserDefaults haben)
        let initialCount = scanner.recentNetworks.count
        
        // When: Neue Netzwerke werden gesetzt
        let testNetworks = ["192.168.1.0", "10.0.0.0", "172.16.0.0"]
        scanner.recentNetworks = testNetworks
        
        // Then: Networks sind korrekt gesetzt
        XCTAssertEqual(scanner.recentNetworks.count, 3)
        XCTAssertTrue(scanner.recentNetworks.contains("192.168.1.0"))
        XCTAssertTrue(scanner.recentNetworks.contains("10.0.0.0"))
        XCTAssertTrue(scanner.recentNetworks.contains("172.16.0.0"))
        
        // Cleanup: Restore initial state (optional)
        // scanner.recentNetworks = []
    }
    
    // MARK: - Error Handling Integration
    
    func testIntegration_InvalidInputHandling() {
        // Scenario: Ungültige Inputs werden korrekt behandelt
        
        // Invalid IP
        let invalidIP = "999.999.999.999"
        XCTAssertFalse(IPAddressValidator.isValidIPv4(invalidIP))
        
        // Invalid Ports
        let invalidPorts = "abc, -1, 99999"
        let parsed = PortListParser.parse(invalidPorts)
        XCTAssertEqual(parsed, [])  // Alle ungültig
        
        // Invalid OUI Line
        let invalidOUILine = "Invalid Line Without Tab"
        XCTAssertNil(OUIParser.parseLine(invalidOUILine))
    }
    
    // MARK: - Performance Integration
    
    func testIntegration_LargeDeviceList() {
        // Given: Viele Devices (Performance Test)
        var devices: [DeviceInfo] = []
        for i in 0..<1000 {
            devices.append(DeviceInfo(
                ipAddress: "192.168.\(i / 256).\(i % 256)",
                hostName: "Device-\(i)",
                macAddress: String(format: "AA:BB:CC:DD:%02X:%02X", i / 256, i % 256),
                manufacturer: "",
                openPorts: [],
                status: .current,
                isExpanded: false
            ))
        }
        
        // When: Devices werden gesetzt und sortiert
        measure {
            scanner.devices = devices
            scanner.sortOption = .ip
            scanner.sortDevices()
        }
        
        // Then: Sortierung hat funktioniert
        XCTAssertEqual(scanner.devices.count, 1000)
        XCTAssertEqual(scanner.devices.first?.ipAddress, "192.168.0.0")
        XCTAssertEqual(scanner.devices.last?.ipAddress, "192.168.3.231")
    }
    
    // MARK: - Data Persistence Integration
    
    func testIntegration_SaveAndLoadSettings() {
        // Given: Scanner mit Daten
        scanner.customPorts = [22, 80, 443]
        scanner.recentNetworks = ["192.168.1.0", "10.0.0.0"]
        scanner.devices = [
            DeviceInfo(ipAddress: "192.168.1.1", hostName: "Router", macAddress: "AA:BB:CC:DD:EE:01", manufacturer: "", openPorts: [], status: .current, isExpanded: false)
        ]
        
        // When: Settings werden gespeichert
        scanner.saveSettings()
        
        // Then: Daten sind persistent (würden in UserDefaults gespeichert)
        // Note: Dieser Test prüft nur, dass saveSettings nicht crasht
        // Die tatsächliche Persistenz wird in SettingsManagerTests getestet
    }
}
