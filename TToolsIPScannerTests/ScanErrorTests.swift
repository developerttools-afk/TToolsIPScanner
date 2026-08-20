import XCTest
@testable import TToolsIPScanner

final class ScanErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testInvalidIPAddressErrorDescription() {
        let error = ScanError.invalidIPAddress("999.999.999.999")
        XCTAssertEqual(error.errorDescription, "Ungültige IP-Adresse: 999.999.999.999")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testNetworkUnreachableErrorDescription() {
        let error = ScanError.networkUnreachable
        XCTAssertEqual(error.errorDescription, "Netzwerk nicht erreichbar")
        XCTAssertNotNil(error.failureReason)
    }
    
    func testScanCancelledErrorDescription() {
        let error = ScanError.scanCancelled
        XCTAssertEqual(error.errorDescription, "Scan wurde abgebrochen")
    }
    
    func testScanAlreadyRunningErrorDescription() {
        let error = ScanError.scanAlreadyRunning
        XCTAssertEqual(error.errorDescription, "Ein Scan läuft bereits")
    }
    
    func testSocketCreationFailedErrorDescription() {
        let error = ScanError.socketCreationFailed(errno: 13)
        XCTAssertTrue(error.errorDescription?.contains("Socket-Erstellung fehlgeschlagen") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("13") ?? false)
    }
    
    func testConnectionTimeoutErrorDescription() {
        let error = ScanError.connectionTimeout(ip: "192.168.1.1", port: 80)
        XCTAssertTrue(error.errorDescription?.contains("192.168.1.1:80") ?? false)
    }
    
    func testInvalidPortNumberErrorDescription() {
        let error = ScanError.invalidPortNumber(99999)
        XCTAssertTrue(error.errorDescription?.contains("99999") ?? false)
    }
    
    func testNoPortsSpecifiedErrorDescription() {
        let error = ScanError.noPortsSpecified
        XCTAssertEqual(error.errorDescription, "Keine Ports zum Scannen angegeben")
    }
    
    func testLocalNetworkPermissionDeniedErrorDescription() {
        let error = ScanError.localNetworkPermissionDenied
        XCTAssertEqual(error.errorDescription, "Zugriff auf lokales Netzwerk verweigert")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testDNSLookupFailedErrorDescription() {
        let error = ScanError.dnsLookupFailed(ip: "192.168.1.100")
        XCTAssertTrue(error.errorDescription?.contains("192.168.1.100") ?? false)
    }
    
    func testOUIErrorDescriptions() {
        let loadError = ScanError.ouiDatabaseLoadFailed(underlying: NSError(domain: "test", code: 1))
        XCTAssertNotNil(loadError.errorDescription)
        
        let downloadError = ScanError.ouiDatabaseDownloadFailed(statusCode: 404)
        XCTAssertTrue(downloadError.errorDescription?.contains("404") ?? false)
        
        let corruptedError = ScanError.ouiDatabaseCorrupted
        XCTAssertNotNil(corruptedError.errorDescription)
    }
    
    // MARK: - Failure Reason Tests
    
    func testFailureReasonProvided() {
        let errors: [ScanError] = [
            .invalidIPAddress("test"),
            .networkUnreachable,
            .scanCancelled,
            .localNetworkPermissionDenied,
            .invalidPortNumber(70000),
            .noPortsSpecified
        ]
        
        for error in errors {
            XCTAssertNotNil(error.failureReason, "Error \(error) should have failure reason")
        }
    }
    
    func testInvalidIPAddressFailureReason() {
        let error = ScanError.invalidIPAddress("test")
        XCTAssertTrue(error.failureReason?.contains("ungültig") ?? false)
    }
    
    func testInvalidPortNumberFailureReason() {
        let error = ScanError.invalidPortNumber(70000)
        XCTAssertTrue(error.failureReason?.contains("70000") ?? false)
        XCTAssertTrue(error.failureReason?.contains("1-65535") ?? false)
    }
    
    // MARK: - Recovery Suggestion Tests
    
    func testRecoverySuggestionProvided() {
        let errors: [ScanError] = [
            .invalidIPAddress("test"),
            .networkUnreachable,
            .scanAlreadyRunning,
            .localNetworkPermissionDenied,
            .invalidPortNumber(70000),
            .noPortsSpecified
        ]
        
        for error in errors {
            XCTAssertNotNil(error.recoverySuggestion, "Error \(error) should have recovery suggestion")
        }
    }
    
    func testInvalidIPAddressRecoverySuggestion() {
        let error = ScanError.invalidIPAddress("test")
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("xxx.xxx.xxx.xxx") ?? false)
    }
    
