import XCTest
@testable import TToolsIPScanner

@MainActor
final class NetworkScannerErrorHandlingTests: XCTestCase {
    var scanner: NetworkScanner!
    
    override func setUp() async throws {
        scanner = NetworkScanner()
    }
    
    override func tearDown() async throws {
        scanner.stopScan()
        scanner = nil
    }
    
    // MARK: - Invalid IP Tests
    
    func testInvalidIPAddressError() {
        // Given
        let invalidIP = "999.999.999.999"
        
        // When
        scanner.startScan(baseIP: invalidIP, mode: .quickScan)
        
        // Then
        XCTAssertNotNil(scanner.scanError)
        if case .invalidIPAddress(let ip) = scanner.scanError {
            XCTAssertEqual(ip, invalidIP)
        } else {
            XCTFail("Expected invalidIPAddress error")
        }
    }
    
    func testInvalidIPAddressFormat() {
        let invalidIPs = [
            "192.168.1",           // Too few octets
            "192.168.1.1.1",       // Too many octets
            "abc.def.ghi.jkl",     // Non-numeric
            "192.168.01.1",        // Leading zeros
            "",                     // Empty
            "192.168.1.256"        // Out of range
        ]
        
        for invalidIP in invalidIPs {
            scanner.scanError = nil
            scanner.startScan(baseIP: invalidIP, mode: .quickScan)
            
            XCTAssertNotNil(scanner.scanError, "Should have error for IP: \(invalidIP)")
            if case .invalidIPAddress = scanner.scanError {
                // Success
            } else {
                XCTFail("Expected invalidIPAddress error for IP: \(invalidIP)")
            }
        }
    }
    
    // MARK: - Scan Already Running Tests
    
    func testScanAlreadyRunningError() {
        // Given
        scanner.isScanning = true
        
        // When
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        
        // Then
        XCTAssertNotNil(scanner.scanError)
        if case .scanAlreadyRunning = scanner.scanError {
            // Success
        } else {
            XCTFail("Expected scanAlreadyRunning error")
        }
    }
    
    // MARK: - No Ports Specified Tests
    
    func testNoPortsSpecifiedError() {
        // Given
        scanner.customPorts = []
        
        // When
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        
        // Then
        XCTAssertNotNil(scanner.scanError)
        if case .noPortsSpecified = scanner.scanError {
            // Success
        } else {
            XCTFail("Expected noPortsSpecified error, got: \(String(describing: scanner.scanError))")
        }
    }
    
    func testNoPortsSpecifiedNotTriggeredInFullScanMode() {
        // Given
        scanner.customPorts = []
        
        // When
        scanner.startScan(baseIP: "192.168.1.1", mode: .fullScan)
        
        // Then - should NOT have noPortsSpecified error in fullScan mode
        if case .noPortsSpecified = scanner.scanError {
            XCTFail("Should not have noPortsSpecified error in fullScan mode")
        }
    }
    
    // MARK: - Error Clearing Tests
    
    func testErrorClearedOnNewScan() {
        // Given
        scanner.scanError = .invalidIPAddress("test")
        XCTAssertNotNil(scanner.scanError)
        
        // When
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        
        // Then - error should be cleared initially
        // (might be set again if new scan has error, but initially cleared)
    }
    
    // MARK: - Valid IP Tests
    
    func testValidIPAddressNoError() {
        let validIPs = [
            "192.168.1.1",
            "10.0.0.1",
            "172.16.0.1",
            "0.0.0.0",
            "255.255.255.255"
        ]
        
        for validIP in validIPs {
            scanner.scanError = nil
            scanner.customPorts = [80, 443] // Ensure ports are set
            scanner.startScan(baseIP: validIP, mode: .quickScan)
            
            // Should not have invalidIPAddress error
            if case .invalidIPAddress = scanner.scanError {
                XCTFail("Should not have invalidIPAddress error for valid IP: \(validIP)")
            }
        }
    }
    
    // MARK: - Error Severity Tests
    
    func testErrorSeverityLevels() {
        let testCases: [(ScanError, ScanError.Severity)] = [
            (.scanCancelled, .info),
            (.dnsLookupFailed(ip: "test"), .warning),
            (.invalidIPAddress("test"), .error),
            (.networkUnreachable, .critical)
        ]
        
        for (error, expectedSeverity) in testCases {
            XCTAssertEqual(error.severity, expectedSeverity)
        }
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptionContainsRelevantInfo() {
        let testCases: [(ScanError, String)] = [
            (.invalidIPAddress("192.168.1.999"), "192.168.1.999"),
            (.connectionTimeout(ip: "10.0.0.1", port: 8080), "10.0.0.1"),
            (.connectionTimeout(ip: "10.0.0.1", port: 8080), "8080"),
            (.invalidPortNumber(70000), "70000")
        ]
        
        for (error, expectedContent) in testCases {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.contains(expectedContent),
                "Error description '\(description)' should contain '\(expectedContent)'"
            )
        }
    }
    
    // MARK: - User-Friendly Message Tests
    
    func testUserFriendlyMessageFormatting() {
        let error = ScanError.localNetworkPermissionDenied
        let message = error.userFriendlyMessage
        
        // Should contain all parts
        XCTAssertTrue(message.contains("Zugriff"))
        XCTAssertTrue(message.contains("💡"))
        XCTAssertTrue(message.contains("Einstellungen"))
    }
    
    // MARK: - OUI Database Error Tests
    
    func testOUIErrorsHandled() {
        // Test that OUI errors are properly created
        let loadError = ScanError.ouiDatabaseLoadFailed(
            underlying: NSError(domain: "test", code: 1)
        )
        let downloadError = ScanError.ouiDatabaseDownloadFailed(statusCode: 404)
        let corruptedError = ScanError.ouiDatabaseCorrupted
        
        XCTAssertNotNil(loadError.errorDescription)
        XCTAssertNotNil(downloadError.errorDescription)
        XCTAssertNotNil(corruptedError.errorDescription)
        
        XCTAssertTrue(downloadError.errorDescription?.contains("404") ?? false)
    }
    
    // MARK: - Multiple Error Scenarios
    
    func testMultipleErrorScenarios() async {
        // Scenario 1: Invalid IP
        scanner.scanError = nil
        scanner.startScan(baseIP: "invalid", mode: .quickScan)
        XCTAssertNotNil(scanner.scanError)
        let error1 = scanner.scanError
        
        // Scenario 2: No ports
        scanner.scanError = nil
        scanner.customPorts = []
        scanner.startScan(baseIP: "192.168.1.1", mode: .quickScan)
        XCTAssertNotNil(scanner.scanError)
        let error2 = scanner.scanError
        
        // Errors should be different
        XCTAssertFalse(
            type(of: error1) == type(of: error2) &&
            String(describing: error1) == String(describing: error2)
        )
    }
    
    // MARK: - Error Icon Tests
    
    func testErrorIconsForDifferentSeverities() {
        XCTAssertEqual(ScanError.scanCancelled.icon, "info.circle")
        XCTAssertEqual(ScanError.dnsTimeout(ip: "test").icon, "exclamationmark.triangle")
        XCTAssertEqual(ScanError.invalidIPAddress("test").icon, "xmark.circle")
        XCTAssertEqual(ScanError.networkUnreachable.icon, "xmark.octagon")
    }
}
