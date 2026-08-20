import XCTest
@testable import TToolsIPScanner

/// Tests für SettingsManager: Type-safe UserDefaults-Wrapper.
final class SettingsManagerTests: XCTestCase {
    
    var settings: SettingsManager!
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Verwende separate UserDefaults für Tests
        testDefaults = UserDefaults(suiteName: "SettingsManagerTests_\(UUID().uuidString)")!
        settings = SettingsManager(storage: testDefaults)
    }
    
    override func tearDown() {
        // Cleanup
        testDefaults.removePersistentDomain(forName: "SettingsManagerTests")
        testDefaults = nil
        settings = nil
        super.tearDown()
    }
    
    // MARK: - Custom Ports Tests
    
    func testCustomPorts_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: customPorts wird abgerufen
        let ports = settings.customPorts
        
        // Then: Default-Ports werden zurückgegeben
        XCTAssertEqual(ports, NetworkConstants.defaultPorts)
    }
    
    func testCustomPorts_SetAndGet() {
        // Given: Neue Custom Ports
        let newPorts: Set<Int> = [22, 80, 443, 8080]
        
        // When: Ports werden gesetzt
        settings.customPorts = newPorts
        
        // Then: Ports können wieder abgerufen werden
        XCTAssertEqual(settings.customPorts, newPorts)
    }
    
    func testCustomPorts_Persistence() {
        // Given: Ports werden gesetzt
        let newPorts: Set<Int> = [22, 80, 443]
        settings.customPorts = newPorts
        
        // When: Neuer SettingsManager wird erstellt
        let newSettings = SettingsManager(storage: testDefaults)
        
        // Then: Ports bleiben erhalten
        XCTAssertEqual(newSettings.customPorts, newPorts)
    }
    
    func testCustomPorts_EmptySet() {
        // Given: Leeres Set wird gesetzt
        settings.customPorts = []
        
        // When: Ports werden abgerufen
        let ports = settings.customPorts
        
        // Then: Leeres Set wird zurückgegeben
        XCTAssertEqual(ports, [])
    }
    
    // MARK: - Scan Mode Tests
    
    func testPreferredScanMode_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: preferredScanMode wird abgerufen
        let mode = settings.preferredScanMode
        
        // Then: QuickScan ist default
        XCTAssertEqual(mode, .quickScan)
    }
    
    func testPreferredScanMode_SetAndGet() {
        // Given: FullScan Modus
        settings.preferredScanMode = .fullScan
        
        // When: Mode wird abgerufen
        let mode = settings.preferredScanMode
        
        // Then: FullScan wird zurückgegeben
        XCTAssertEqual(mode, .fullScan)
    }
    
    func testPreferredScanMode_Persistence() {
        // Given: FullScan wird gesetzt
        settings.preferredScanMode = .fullScan
        
        // When: Neuer SettingsManager wird erstellt
        let newSettings = SettingsManager(storage: testDefaults)
        
        // Then: Mode bleibt erhalten
        XCTAssertEqual(newSettings.preferredScanMode, .fullScan)
    }
    
    // MARK: - Sort Settings Tests
    
    func testSortOption_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: sortOption wird abgerufen
        let option = settings.sortOption
        
        // Then: IP ist default
        XCTAssertEqual(option, .ip)
    }
    
    func testSortOption_SetAndGet() {
        // Given: Hostname Sort-Option
        settings.sortOption = .hostname
        
        // When: Option wird abgerufen
        let option = settings.sortOption
        
        // Then: Hostname wird zurückgegeben
        XCTAssertEqual(option, .hostname)
    }
    
    func testSortOption_AllValues() {
        // Test alle Sort-Optionen
        let allOptions: [SortOption] = [.ip, .hostname, .status, .vendor]
        
        for option in allOptions {
            // When: Option wird gesetzt
            settings.sortOption = option
            
            // Then: Korrekte Option wird zurückgegeben
            XCTAssertEqual(settings.sortOption, option, "Failed for option: \(option)")
        }
    }
    
    func testSortAscending_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: sortAscending wird abgerufen
        let ascending = settings.sortAscending
        
        // Then: True ist default
        XCTAssertTrue(ascending)
    }
    
    func testSortAscending_SetAndGet() {
        // Given: Descending Sort
        settings.sortAscending = false
        
        // When: Wert wird abgerufen
        let ascending = settings.sortAscending
        
        // Then: False wird zurückgegeben
        XCTAssertFalse(ascending)
    }
    
    // MARK: - Network Settings Tests
    
    func testRecentNetworks_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: recentNetworks wird abgerufen
        let networks = settings.recentNetworks
        
        // Then: Leeres Array ist default
        XCTAssertEqual(networks, [])
    }
    
    func testRecentNetworks_SetAndGet() {
        // Given: Netzwerke
        let networks = ["192.168.1.0", "10.0.0.0", "172.16.0.0"]
        
        // When: Netzwerke werden gesetzt
        settings.recentNetworks = networks
        
        // Then: Netzwerke können abgerufen werden
        XCTAssertEqual(settings.recentNetworks, networks)
    }
    
    func testRecentNetworks_Persistence() {
        // Given: Netzwerke werden gesetzt
        let networks = ["192.168.1.0", "10.0.0.0"]
        settings.recentNetworks = networks
        
        // When: Neuer SettingsManager wird erstellt
        let newSettings = SettingsManager(storage: testDefaults)
        
        // Then: Netzwerke bleiben erhalten
        XCTAssertEqual(newSettings.recentNetworks, networks)
    }
    
    // MARK: - Codable Settings Tests
    
    func testLastScanResults_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: lastScanResults wird abgerufen
        let results = settings.lastScanResults
        
        // Then: Leeres Array ist default
        XCTAssertEqual(results, [])
    }
    
    func testLastScanResults_SetAndGet() {
        // Given: Test-Devices
        let devices = createTestDevices()
        
        // When: Devices werden gesetzt
        settings.lastScanResults = devices
        
        // Then: Devices können abgerufen werden
        XCTAssertEqual(settings.lastScanResults.count, devices.count)
        XCTAssertEqual(settings.lastScanResults.first?.ipAddress, devices.first?.ipAddress)
    }
    
    func testLastScanResults_Persistence() {
        // Given: Devices werden gesetzt
        let devices = createTestDevices()
        settings.lastScanResults = devices
        
        // When: Neuer SettingsManager wird erstellt
        let newSettings = SettingsManager(storage: testDefaults)
        
        // Then: Devices bleiben erhalten
        XCTAssertEqual(newSettings.lastScanResults.count, devices.count)
    }
    
    func testDeviceAliases_DefaultValue() {
        // Given: Frischer SettingsManager
        // When: deviceAliases wird abgerufen
        let aliases = settings.deviceAliases
        
        // Then: Leeres Dictionary ist default
        XCTAssertEqual(aliases, [:])
    }
    
    func testDeviceAliases_SetAndGet() {
        // Given: Test-Aliases
        let aliases = createTestAliases()
        
        // When: Aliases werden gesetzt
        settings.deviceAliases = aliases
        
        // Then: Aliases können abgerufen werden
        XCTAssertEqual(settings.deviceAliases.count, aliases.count)
        XCTAssertEqual(settings.deviceAliases["192.168.1.1"]?.customName, "Router")
    }
    
    func testDeviceAliases_Persistence() {
        // Given: Aliases werden gesetzt
        let aliases = createTestAliases()
        settings.deviceAliases = aliases
        
        // When: Neuer SettingsManager wird erstellt
        let newSettings = SettingsManager(storage: testDefaults)
        
        // Then: Aliases bleiben erhalten
        XCTAssertEqual(newSettings.deviceAliases.count, aliases.count)
    }
    
    // MARK: - Utility Tests
    
    func testResetAllSettings() {
        // Given: Verschiedene Settings sind gesetzt
        settings.customPorts = [22, 80, 443]
        settings.preferredScanMode = .fullScan
        settings.sortOption = .hostname
        settings.sortAscending = false
        settings.recentNetworks = ["192.168.1.0"]
        settings.lastScanResults = createTestDevices()
        settings.deviceAliases = createTestAliases()
        
        // When: Reset wird durchgeführt
        settings.resetAllSettings()
        
        // Then: Alle Settings sind zurückgesetzt
        XCTAssertEqual(settings.customPorts, NetworkConstants.defaultPorts)
        XCTAssertEqual(settings.preferredScanMode, .quickScan)
        XCTAssertEqual(settings.sortOption, .ip)
        XCTAssertTrue(settings.sortAscending)
        XCTAssertEqual(settings.recentNetworks, [])
        XCTAssertEqual(settings.lastScanResults, [])
        XCTAssertEqual(settings.deviceAliases, [:])
    }
    
    func testExportSettings() {
        // Given: Settings sind gesetzt
        settings.customPorts = [80, 443]
        settings.preferredScanMode = .fullScan
        settings.sortOption = .hostname
        settings.sortAscending = false
        settings.recentNetworks = ["192.168.1.0"]
        
        // When: Export wird durchgeführt
        let exported = settings.exportSettings()
        
        // Then: Alle Settings sind im Export enthalten
        XCTAssertNotNil(exported["customPorts"])
        XCTAssertEqual(exported["preferredScanMode"] as? String, "fullScan")
        XCTAssertEqual(exported["sortOption"] as? String, "hostname")
        XCTAssertEqual(exported["sortAscending"] as? Bool, false)
        XCTAssertNotNil(exported["recentNetworks"])
    }
    
    func testForTesting_CreatesSeparateInstance() {
        // Given: Test-Instance
        let testSettings = SettingsManager.forTesting()
        
        // When: Settings werden gesetzt
        testSettings.sortOption = .hostname
        
        // Then: Shared Instance ist unbeeinflusst
        XCTAssertNotEqual(SettingsManager.shared.sortOption, testSettings.sortOption)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAccess() {
        // Test: Gleichzeitige Zugriffe auf Settings
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            settings.customPorts = Set([index * 10, index * 20])
            _ = settings.customPorts
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestDevices() -> [DeviceInfo] {
        return [
            DeviceInfo(
                ipAddress: "192.168.1.1",
                hostName: "Router",
                macAddress: "AA:BB:CC:DD:EE:01",
                vendor: "Test Vendor",
                openPorts: [80, 443],
                status: .active
            ),
            DeviceInfo(
                ipAddress: "192.168.1.2",
                hostName: "PC",
                macAddress: "AA:BB:CC:DD:EE:02",
                vendor: "Another Vendor",
                openPorts: [22],
                status: .active
            )
        ]
    }
    
    private func createTestAliases() -> [String: DeviceAlias] {
        return [
            "192.168.1.1": DeviceAlias(customName: "Router", notes: "Main router"),
            "192.168.1.2": DeviceAlias(customName: "PC", notes: "Work PC")
        ]
    }
}