    func testLocalNetworkPermissionDeniedRecoverySuggestion() {
        let error = ScanError.localNetworkPermissionDenied
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("Einstellungen") ?? false)
        XCTAssertTrue(suggestion?.contains("Datenschutz") ?? false)
    }
    
    func testNoPortsSpecifiedRecoverySuggestion() {
        let error = ScanError.noPortsSpecified
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("Port") ?? false)
    }
    
    // MARK: - Severity Tests
    
    func testInfoSeverity() {
        let error = ScanError.scanCancelled
        XCTAssertEqual(error.severity, .info)
    }
    
    func testWarningSeverity() {
        let errors: [ScanError] = [
            .dnsLookupFailed(ip: "test"),
            .dnsTimeout(ip: "test"),
            .scanTimeout(ip: "test"),
            .connectionTimeout(ip: "test", port: 80)
        ]
        
        for error in errors {
            XCTAssertEqual(error.severity, .warning, "Error \(error) should be warning")
        }
    }
    
    func testErrorSeverity() {
        let errors: [ScanError] = [
            .invalidIPAddress("test"),
            .invalidPortNumber(70000),
            .noPortsSpecified,
            .scanAlreadyRunning,
            .connectionFailed(ip: "test", port: 80, errno: 1)
        ]
        
        for error in errors {
            XCTAssertEqual(error.severity, .error, "Error \(error) should be error")
        }
    }
    
    func testCriticalSeverity() {
        let errors: [ScanError] = [
            .networkUnreachable,
            .noNetworkConnection,
            .localNetworkPermissionDenied,
            .socketCreationFailed(errno: 1),
            .tooManyConnections
        ]
        
        for error in errors {
            XCTAssertEqual(error.severity, .critical, "Error \(error) should be critical")
        }
    }
    
    // MARK: - Icon Tests
    
    func testIconForSeverity() {
        XCTAssertEqual(ScanError.scanCancelled.icon, "info.circle")
        XCTAssertEqual(ScanError.dnsLookupFailed(ip: "test").icon, "exclamationmark.triangle")
        XCTAssertEqual(ScanError.invalidIPAddress("test").icon, "xmark.circle")
        XCTAssertEqual(ScanError.networkUnreachable.icon, "xmark.octagon")
    }
    
    // MARK: - User-Friendly Message Tests
    
    func testUserFriendlyMessage() {
        let error = ScanError.invalidIPAddress("999.999.999.999")
        let message = error.userFriendlyMessage
        
        XCTAssertTrue(message.contains("Ungültige IP-Adresse"))
        XCTAssertTrue(message.contains("999.999.999.999"))
    }
    
    func testUserFriendlyMessageIncludesFailureReason() {
        let error = ScanError.localNetworkPermissionDenied
        let message = error.userFriendlyMessage
        
        XCTAssertTrue(message.contains(error.errorDescription ?? ""))
        XCTAssertTrue(message.contains(error.failureReason ?? ""))
    }
    
    func testUserFriendlyMessageIncludesRecoverySuggestion() {
        let error = ScanError.noPortsSpecified
        let message = error.userFriendlyMessage
        
        XCTAssertTrue(message.contains("💡"))
        XCTAssertTrue(message.contains(error.recoverySuggestion ?? ""))
    }
    
    // MARK: - Help Anchor Tests
    
    func testHelpAnchorProvided() {
        XCTAssertEqual(ScanError.invalidIPAddress("test").helpAnchor, "ip-address-format")
        XCTAssertEqual(ScanError.localNetworkPermissionDenied.helpAnchor, "local-network-permission")
        XCTAssertEqual(ScanError.noPortsSpecified.helpAnchor, "port-configuration")
        XCTAssertEqual(ScanError.ouiDatabaseCorrupted.helpAnchor, "oui-database")
    }
    
    func testHelpAnchorNilForMostErrors() {
        XCTAssertNil(ScanError.networkUnreachable.helpAnchor)
        XCTAssertNil(ScanError.scanCancelled.helpAnchor)
    }
    
    // MARK: - Equatable Tests (implied by enum)
    
    func testErrorEquality() {
        let error1 = ScanError.invalidIPAddress("192.168.1.1")
        let error2 = ScanError.invalidIPAddress("192.168.1.1")
        
        // Enums with associated values can be compared
        switch (error1, error2) {
        case (.invalidIPAddress(let ip1), .invalidIPAddress(let ip2)):
            XCTAssertEqual(ip1, ip2)
        default:
            XCTFail("Errors should be of same type")
        }
    }
    
    // MARK: - LocalizedError Conformance Tests
    
    func testLocalizedErrorConformance() {
        let error: LocalizedError = ScanError.invalidIPAddress("test")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyIPAddress() {
        let error = ScanError.invalidIPAddress("")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testVeryLongIPAddress() {
        let longIP = String(repeating: "123.456.789.012.", count: 10)
        let error = ScanError.invalidIPAddress(longIP)
        XCTAssertNotNil(error.errorDescription)
    }
    
    func testNegativePortNumber() {
        let error = ScanError.invalidPortNumber(-1)
        XCTAssertTrue(error.errorDescription?.contains("-1") ?? false)
    }
    
    func testMaxPortNumber() {
        let error = ScanError.invalidPortNumber(99999)
        XCTAssertTrue(error.failureReason?.contains("65535") ?? false)
    }
    
    func testZeroErrno() {
        let error = ScanError.socketCreationFailed(errno: 0)
        XCTAssertTrue(error.errorDescription?.contains("0") ?? false)
    }
    
    func testConnectionFailedWithAllParameters() {
        let error = ScanError.connectionFailed(ip: "10.0.0.1", port: 8080, errno: 61)
        let description = error.errorDescription
        
        XCTAssertTrue(description?.contains("10.0.0.1") ?? false)
        XCTAssertTrue(description?.contains("8080") ?? false)
        XCTAssertTrue(description?.contains("61") ?? false)
    }
}
