import XCTest
@testable import TToolsIPScanner

@MainActor
final class NetworkScannerAsyncTests: XCTestCase {
    var scanner: NetworkScanner!
    
    override func setUp() async throws {
        scanner = NetworkScanner()
    }
    
    override func tearDown() async throws {
        scanner.stopScan()
        scanner = nil
    }
    
    // MARK: - Task Management Tests
    
    func testScanTaskCreation() async throws {
        // Given
        XCTAssertNil(scanner.currentScanTask)
        
        // When
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        
        // Then
        XCTAssertNotNil(scanner.currentScanTask)
        
        // Cleanup
        await Task.yield() // Let the task start
        scanner.stopScan()
    }
    
    func testScanTaskCancellation() async throws {
        // Given
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        await Task.yield()
        XCTAssertNotNil(scanner.currentScanTask)
        
        // When
        scanner.stopScan()
        
        // Then
        XCTAssertTrue(scanner.currentScanTask?.isCancelled ?? false)
        XCTAssertFalse(scanner.isScanning)
    }
    
    func testMultipleScansCancelPrevious() async throws {
        // Given
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        await Task.yield()
        let firstTask = scanner.currentScanTask
        
        // When - start second scan
        scanner.startScan(baseIP: "192.168.2.1", mode: .quickScan)
        await Task.yield()
        
        // Then - first task should be cancelled
        XCTAssertTrue(firstTask?.isCancelled ?? false)
        XCTAssertNotNil(scanner.currentScanTask)
        XCTAssertNotEqual(firstTask, scanner.currentScanTask)
        
        // Cleanup
        scanner.stopScan()
    }
    
    // MARK: - Scan State Tests
    
    func testScanStateUpdates() async throws {
        // Given
        XCTAssertEqual(scanner.scanPhase, .idle)
        XCTAssertFalse(scanner.isScanning)
        
        // When
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        
        // Give the task time to update state
        try await Task.sleep(for: .milliseconds(100))
        
        // Then
        XCTAssertTrue(scanner.isScanning)
        
        // Cleanup
        scanner.stopScan()
        XCTAssertFalse(scanner.isScanning)
        XCTAssertEqual(scanner.scanPhase, .idle)
    }
    
    func testInvalidIPAddressHandling() async throws {
        // Given
        let invalidIP = "999.999.999.999"
        
        // When
        scanner.startScan(baseIP: invalidIP, mode: .quickScan)
        
        // Then
        XCTAssertNotNil(scanner.scanError)
        XCTAssertTrue(scanner.scanError?.contains("Ungültige") ?? false)
        XCTAssertFalse(scanner.isScanning)
    }
    
    // MARK: - DNS Async Tests
    
    func testDNSLookupAsync() async throws {
        // Test with a known host
        let hostname = await scanner.getHostName(for: "127.0.0.1", timeout: 1.0)
        
        // localhost should resolve (might be "localhost" or similar)
        XCTAssertNotNil(hostname)
    }
    
    func testDNSLookupTimeout() async throws {
        // Test with likely unreachable IP
        let startTime = Date()
        let hostname = await scanner.getHostName(for: "192.168.255.254", timeout: 0.5)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should timeout within reasonable time
        XCTAssertLessThan(elapsed, 0.7) // Some buffer
        // Likely no hostname for unreachable IP
        XCTAssertNil(hostname)
    }
    
    // MARK: - Performance Tests
    
    func testAsyncScanPerformance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "Scan completes")
            
            scanner.startScan(baseIP: "127.0.0.1", mode: .quickScan)
            
            // Wait a bit for scan to progress
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.scanner.stopScan()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Device Alias Async Tests
    
    func testRememberedHostNameAsync() async throws {
        // Given
        let device = DeviceInfo(
            ipAddress: "192.168.1.100",
            hostName: "TestDevice",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "Test",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        let alias = DeviceAlias(customName: "My Custom Device", notes: "Test note")
        
        await MainActor.run {
            scanner.setDeviceAlias(for: device, alias: alias)
        }
        
        // When
        let remembered = await scanner.rememberedHostName(
            ip: device.ipAddress,
            mac: device.macAddress
        )
        
        // Then
        XCTAssertEqual(remembered, "My Custom Device")
    }
    
    func testMigrateAliasAsync() async throws {
        // Given
        let ip = "192.168.1.100"
        let mac = "AA:BB:CC:DD:EE:FF"
        let alias = DeviceAlias(customName: "Test Device", notes: "")
        
        await MainActor.run {
            scanner.deviceAliases[ip] = alias
        }
        
        // When
        await scanner.migrateAliasIfNeeded(ip: ip, mac: mac)
        
        // Then
        let macAlias = await MainActor.run {
            scanner.deviceAliases[mac]
        }
        XCTAssertNotNil(macAlias)
        XCTAssertEqual(macAlias?.customName, "Test Device")
    }
    
    // MARK: - Concurrency Safety Tests
    
    func testConcurrentScanRequests() async throws {
        // Start multiple scans rapidly
        for i in 1...5 {
            scanner.startScan(baseIP: "192.168.\(i).1", mode: .quickScan)
            try await Task.sleep(for: .milliseconds(50))
        }
        
        // Should have only one active task
        XCTAssertNotNil(scanner.currentScanTask)
        
        // Cleanup
        scanner.stopScan()
    }
}
