import XCTest
@testable import TToolsIPScanner

/// Umfassende Tests für DeviceInfo Model.
final class DeviceInfoTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInit_AllParameters() {
        // Given: Alle Parameter
        let id = UUID()
        let device = DeviceInfo(
            id: id,
            ipAddress: "192.168.1.1",
            hostName: "Router",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "Apple",
            openPorts: [80, 443],
            status: .active,
            isExpanded: true
        )
        
        // Then: Alle Properties sind korrekt gesetzt
        XCTAssertEqual(device.id, id)
        XCTAssertEqual(device.ipAddress, "192.168.1.1")
        XCTAssertEqual(device.hostName, "Router")
        XCTAssertEqual(device.macAddress, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(device.manufacturer, "Apple")
        XCTAssertEqual(device.openPorts, [80, 443])
        XCTAssertEqual(device.status, .active)
        XCTAssertTrue(device.isExpanded)
    }
    
    func testInit_DefaultID() {
        // Given: ID wird nicht angegeben
        let device1 = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device1",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        let device2 = DeviceInfo(
            ipAddress: "192.168.1.2",
            hostName: "Device2",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // Then: Unterschiedliche UUIDs werden generiert
        XCTAssertNotEqual(device1.id, device2.id)
    }
    
    func testInit_EmptyValues() {
        // Given: Leere Werte
        let device = DeviceInfo(
            ipAddress: "",
            hostName: "",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // Then: Leere Werte werden akzeptiert
        XCTAssertEqual(device.ipAddress, "")
        XCTAssertEqual(device.hostName, "")
        XCTAssertEqual(device.macAddress, "")
        XCTAssertEqual(device.manufacturer, "")
        XCTAssertEqual(device.openPorts, [])
    }
    
    // MARK: - aliasKey Tests
    
    func testAliasKey_WithMAC() {
        // Given: Device mit MAC-Adresse
        let device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Router",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: aliasKey wird abgerufen
        let key = device.aliasKey
        
        // Then: MAC wird bevorzugt
        XCTAssertEqual(key, "AA:BB:CC:DD:EE:FF")
    }
    
    func testAliasKey_WithoutMAC() {
        // Given: Device ohne MAC-Adresse
        let device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Router",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: aliasKey wird abgerufen
        let key = device.aliasKey
        
        // Then: IP wird verwendet
        XCTAssertEqual(key, "192.168.1.1")
    }
    
    func testAliasKey_EmptyBoth() {
        // Given: Beides leer (unwahrscheinlich, aber testen)
        let device = DeviceInfo(
            ipAddress: "",
            hostName: "",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: aliasKey wird abgerufen
        let key = device.aliasKey
        
        // Then: Leerer String (IP ist leer)
        XCTAssertEqual(key, "")
    }
    
    // MARK: - Equatable Tests
    
    func testEquality_SameID() {
        // Given: Zwei Devices mit gleicher ID
        let id = UUID()
        let device1 = DeviceInfo(
            id: id,
            ipAddress: "192.168.1.1",
            hostName: "Device1",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        let device2 = DeviceInfo(
            id: id,
            ipAddress: "192.168.1.2",
            hostName: "Device2",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "Apple",
            openPorts: [80],
            status: .missing,
            isExpanded: true
        )
        
        // Then: Devices sind gleich (ID ist entscheidend)
        XCTAssertEqual(device1, device2)
    }
    
    func testEquality_DifferentID() {
        // Given: Zwei Devices mit verschiedenen IDs (aber gleichen anderen Werten)
        let device1 = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        let device2 = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // Then: Devices sind ungleich (verschiedene IDs)
        XCTAssertNotEqual(device1, device2)
    }
    
    // MARK: - Hashable Tests
    
    func testHashable_SameID() {
        // Given: Zwei Devices mit gleicher ID
        let id = UUID()
        let device1 = DeviceInfo(
            id: id,
            ipAddress: "192.168.1.1",
            hostName: "Device1",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        let device2 = DeviceInfo(
            id: id,
            ipAddress: "192.168.1.2",
            hostName: "Device2",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .missing,
            isExpanded: true
        )
        
        // Then: Gleicher Hash
        XCTAssertEqual(device1.hashValue, device2.hashValue)
    }
    
    func testHashable_DifferentID() {
        // Given: Zwei Devices mit verschiedenen IDs
        let device1 = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        let device2 = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // Then: Verschiedene Hashes
        XCTAssertNotEqual(device1.hashValue, device2.hashValue)
    }
    
    func testHashable_InSet() {
        // Given: Devices in einem Set
        let id1 = UUID()
        let id2 = UUID()
        
        let device1a = DeviceInfo(id: id1, ipAddress: "192.168.1.1", hostName: "A", macAddress: "", manufacturer: "", openPorts: [], status: .active, isExpanded: false)
        let device1b = DeviceInfo(id: id1, ipAddress: "192.168.1.2", hostName: "B", macAddress: "", manufacturer: "", openPorts: [], status: .active, isExpanded: false)
        let device2 = DeviceInfo(id: id2, ipAddress: "192.168.1.3", hostName: "C", macAddress: "", manufacturer: "", openPorts: [], status: .active, isExpanded: false)
        
        // When: Set wird erstellt
        let set: Set<DeviceInfo> = [device1a, device1b, device2]
        
        // Then: Set enthält nur 2 Elemente (device1a und device1b haben gleiche ID)
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - Codable Tests
    
    func testCodable_EncodeAndDecode() throws {
        // Given: Device
        let original = DeviceInfo(
            id: UUID(),
            ipAddress: "192.168.1.1",
            hostName: "Router",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "Apple",
            openPorts: [80, 443, 8080],
            status: .active,
            isExpanded: true
        )
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: encoded)
        
        // Then: Alle Properties bleiben erhalten
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.ipAddress, original.ipAddress)
        XCTAssertEqual(decoded.hostName, original.hostName)
        XCTAssertEqual(decoded.macAddress, original.macAddress)
        XCTAssertEqual(decoded.manufacturer, original.manufacturer)
        XCTAssertEqual(decoded.openPorts, original.openPorts)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.isExpanded, original.isExpanded)
    }
    
    func testCodable_ArrayOfDevices() throws {
        // Given: Array von Devices
        let devices = [
            DeviceInfo(ipAddress: "192.168.1.1", hostName: "Router", macAddress: "AA:BB:CC:DD:EE:01", manufacturer: "Apple", openPorts: [80], status: .active, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.2", hostName: "PC", macAddress: "AA:BB:CC:DD:EE:02", manufacturer: "Dell", openPorts: [22, 3389], status: .current, isExpanded: true),
            DeviceInfo(ipAddress: "192.168.1.3", hostName: "Printer", macAddress: "", manufacturer: "", openPorts: [], status: .new, isExpanded: false)
        ]
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(devices)
        let decoded = try JSONDecoder().decode([DeviceInfo].self, from: encoded)
        
        // Then: Array bleibt identisch
        XCTAssertEqual(decoded.count, devices.count)
        for (original, decodedDevice) in zip(devices, decoded) {
            XCTAssertEqual(decodedDevice.id, original.id)
            XCTAssertEqual(decodedDevice.ipAddress, original.ipAddress)
        }
    }
    
    func testCodable_EmptyValues() throws {
        // Given: Device mit leeren Werten
        let device = DeviceInfo(
            ipAddress: "",
            hostName: "",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: Encode und Decode
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: encoded)
        
        // Then: Leere Werte bleiben erhalten
        XCTAssertEqual(decoded.ipAddress, "")
        XCTAssertEqual(decoded.hostName, "")
        XCTAssertEqual(decoded.macAddress, "")
        XCTAssertEqual(decoded.manufacturer, "")
        XCTAssertEqual(decoded.openPorts, [])
    }
    
    // MARK: - Mutability Tests
    
    func testMutability_ChangeHostName() {
        // Given: Device
        var device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "OldName",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: hostName wird geändert
        device.hostName = "NewName"
        
        // Then: Änderung ist wirksam
        XCTAssertEqual(device.hostName, "NewName")
    }
    
    func testMutability_ChangeMACAddress() {
        // Given: Device ohne MAC
        var device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        
        let initialAliasKey = device.aliasKey
        XCTAssertEqual(initialAliasKey, "192.168.1.1")
        
        // When: MAC wird hinzugefügt
        device.macAddress = "AA:BB:CC:DD:EE:FF"
        
        // Then: aliasKey ändert sich
        XCTAssertEqual(device.aliasKey, "AA:BB:CC:DD:EE:FF")
    }
    
    func testMutability_AddOpenPorts() {
        // Given: Device ohne offene Ports
        var device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: Ports werden hinzugefügt
        device.openPorts = [80, 443]
        
        // Then: Ports sind gesetzt
        XCTAssertEqual(device.openPorts, [80, 443])
    }
    
    func testMutability_ChangeStatus() {
        // Given: Device mit Status .new
        var device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        
        // When: Status wird geändert
        device.status = .current
        
        // Then: Neuer Status ist gesetzt
        XCTAssertEqual(device.status, .current)
    }
    
    func testMutability_ToggleExpanded() {
        // Given: Device collapsed
        var device = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Device",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .active,
            isExpanded: false
        )
        
        // When: isExpanded wird getoggled
        device.isExpanded.toggle()
        
        // Then: Device ist expanded
        XCTAssertTrue(device.isExpanded)
    }
    
    // MARK: - Real World Scenarios
    
    func testRealWorld_TypicalRouter() {
        // Given: Typischer Router
        let router = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Router",
            macAddress: "B8:27:EB:AA:BB:CC",
            manufacturer: "Raspberry Pi Foundation",
            openPorts: [80, 443, 53, 22],
            status: .active,
            isExpanded: false
        )
        
        // Then: Properties sind realistisch
        XCTAssertEqual(router.aliasKey, "B8:27:EB:AA:BB:CC")
        XCTAssertTrue(router.openPorts.contains(80))
        XCTAssertTrue(router.openPorts.contains(443))
    }
    
    func testRealWorld_UnknownDevice() {
        // Given: Unbekanntes Device (nur IP bekannt)
        let unknown = DeviceInfo(
            ipAddress: "192.168.1.99",
            hostName: "",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        
        // Then: aliasKey ist IP
        XCTAssertEqual(unknown.aliasKey, "192.168.1.99")
        XCTAssertEqual(unknown.status, .new)
    }
    
    func testRealWorld_ServerWithManyPorts() {
        // Given: Server mit vielen offenen Ports
        let server = DeviceInfo(
            ipAddress: "192.168.1.10",
            hostName: "web-server",
            macAddress: "00:1A:11:22:33:44",
            manufacturer: "Google",
            openPorts: [21, 22, 25, 80, 110, 143, 443, 993, 995, 3306, 5432, 8080, 8443],
            status: .current,
            isExpanded: true
        )
        
        // Then: Viele Ports sind vorhanden
        XCTAssertGreaterThan(server.openPorts.count, 10)
        XCTAssertTrue(server.isExpanded)
    }
}
