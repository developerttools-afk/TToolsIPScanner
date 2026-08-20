import XCTest
@testable import TToolsIPScanner

/// Umfassende Tests für IPAddressValidator.
final class IPAddressValidatorTests: XCTestCase {
    
    // MARK: - Valid IPv4 Tests
    
    func testValidIPv4_StandardAddresses() {
        // Given: Standard gültige IP-Adressen
        let validIPs = [
            "192.168.1.1",
            "10.0.0.1",
            "172.16.0.1",
            "8.8.8.8",
            "1.2.3.4"
        ]
        
        // When/Then: Alle sollten als gültig erkannt werden
        for ip in validIPs {
            XCTAssertTrue(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be valid"
            )
        }
    }
    
    func testValidIPv4_EdgeCases() {
        // Given: Edge-Case IP-Adressen
        let edgeCases = [
            "0.0.0.0",           // Minimum
            "255.255.255.255",   // Maximum
            "127.0.0.1",         // Localhost
            "169.254.0.1",       // Link-local
            "224.0.0.1",         // Multicast
            "192.168.0.0",       // Network address
            "192.168.255.255"    // Broadcast
        ]
        
        // When/Then: Alle sollten als gültig erkannt werden
        for ip in edgeCases {
            XCTAssertTrue(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be valid"
            )
        }
    }
    
    func testValidIPv4_SingleDigitOctets() {
        // Given: IPs mit einzelnen Ziffern
        let singleDigit = ["1.2.3.4", "9.8.7.6", "0.0.0.1"]
        
        // When/Then: Alle sollten gültig sein
        for ip in singleDigit {
            XCTAssertTrue(IPAddressValidator.isValidIPv4(ip))
        }
    }
    
    func testValidIPv4_MixedDigitLengths() {
        // Given: IPs mit gemischten Oktett-Längen
        let mixed = [
            "1.22.333.4",     // Ungültig (333 > 255)
            "192.168.1.1",    // Gültig
            "10.0.0.100"      // Gültig
        ]
        
        XCTAssertFalse(IPAddressValidator.isValidIPv4(mixed[0]))
        XCTAssertTrue(IPAddressValidator.isValidIPv4(mixed[1]))
        XCTAssertTrue(IPAddressValidator.isValidIPv4(mixed[2]))
    }
    
    // MARK: - Invalid IPv4 Tests
    
    func testInvalidIPv4_EmptyString() {
        // Given: Leerer String
        let empty = ""
        
        // When/Then: Sollte ungültig sein
        XCTAssertFalse(IPAddressValidator.isValidIPv4(empty))
    }
    
    func testInvalidIPv4_TooFewOctets() {
        // Given: Zu wenige Oktetts
        let tooFew = [
            "192",
            "192.168",
            "192.168.1",
            "192.168.1."
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in tooFew {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (too few octets)"
            )
        }
    }
    
    func testInvalidIPv4_TooManyOctets() {
        // Given: Zu viele Oktetts
        let tooMany = [
            "192.168.1.1.1",
            "1.2.3.4.5",
            "192.168.1.1.1.1"
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in tooMany {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (too many octets)"
            )
        }
    }
    
    func testInvalidIPv4_OutOfRange() {
        // Given: Werte außerhalb des gültigen Bereichs
        let outOfRange = [
            "256.1.1.1",         // Erstes Oktett > 255
            "1.256.1.1",         // Zweites Oktett > 255
            "1.1.256.1",         // Drittes Oktett > 255
            "1.1.1.256",         // Viertes Oktett > 255
            "999.999.999.999",   // Alle zu groß
            "192.168.1.-1",      // Negativ
            "-1.-1.-1.-1"        // Alle negativ
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in outOfRange {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (out of range)"
            )
        }
    }
    
