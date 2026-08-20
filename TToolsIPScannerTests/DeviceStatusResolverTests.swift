import XCTest
@testable import TToolsIPScanner

/// Umfassende Tests für DeviceStatusResolver.
final class DeviceStatusResolverTests: XCTestCase {
    
    // MARK: - status(for:previousIPs:) Tests
    
    func testStatus_NewDevice() {
        // Given: Leeres Previous-Set
        let previousIPs: Set<String> = []
        let ip = "192.168.1.1"
        
        // When: Status wird ermittelt
        let status = DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        
        // Then: Device ist neu
        XCTAssertEqual(status, .new)
    }
    
    func testStatus_CurrentDevice() {
        // Given: IP ist in Previous-Set vorhanden
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2"]
        let ip = "192.168.1.1"
        
        // When: Status wird ermittelt
        let status = DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        
        // Then: Device ist current
        XCTAssertEqual(status, .current)
    }
    
    func testStatus_NewDeviceWithOtherPreviousDevices() {
        // Given: IP ist NICHT in Previous-Set
        let previousIPs: Set<String> = ["192.168.1.10", "192.168.1.20"]
        let ip = "192.168.1.99"
        
        // When: Status wird ermittelt
        let status = DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        
        // Then: Device ist neu
        XCTAssertEqual(status, .new)
    }
    
    func testStatus_MultipleIPs() {
        // Given: Mehrere IPs und Previous-Set
        let previousIPs: Set<String> = ["192.168.1.10", "192.168.1.20", "192.168.1.30"]
        
        let testCases: [(ip: String, expected: DeviceStatus)] = [
            ("192.168.1.10", .current),
            ("192.168.1.20", .current),
            ("192.168.1.30", .current),
            ("192.168.1.99", .new),
            ("192.168.1.1", .new),
            ("10.0.0.1", .new)
        ]
        
        // When/Then: Status für jede IP wird korrekt ermittelt
        for testCase in testCases {
            let status = DeviceStatusResolver.status(for: testCase.ip, previousIPs: previousIPs)
            XCTAssertEqual(
                status,
                testCase.expected,
                "Failed for IP '\(testCase.ip)'"
            )
        }
    }
    
    func testStatus_EmptyIP() {
        // Given: Leerer IP-String
        let previousIPs: Set<String> = ["192.168.1.1"]
        let ip = ""
        
        // When: Status wird ermittelt
        let status = DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        
        // Then: Device ist neu (leerer String ist nicht in Set)
        XCTAssertEqual(status, .new)
    }
    
    func testStatus_CaseSensitivity() {
        // Given: IPs mit verschiedenen Cases
        let previousIPs: Set<String> = ["192.168.1.1"]
        
        // When/Then: IP-Adressen sind case-sensitive (auch wenn unüblich)
        XCTAssertEqual(DeviceStatusResolver.status(for: "192.168.1.1", previousIPs: previousIPs), .current)
        // Note: In der Praxis sollten IPs nur Zahlen und Punkte enthalten
    }
    
    func testStatus_WithSpecialCharacters() {
        // Given: IPs mit Sonderzeichen (ungültig, aber testen wir das Verhalten)
        let previousIPs: Set<String> = ["192.168.1.1!"]
        let ip = "192.168.1.1!"
        
        // When: Status wird ermittelt
        let status = DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        
        // Then: Exakte String-Übereinstimmung
        XCTAssertEqual(status, .current)
    }
    
    // MARK: - missingIPs Tests
    
    func testMissingIPs_AllDevicesFound() {
        // Given: Alle Previous-IPs sind auch in Found-Set
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        let foundIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Keine IPs fehlen
        XCTAssertEqual(missing, [])
    }
    
