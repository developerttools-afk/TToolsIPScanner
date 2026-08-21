import XCTest
@testable import TToolsIPScanner

/// Tests für Property Wrappers: UserDefault, CodableUserDefault, EnumUserDefault.
final class PropertyWrappersTests: XCTestCase {
    
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "PropertyWrappersTests_\(UUID().uuidString)")!
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "PropertyWrappersTests")
        testDefaults = nil
        super.tearDown()
    }
    
    // MARK: - @UserDefault Tests
    
    func testUserDefault_Int() {
        // Given: Property Wrapper für Int
        @UserDefault(key: "testInt", defaultValue: 42, storage: testDefaults)
        var count: Int
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertEqual(count, 42)
        
        // When: Neuer Wert wird gesetzt
        count = 100
        
        // Then: Neuer Wert wird persistent
        XCTAssertEqual(testDefaults.integer(forKey: "testInt"), 100)
        XCTAssertEqual(count, 100)
    }
    
    func testUserDefault_String() {
        // Given: Property Wrapper für String
        @UserDefault(key: "testString", defaultValue: "default", storage: testDefaults)
        var text: String
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertEqual(text, "default")
        
        // When: Neuer Wert wird gesetzt
        text = "Hello World"
        
        // Then: Neuer Wert wird persistent
        XCTAssertEqual(testDefaults.string(forKey: "testString"), "Hello World")
        XCTAssertEqual(text, "Hello World")
    }
    
    func testUserDefault_Bool() {
        // Given: Property Wrapper für Bool
        @UserDefault(key: "testBool", defaultValue: false, storage: testDefaults)
        var flag: Bool
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertFalse(flag)
        
        // When: Neuer Wert wird gesetzt
        flag = true
        
        // Then: Neuer Wert wird persistent
        XCTAssertTrue(testDefaults.bool(forKey: "testBool"))
        XCTAssertTrue(flag)
    }
    
    func testUserDefault_Double() {
        // Given: Property Wrapper für Double
        @UserDefault(key: "testDouble", defaultValue: 3.14, storage: testDefaults)
        var value: Double
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertEqual(value, 3.14, accuracy: 0.001)
        
        // When: Neuer Wert wird gesetzt
        value = 2.71
        
        // Then: Neuer Wert wird persistent
        XCTAssertEqual(testDefaults.double(forKey: "testDouble"), 2.71, accuracy: 0.001)
        XCTAssertEqual(value, 2.71, accuracy: 0.001)
    }
    
    func testUserDefault_Array() {
        // Given: Property Wrapper für [String]
        @UserDefault(key: "testArray", defaultValue: [], storage: testDefaults)
        var items: [String]
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertEqual(items, [])
        
        // When: Neuer Wert wird gesetzt
        items = ["A", "B", "C"]
        
        // Then: Neuer Wert wird persistent
        XCTAssertEqual(testDefaults.stringArray(forKey: "testArray"), ["A", "B", "C"])
        XCTAssertEqual(items, ["A", "B", "C"])
    }
    
    // MARK: - @CodableUserDefault Tests
    
    func testCodableUserDefault_SimpleStruct() {
        // Given: Codable Struct
        struct TestStruct: Codable, Equatable {
            let name: String
            let age: Int
        }
        
        @CodableUserDefault(key: "testStruct", defaultValue: TestStruct(name: "Default", age: 0), storage: testDefaults)
        var data: TestStruct
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertEqual(data.name, "Default")
        XCTAssertEqual(data.age, 0)
        
        // When: Neuer Wert wird gesetzt
        data = TestStruct(name: "John", age: 30)
        
        // Then: Neuer Wert wird persistent
        XCTAssertEqual(data.name, "John")
        XCTAssertEqual(data.age, 30)
        
        // Verify persistence
        @CodableUserDefault(key: "testStruct", defaultValue: TestStruct(name: "Default", age: 0), storage: testDefaults)
        var loadedData: TestStruct
        XCTAssertEqual(loadedData, TestStruct(name: "John", age: 30))
    }
    
    func testCodableUserDefault_Array() {
        // Given: Codable Array
        @CodableUserDefault(key: "testDevices", defaultValue: [], storage: testDefaults)
        var devices: [DeviceInfo]
        
        // Then: Default-Wert (leer) wird zurückgegeben
        XCTAssertEqual(devices, [])
        
        // When: Devices werden gesetzt
        let testDevice = DeviceInfo(
            ipAddress: "192.168.1.1",
            hostName: "Test",
            macAddress: "AA:BB:CC:DD:EE:FF",
            vendor: "TestVendor",
            openPorts: [80],
            status: .active
        )
        devices = [testDevice]
        
        // Then: Devices werden persistent
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.ipAddress, "192.168.1.1")
    }
    
    func testCodableUserDefault_Dictionary() {
        // Given: Codable Dictionary
        @CodableUserDefault(key: "testAliases", defaultValue: [:], storage: testDefaults)
        var aliases: [String: DeviceAlias]
        
        // Then: Default-Wert (leer) wird zurückgegeben
        XCTAssertEqual(aliases, [:])
        
        // When: Aliases werden gesetzt
        let alias = DeviceAlias(customName: "Router", notes: "Main")
        aliases = ["192.168.1.1": alias]
        
        // Then: Aliases werden persistent
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases["192.168.1.1"]?.customName, "Router")
    }
    
    func testCodableUserDefault_InvalidData() {
        // Given: Ungültige Daten in UserDefaults
        testDefaults.set(Data([0xFF, 0xFF]), forKey: "corruptedData")
        
        @CodableUserDefault(key: "corruptedData", defaultValue: [], storage: testDefaults)
        var devices: [DeviceInfo]
        
        // Then: Default-Wert wird zurückgegeben (decode schlägt fehl)
        XCTAssertEqual(devices, [])
    }
    
    // MARK: - @EnumUserDefault Tests
    
    func testEnumUserDefault_SortOption() {
        // Given: Property Wrapper für Enum
        @EnumUserDefault(key: "testSort", defaultValue: .ip, storage: testDefaults)
        var sortOption: SortOption
        
        // Then: Default-Wert wird zurückgegeben
        XCTAssertEqual(sortOption, .ip)
        
        // When: Neuer Wert wird gesetzt
        sortOption = .hostname
        
        // Then: Neuer Wert wird persistent
        XCTAssertEqual(testDefaults.string(forKey: "testSort"), "hostname")
        XCTAssertEqual(sortOption, .hostname)
    }
    
    func testEnumUserDefault_AllValues() {
        // Test alle SortOption-Werte
        let allOptions: [SortOption] = [.ip, .hostname, .status, .vendor]
        
        for option in allOptions {
            // When: Option wird gesetzt
            @EnumUserDefault(key: "testAllOptions", defaultValue: .ip, storage: testDefaults)
            var sortOption: SortOption
            
            sortOption = option
            
            // Then: Option wird korrekt gespeichert und gelesen
            @EnumUserDefault(key: "testAllOptions", defaultValue: .ip, storage: testDefaults)
            var loadedOption: SortOption
            
            XCTAssertEqual(loadedOption, option, "Failed for option: \(option)")
        }
    }
    
    func testEnumUserDefault_InvalidRawValue() {
        // Given: Ungültiger RawValue in UserDefaults
        testDefaults.set("invalidValue", forKey: "invalidEnum")
        
        @EnumUserDefault(key: "invalidEnum", defaultValue: .ip, storage: testDefaults)
        var sortOption: SortOption
        
        // Then: Default-Wert wird zurückgegeben (init schlägt fehl)
        XCTAssertEqual(sortOption, .ip)
    }
    
    // MARK: - Persistence Tests
    
    func testPersistence_AcrossInstances() {
        // Given: Wert wird gesetzt
        do {
            @UserDefault(key: "persistentValue", defaultValue: 0, storage: testDefaults)
            var count: Int
            count = 42
        }
        
        // When: Neue Property Wrapper Instance wird erstellt
        @UserDefault(key: "persistentValue", defaultValue: 0, storage: testDefaults)
        var loadedCount: Int
        
        // Then: Wert bleibt erhalten
        XCTAssertEqual(loadedCount, 42)
    }
    
    func testPersistence_CodableAcrossInstances() {
        // Given: Codable Wert wird gesetzt
        do {
            @CodableUserDefault(key: "persistentDevices", defaultValue: [], storage: testDefaults)
            var devices: [DeviceInfo]
            
            devices = [DeviceInfo(
                ipAddress: "192.168.1.1",
                hostName: "Test",
                macAddress: "",
                vendor: "",
                openPorts: [],
                status: .active
            )]
        }
        
        // When: Neue Property Wrapper Instance wird erstellt
        @CodableUserDefault(key: "persistentDevices", defaultValue: [], storage: testDefaults)
        var loadedDevices: [DeviceInfo]
        
        // Then: Devices bleiben erhalten
        XCTAssertEqual(loadedDevices.count, 1)
        XCTAssertEqual(loadedDevices.first?.ipAddress, "192.168.1.1")
    }
    
    // MARK: - Edge Case Tests
    
    func testUserDefault_EmptyString() {
        @UserDefault(key: "emptyString", defaultValue: "default", storage: testDefaults)
        var text: String
        
        text = ""
        
        XCTAssertEqual(text, "")
        XCTAssertEqual(testDefaults.string(forKey: "emptyString"), "")
    }
    
    func testUserDefault_NegativeNumbers() {
        @UserDefault(key: "negativeInt", defaultValue: 0, storage: testDefaults)
        var number: Int
        
        number = -42
        
        XCTAssertEqual(number, -42)
        XCTAssertEqual(testDefaults.integer(forKey: "negativeInt"), -42)
    }
    
    func testCodableUserDefault_EmptyArray() {
        @CodableUserDefault(key: "emptyArray", defaultValue: ["default"], storage: testDefaults)
        var items: [String]
        
        items = []
        
        // Empty array wird persistent
        @CodableUserDefault(key: "emptyArray", defaultValue: ["default"], storage: testDefaults)
        var loadedItems: [String]
        
        XCTAssertEqual(loadedItems, [])
    }
}