    func testInvalidIPv4_LeadingZeros() {
        // Given: Führende Nullen (außer "0" selbst)
        let leadingZeros = [
            "192.168.01.1",      // 01 ist ungültig
            "192.168.001.1",     // 001 ist ungültig
            "01.02.03.04",       // Alle ungültig
            "192.168.1.00"       // 00 ist ungültig
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in leadingZeros {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (leading zeros)"
            )
        }
    }
    
    func testInvalidIPv4_LeadingZeroException() {
        // Given: "0" selbst ist gültig
        let validZero = "192.168.0.1"
        
        // When/Then: Sollte gültig sein
        XCTAssertTrue(IPAddressValidator.isValidIPv4(validZero))
    }
    
    func testInvalidIPv4_NonNumericCharacters() {
        // Given: Nicht-numerische Zeichen
        let nonNumeric = [
            "abc.def.ghi.jkl",
            "192.168.1.abc",
            "192.168.a.1",
            "192.168.1.1a",
            "192.168.1.1!",
            "192.168.1.1 ",      // Leerzeichen
            "192 .168.1.1",      // Leerzeichen im Oktett
            "192.168.1.x"
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in nonNumeric {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (non-numeric)"
            )
        }
    }
    
    func testInvalidIPv4_EmptyOctets() {
        // Given: Leere Oktetts
        let emptyOctets = [
            "...",
            "192..1.1",
            ".168.1.1",
            "192.168.1.",
            "192.168..1"
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in emptyOctets {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (empty octets)"
            )
        }
    }
    
    func testInvalidIPv4_SpecialCharacters() {
        // Given: Sonderzeichen
        let special = [
            "192.168.1.1/24",    // CIDR notation
            "192.168.1.1:8080",  // Mit Port
            "192_168_1_1",       // Unterstriche
            "192-168-1-1",       // Bindestriche
            "192.168.1.1%eth0"   // Mit Interface
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in special {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (special characters)"
            )
        }
    }
    
    func testInvalidIPv4_WhitespaceVariations() {
        // Given: Verschiedene Whitespace-Varianten
        let whitespace = [
            " 192.168.1.1",      // Leading space
            "192.168.1.1 ",      // Trailing space
            " 192.168.1.1 ",     // Both
            "192. 168.1.1",      // Space after dot
            "192 . 168 . 1 . 1"  // Spaces everywhere
        ]
        
        // When/Then: Alle sollten ungültig sein (kein Trimming)
        for ip in whitespace {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (whitespace)"
            )
        }
    }
    
    func testInvalidIPv4_CommonMistakes() {
        // Given: Häufige Fehler
        let mistakes = [
            "192.168.l.1",       // l statt 1
            "192.168.O.1",       // O statt 0
            "192,168,1,1",       // Kommas statt Punkte
            "192;168;1;1",       // Semikolons
            "192:168:1:1"        // Colons (IPv6-Style)
        ]
        
        // When/Then: Alle sollten ungültig sein
        for ip in mistakes {
            XCTAssertFalse(
                IPAddressValidator.isValidIPv4(ip),
                "Expected '\(ip)' to be invalid (common mistakes)"
            )
        }
    }
    
    // MARK: - Boundary Tests
    
    func testBoundary_AllZeros() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4("0.0.0.0"))
    }
    
    func testBoundary_AllMaximum() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4("255.255.255.255"))
    }
    
    func testBoundary_Mixed() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4("0.255.0.255"))
        XCTAssertTrue(IPAddressValidator.isValidIPv4("255.0.255.0"))
    }
    
    func testBoundary_JustAboveMaximum() {
        XCTAssertFalse(IPAddressValidator.isValidIPv4("256.0.0.0"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("0.256.0.0"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("0.0.256.0"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("0.0.0.256"))
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_ValidateIPAddress() {
        measure {
            for _ in 0..<1000 {
                _ = IPAddressValidator.isValidIPv4("192.168.1.1")
            }
        }
    }
    
    func testPerformance_ValidateInvalidIPAddress() {
        measure {
            for _ in 0..<1000 {
                _ = IPAddressValidator.isValidIPv4("abc.def.ghi.jkl")
            }
        }
    }
}