    func testMissingIPs_SomeDevicesMissing() {
        // Given: Einige Previous-IPs fehlen in Found-Set
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        let foundIPs: Set<String> = ["192.168.1.1"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: 2 IPs fehlen
        XCTAssertEqual(missing, ["192.168.1.2", "192.168.1.3"])
    }
    
    func testMissingIPs_AllDevicesMissing() {
        // Given: Alle Previous-IPs fehlen
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        let foundIPs: Set<String> = []
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Alle IPs fehlen
        XCTAssertEqual(missing, previousIPs)
    }
    
    func testMissingIPs_NoPreviousDevices() {
        // Given: Keine Previous-IPs
        let previousIPs: Set<String> = []
        let foundIPs: Set<String> = ["192.168.1.1", "192.168.1.2"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Keine IPs fehlen
        XCTAssertEqual(missing, [])
    }
    
    func testMissingIPs_NewDevicesAdded() {
        // Given: Found-Set enthält neue IPs
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2"]
        let foundIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.99", "192.168.1.100"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Keine IPs fehlen (neue IPs werden ignoriert)
        XCTAssertEqual(missing, [])
    }
    
    func testMissingIPs_CompletelyDifferentSets() {
        // Given: Komplett verschiedene Sets
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2"]
        let foundIPs: Set<String> = ["10.0.0.1", "10.0.0.2"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Alle Previous-IPs fehlen
        XCTAssertEqual(missing, previousIPs)
    }
    
    func testMissingIPs_PartialOverlap() {
        // Given: Teilweise Überlappung
        let previousIPs: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3", "192.168.1.4"]
        let foundIPs: Set<String> = ["192.168.1.2", "192.168.1.4", "192.168.1.99"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Die fehlenden IPs werden identifiziert
        XCTAssertEqual(missing, ["192.168.1.1", "192.168.1.3"])
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_TypicalScanScenario() {
        // Given: Realistisches Scan-Szenario
        // Erster Scan: 4 Devices gefunden
        let firstScanIPs: Set<String> = [
            "192.168.1.1",   // Router
            "192.168.1.10",  // PC
            "192.168.1.20",  // Laptop
            "192.168.1.30"   // Phone
        ]
        
        // Zweiter Scan: Laptop offline, neues Tablet online
        let secondScanIPs: Set<String> = [
            "192.168.1.1",   // Router (still online)
            "192.168.1.10",  // PC (still online)
            "192.168.1.30",  // Phone (still online)
            "192.168.1.99"   // Tablet (new)
        ]
        
        // When: Status für jeden Second-Scan-IP
        let statuses = secondScanIPs.map { ip in
            (ip: ip, status: DeviceStatusResolver.status(for: ip, previousIPs: firstScanIPs))
        }
        
        // Then: Korrekte Status-Zuordnung
        XCTAssertEqual(statuses.filter { $0.status == .current }.count, 3)  // Router, PC, Phone
        XCTAssertEqual(statuses.filter { $0.status == .new }.count, 1)      // Tablet
        
        // And: Missing IP identifiziert
        let missing = DeviceStatusResolver.missingIPs(previousIPs: firstScanIPs, foundIPs: secondScanIPs)
        XCTAssertEqual(missing, ["192.168.1.20"])  // Laptop
    }
    
    func testIntegration_FirstScan() {
        // Given: Erster Scan (keine Previous-IPs)
        let previousIPs: Set<String> = []
        let foundIPs: Set<String> = [
            "192.168.1.1",
            "192.168.1.10",
            "192.168.1.20"
        ]
        
        // When: Status für alle gefundenen IPs
        let statuses = foundIPs.map { ip in
            DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        }
        
        // Then: Alle sind neu
        XCTAssertTrue(statuses.allSatisfy { $0 == .new })
        
        // And: Keine IPs fehlen
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        XCTAssertEqual(missing, [])
    }
    
    func testIntegration_AllDevicesOffline() {
        // Given: Alle Devices waren online, jetzt alle offline
        let previousIPs: Set<String> = [
            "192.168.1.1",
            "192.168.1.10",
            "192.168.1.20"
        ]
        let foundIPs: Set<String> = []
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Alle IPs fehlen
        XCTAssertEqual(missing, previousIPs)
    }
    
    func testIntegration_NetworkChange() {
        // Given: Netzwerkwechsel (komplett neue IPs)
        let previousIPs: Set<String> = [
            "192.168.1.1",
            "192.168.1.10",
            "192.168.1.20"
        ]
        let foundIPs: Set<String> = [
            "10.0.0.1",
            "10.0.0.10",
            "10.0.0.20"
        ]
        
        // When: Status und Missing werden ermittelt
        let statuses = foundIPs.map { ip in
            DeviceStatusResolver.status(for: ip, previousIPs: previousIPs)
        }
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Alle Found-IPs sind neu, alle Previous-IPs fehlen
        XCTAssertTrue(statuses.allSatisfy { $0 == .new })
        XCTAssertEqual(missing, previousIPs)
    }
    
    // MARK: - Edge Cases
    
    func testEdgeCase_BothSetsEmpty() {
        // Given: Beide Sets leer
        let previousIPs: Set<String> = []
        let foundIPs: Set<String> = []
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: Keine IPs fehlen
        XCTAssertEqual(missing, [])
    }
    
    func testEdgeCase_IdenticalSets() {
        // Given: Identische Sets
        let ips: Set<String> = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: ips, foundIPs: ips)
        
        // Then: Keine IPs fehlen
        XCTAssertEqual(missing, [])
        
        // And: Alle sind current
        for ip in ips {
            XCTAssertEqual(DeviceStatusResolver.status(for: ip, previousIPs: ips), .current)
        }
    }
    
    func testEdgeCase_LargeSet() {
        // Given: Großes Set (1000 IPs)
        let previousIPs = Set((1...1000).map { "192.168.\($0 / 256).\($0 % 256)" })
        let foundIPs = Set((1...500).map { "192.168.\($0 / 256).\($0 % 256)" })
        
        // When: Missing IPs werden ermittelt
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: 500 IPs fehlen
        XCTAssertEqual(missing.count, 500)
    }
    
    func testEdgeCase_InvalidIPFormats() {
        // Given: "Ungültige" IP-Strings (werden trotzdem als Strings behandelt)
        let previousIPs: Set<String> = ["invalid-ip", "192.168.1.999", "abc"]
        let foundIPs: Set<String> = ["invalid-ip", "xyz"]
        
        // When: Status und Missing werden ermittelt
        let status1 = DeviceStatusResolver.status(for: "invalid-ip", previousIPs: previousIPs)
        let status2 = DeviceStatusResolver.status(for: "xyz", previousIPs: previousIPs)
        let missing = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        
        // Then: String-Vergleich funktioniert auch bei ungültigen IPs
        XCTAssertEqual(status1, .current)
        XCTAssertEqual(status2, .new)
        XCTAssertEqual(missing, ["192.168.1.999", "abc"])
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_StatusCheck() {
        let previousIPs = Set((1...1000).map { "192.168.\($0 / 256).\($0 % 256)" })
        
        measure {
            for _ in 0..<1000 {
                _ = DeviceStatusResolver.status(for: "192.168.1.1", previousIPs: previousIPs)
            }
        }
    }
    
    func testPerformance_MissingIPsLargeSet() {
        let previousIPs = Set((1...1000).map { "192.168.\($0 / 256).\($0 % 256)" })
        let foundIPs = Set((1...500).map { "192.168.\($0 / 256).\($0 % 256)" })
        
        measure {
            _ = DeviceStatusResolver.missingIPs(previousIPs: previousIPs, foundIPs: foundIPs)
        }
    }
}
