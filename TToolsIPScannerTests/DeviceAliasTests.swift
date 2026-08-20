import XCTest
@testable import TToolsIPScanner

/// Umfassende Tests für DeviceAlias Model.
final class DeviceAliasTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInit_BothValues() {
        // Given: Name und Notes
        let alias = DeviceAlias(customName: "Router", notes: "Main router in living room")
        
        // Then: Beide Properties sind gesetzt
        XCTAssertEqual(alias.customName, "Router")
        XCTAssertEqual(alias.notes, "Main router in living room")
    }
    
    func testInit_OnlyName() {
        // Given: Nur Name
        let alias = DeviceAlias(customName: "My Device", notes: "")
        
        // Then: Name ist gesetzt, Notes ist leer
        XCTAssertEqual(alias.customName, "My Device")
        XCTAssertEqual(alias.notes, "")
    }
    
    func testInit_OnlyNotes() {
        // Given: Nur Notes (unüblich, aber möglich)
        let alias = DeviceAlias(customName: "", notes: "Some notes")
        
        // Then: Notes ist gesetzt, Name ist leer
        XCTAssertEqual(alias.customName, "")
        XCTAssertEqual(alias.notes, "Some notes")
    }
    
    func testInit_EmptyBoth() {
        // Given: Beides leer
        let alias = DeviceAlias(customName: "", notes: "")
        
        // Then: Beide Properties sind leer
        XCTAssertEqual(alias.customName, "")
        XCTAssertEqual(alias.notes, "")
    }
    
    // MARK: - Codable Tests
    
    func testCodable_EncodeAndDecode() throws {
        // Given: Alias mit beiden Feldern
        let original = DeviceAlias(
            customName: "Living Room TV",
            notes: "Samsung Smart TV, bought 2023"
        )
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceAlias.self, from: encoded)
        
        // Then: Alle Properties bleiben erhalten
        XCTAssertEqual(decoded.customName, original.customName)
        XCTAssertEqual(decoded.notes, original.notes)
    }
    
    func testCodable_EmptyValues() throws {
        // Given: Alias mit leeren Werten
        let original = DeviceAlias(customName: "", notes: "")
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceAlias.self, from: encoded)
        
        // Then: Leere Werte bleiben erhalten
        XCTAssertEqual(decoded.customName, "")
        XCTAssertEqual(decoded.notes, "")
    }
    
    func testCodable_DictionaryOfAliases() throws {
        // Given: Dictionary von Aliases
        let aliases: [String: DeviceAlias] = [
            "192.168.1.1": DeviceAlias(customName: "Router", notes: "Main router"),
            "AA:BB:CC:DD:EE:FF": DeviceAlias(customName: "PC", notes: "Work PC"),
            "192.168.1.10": DeviceAlias(customName: "Printer", notes: "")
        ]
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(aliases)
        let decoded = try JSONDecoder().decode([String: DeviceAlias].self, from: encoded)
        
        // Then: Dictionary bleibt identisch
        XCTAssertEqual(decoded.count, aliases.count)
        XCTAssertEqual(decoded["192.168.1.1"]?.customName, "Router")
        XCTAssertEqual(decoded["AA:BB:CC:DD:EE:FF"]?.customName, "PC")
        XCTAssertEqual(decoded["192.168.1.10"]?.notes, "")
    }
    
    func testCodable_SpecialCharacters() throws {
        // Given: Alias mit Sonderzeichen
        let original = DeviceAlias(
            customName: "Müller's PC ☺️",
            notes: "Notes with emoji 🖥️ and umlauts: äöü ÄÖÜ ß"
        )
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceAlias.self, from: encoded)
        
        // Then: Sonderzeichen bleiben erhalten
        XCTAssertEqual(decoded.customName, original.customName)
        XCTAssertEqual(decoded.notes, original.notes)
    }
    
    func testCodable_LongStrings() throws {
        // Given: Alias mit langen Strings
        let longName = String(repeating: "A", count: 1000)
        let longNotes = String(repeating: "Note ", count: 200)
        let original = DeviceAlias(customName: longName, notes: longNotes)
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceAlias.self, from: encoded)
        
        // Then: Lange Strings bleiben erhalten
        XCTAssertEqual(decoded.customName.count, 1000)
        XCTAssertEqual(decoded.notes.count, 1000)  // "Note " * 200
    }
    
    // MARK: - Mutability Tests
    
    func testMutability_ChangeName() {
        // Given: Alias
        var alias = DeviceAlias(customName: "OldName", notes: "Notes")
        
        // When: Name wird geändert
        alias.customName = "NewName"
        
        // Then: Änderung ist wirksam
        XCTAssertEqual(alias.customName, "NewName")
        XCTAssertEqual(alias.notes, "Notes")  // Notes unverändert
    }
    
    func testMutability_ChangeNotes() {
        // Given: Alias
        var alias = DeviceAlias(customName: "Name", notes: "Old notes")
        
        // When: Notes werden geändert
        alias.notes = "New notes"
        
        // Then: Änderung ist wirksam
        XCTAssertEqual(alias.customName, "Name")  // Name unverändert
        XCTAssertEqual(alias.notes, "New notes")
    }
    
    func testMutability_ChangeBoth() {
        // Given: Alias
        var alias = DeviceAlias(customName: "OldName", notes: "Old notes")
        
        // When: Beides wird geändert
        alias.customName = "NewName"
        alias.notes = "New notes"
        
        // Then: Beide Änderungen sind wirksam
        XCTAssertEqual(alias.customName, "NewName")
        XCTAssertEqual(alias.notes, "New notes")
    }
    
    func testMutability_ClearName() {
        // Given: Alias mit Name
        var alias = DeviceAlias(customName: "Name", notes: "Notes")
        
        // When: Name wird geleert
        alias.customName = ""
        
        // Then: Name ist leer
        XCTAssertEqual(alias.customName, "")
        XCTAssertEqual(alias.notes, "Notes")
    }
    
    func testMutability_ClearNotes() {
        // Given: Alias mit Notes
        var alias = DeviceAlias(customName: "Name", notes: "Notes")
        
        // When: Notes werden geleert
        alias.notes = ""
        
        // Then: Notes sind leer
        XCTAssertEqual(alias.customName, "Name")
        XCTAssertEqual(alias.notes, "")
    }
    
    // MARK: - Real World Scenarios
    
    func testRealWorld_SimpleAlias() {
        // Given: Einfacher Alias
        let alias = DeviceAlias(customName: "Router", notes: "")
        
        // Then: Name ist gesetzt, keine Notes
        XCTAssertEqual(alias.customName, "Router")
        XCTAssertTrue(alias.notes.isEmpty)
    }
    
    func testRealWorld_DetailedAlias() {
        // Given: Detaillierter Alias mit Notes
        let alias = DeviceAlias(
            customName: "Synology NAS",
            notes: "DS918+, 4TB, Located in server room, static IP 192.168.1.50"
        )
        
        // Then: Name und detaillierte Notes
        XCTAssertEqual(alias.customName, "Synology NAS")
        XCTAssertTrue(alias.notes.contains("DS918+"))
        XCTAssertTrue(alias.notes.contains("4TB"))
    }
    
    func testRealWorld_DeviceWithLocation() {
        // Given: Alias mit Standort
        let alias = DeviceAlias(
            customName: "Living Room TV",
            notes: "Location: Living Room, Floor 1"
        )
        
        // Then: Name und Standort-Info
        XCTAssertEqual(alias.customName, "Living Room TV")
        XCTAssertTrue(alias.notes.contains("Living Room"))
    }
    
    func testRealWorld_WorkDevice() {
        // Given: Arbeitsgerät
        let alias = DeviceAlias(
            customName: "Work Laptop",
            notes: "Owner: John Doe, Department: IT, MAC: AA:BB:CC:DD:EE:FF"
        )
        
        // Then: Name und Organisationsinfo
        XCTAssertEqual(alias.customName, "Work Laptop")
        XCTAssertTrue(alias.notes.contains("John Doe"))
        XCTAssertTrue(alias.notes.contains("IT"))
    }
    
    func testRealWorld_MultilingualAlias() {
        // Given: Mehrsprachiger Alias
        let alias = DeviceAlias(
            customName: "Büro Drucker",
            notes: "Standort: Erdgeschoss, Model: HP LaserJet"
        )
        
        // Then: Deutsche Umlaute funktionieren
        XCTAssertEqual(alias.customName, "Büro Drucker")
        XCTAssertTrue(alias.notes.contains("Erdgeschoss"))
    }
    
    // MARK: - Integration with DeviceInfo
    
    func testIntegration_AliasKey() {
        // Given: Device mit MAC
        let device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Original Name",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "",
            openPorts: [],
            status: .current,
            isExpanded: false
        )
        
        let alias = DeviceAlias(customName: "Custom Name", notes: "Notes")
        
        // When: Alias wird mit aliasKey verknüpft
        var aliases: [String: DeviceAlias] = [:]
        aliases[device.aliasKey] = alias
        
        // Then: Alias kann über aliasKey gefunden werden
        XCTAssertEqual(aliases[device.aliasKey]?.customName, "Custom Name")
        XCTAssertEqual(aliases["AA:BB:CC:DD:EE:FF"]?.customName, "Custom Name")
    }
    
    func testIntegration_MultipleDevicesSameAlias() {
        // Given: Mehrere Devices mit gleichem Alias-Namen (aber verschiedene Keys)
        let alias1 = DeviceAlias(customName: "Printer", notes: "Office printer")
        let alias2 = DeviceAlias(customName: "Printer", notes: "Home printer")
        
        var aliases: [String: DeviceAlias] = [:]
        aliases["192.168.1.10"] = alias1
        aliases["192.168.2.10"] = alias2
        
        // Then: Beide Aliases können koexistieren
        XCTAssertEqual(aliases.count, 2)
        XCTAssertNotEqual(aliases["192.168.1.10"]?.notes, aliases["192.168.2.10"]?.notes)
    }
    
    // MARK: - Edge Cases
    
    func testEdgeCase_OnlyWhitespace() {
        // Given: Nur Whitespace
        let alias = DeviceAlias(customName: "   ", notes: "   ")
        
        // Then: Whitespace bleibt erhalten (keine auto-trim)
        XCTAssertEqual(alias.customName, "   ")
        XCTAssertEqual(alias.notes, "   ")
    }
    
    func testEdgeCase_Newlines() {
        // Given: String mit Newlines
        let alias = DeviceAlias(
            customName: "Multi\nLine\nName",
            notes: "Line 1\nLine 2\nLine 3"
        )
        
        // Then: Newlines bleiben erhalten
        XCTAssertTrue(alias.customName.contains("\n"))
        XCTAssertTrue(alias.notes.contains("\n"))
    }
    
    func testEdgeCase_Tabs() {
        // Given: String mit Tabs
        let alias = DeviceAlias(
            customName: "Name\twith\ttabs",
            notes: "Notes\twith\ttabs"
        )
        
        // Then: Tabs bleiben erhalten
        XCTAssertTrue(alias.customName.contains("\t"))
        XCTAssertTrue(alias.notes.contains("\t"))
    }
    
    func testEdgeCase_UnicodeCharacters() {
        // Given: Various Unicode characters
        let alias = DeviceAlias(
            customName: "Device 🖥️ 💻 📱",
            notes: "Contains: ñ, é, ü, 中文, 日本語, 한글"
        )
        
        // Then: Unicode wird korrekt gespeichert
        XCTAssertTrue(alias.customName.contains("🖥️"))
        XCTAssertTrue(alias.notes.contains("中文"))
        XCTAssertTrue(alias.notes.contains("한글"))
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_CreateManyAliases() {
        measure {
            var aliases: [DeviceAlias] = []
            for i in 0..<1000 {
                let alias = DeviceAlias(
                    customName: "Device \(i)",
                    notes: "Notes for device number \(i)"
                )
                aliases.append(alias)
            }
        }
    }
    
    func testPerformance_EncodeDecodeAliases() throws {
        // Given: Dictionary mit vielen Aliases
        var aliases: [String: DeviceAlias] = [:]
        for i in 0..<1000 {
            let key = "192.168.\(i / 256).\(i % 256)"
            aliases[key] = DeviceAlias(customName: "Device \(i)", notes: "Notes \(i)")
        }
        
        // When/Then: Performance test
        measure {
            do {
                let encoded = try JSONEncoder().encode(aliases)
                _ = try JSONDecoder().decode([String: DeviceAlias].self, from: encoded)
            } catch {
                XCTFail("Encoding/Decoding failed: \(error)")
            }
        }
    }
}
