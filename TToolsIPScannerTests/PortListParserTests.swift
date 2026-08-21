import XCTest
@testable import TToolsIPScanner

/// Umfassende Tests für PortListParser.
final class PortListParserTests: XCTestCase {
    
    // MARK: - Parse Tests
    
    func testParse_SinglePort() {
        // Given: Einzelner Port
        let input = "80"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Port wird korrekt geparst
        XCTAssertEqual(result, [80])
    }
    
    func testParse_MultiplePorts() {
        // Given: Mehrere Ports
        let input = "80, 443, 22"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Alle Ports werden geparst
        XCTAssertEqual(result, [80, 443, 22])
    }
    
    func testParse_WithWhitespace() {
        // Given: Ports mit verschiedenen Whitespace-Varianten
        let inputs = [
            "80,443,22",           // Keine Spaces
            "80, 443, 22",         // Normale Spaces
            "80 , 443 , 22",       // Spaces um Kommas
            "  80  ,  443  ,  22  " // Viele Spaces
        ]
        
        // When/Then: Alle sollten gleich geparst werden
        let expected: Set<Int> = [80, 443, 22]
        for input in inputs {
            XCTAssertEqual(
                PortListParser.parse(input),
                expected,
                "Failed for input: '\(input)'"
            )
        }
    }
    
    func testParse_EmptyString() {
        // Given: Leerer String
        let input = ""
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Leeres Set wird zurückgegeben
        XCTAssertEqual(result, [])
    }
    
    func testParse_OnlyWhitespace() {
        // Given: Nur Whitespace
        let inputs = [" ", "  ", "\t", "\n", "   \t\n  "]
        
        // When/Then: Alle sollten leeres Set zurückgeben
        for input in inputs {
            XCTAssertEqual(
                PortListParser.parse(input),
                [],
                "Failed for whitespace input"
            )
        }
    }
    
    func testParse_DuplicatePorts() {
        // Given: Duplizierte Ports
        let input = "80, 80, 443, 22, 80"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Set enthält jeden Port nur einmal
        XCTAssertEqual(result, [80, 443, 22])
        XCTAssertEqual(result.count, 3)
    }
    
    func testParse_InvalidPorts() {
        // Given: Ungültige Ports gemischt mit gültigen
        let input = "80, abc, 443, xyz, 22"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Nur gültige Ports werden geparst
        XCTAssertEqual(result, [80, 443, 22])
    }
    
    func testParse_OutOfRangePorts() {
        // Given: Ports außerhalb des gültigen Bereichs
        let input = "0, 80, 443, 65536, 99999"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Nur Ports im Bereich 1-65535 werden akzeptiert
        XCTAssertEqual(result, [80, 443])
    }
    
    func testParse_BoundaryPorts() {
        // Given: Grenzwert-Ports
        let input = "1, 65535"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Beide Grenzwerte werden akzeptiert
        XCTAssertEqual(result, [1, 65535])
    }
    
    func testParse_JustOutOfBounds() {
        // Given: Knapp außerhalb der Grenzen
        let input = "0, 1, 65535, 65536"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Nur 1 und 65535 sind gültig
        XCTAssertEqual(result, [1, 65535])
    }
    
    func testParse_NegativePorts() {
        // Given: Negative Ports
        let input = "-1, -80, 443, -999"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Negative Ports werden ignoriert
        XCTAssertEqual(result, [443])
    }
    
    func testParse_CommonPorts() {
        // Given: Standard-Ports
        let input = "21, 22, 23, 25, 53, 80, 110, 143, 443, 3306, 3389, 5432, 8080, 8443"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Alle Standard-Ports werden geparst
        XCTAssertEqual(result.count, 14)
        XCTAssertTrue(result.contains(80))
        XCTAssertTrue(result.contains(443))
        XCTAssertTrue(result.contains(8080))
    }
    
    func testParse_LargeNumbers() {
        // Given: Sehr große Zahlen
        let input = "80, 999999999, 443, 1234567890"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Nur gültige Ports werden akzeptiert
        XCTAssertEqual(result, [80, 443])
    }
    
    func testParse_MixedInvalid() {
        // Given: Mix aus allen Arten von ungültigen Eingaben
        let input = "abc, 0, -1, 80, def, 65536, 443, xyz, 99999, 22"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Nur die 3 gültigen Ports
        XCTAssertEqual(result, [80, 443, 22])
    }
    
    func testParse_OnlyCommas() {
        // Given: Nur Kommas
        let input = ",,,,,"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Leeres Set
        XCTAssertEqual(result, [])
    }
    
    func testParse_TrailingComma() {
        // Given: Trailing Comma
        let input = "80, 443, 22,"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Ports werden korrekt geparst
        XCTAssertEqual(result, [80, 443, 22])
    }
    
    func testParse_LeadingComma() {
        // Given: Leading Comma
        let input = ",80, 443, 22"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Ports werden korrekt geparst
        XCTAssertEqual(result, [80, 443, 22])
    }
    
    func testParse_MultipleCommas() {
        // Given: Mehrfache Kommas
        let input = "80,,,,443,,22"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Ports werden korrekt geparst
        XCTAssertEqual(result, [80, 443, 22])
    }
    
    func testParse_SpecialCharacters() {
        // Given: Sonderzeichen
        let input = "80!, 443#, @22, 8080$"
        
        // When: Parse wird aufgerufen
        let result = PortListParser.parse(input)
        
        // Then: Werden als ungültig ignoriert
        XCTAssertEqual(result, [])
    }
    
    // MARK: - Format Tests
    
    func testFormat_SinglePort() {
        // Given: Einzelner Port
        let ports: Set<Int> = [80]
        
        // When: Format wird aufgerufen
        let result = PortListParser.format(ports)
        
        // Then: Korrekt formatiert
        XCTAssertEqual(result, "80")
    }
    
    func testFormat_MultiplePorts() {
        // Given: Mehrere Ports
        let ports: Set<Int> = [443, 80, 22]
        
        // When: Format wird aufgerufen
        let result = PortListParser.format(ports)
        
        // Then: Sortiert und komma-getrennt
        XCTAssertEqual(result, "22, 80, 443")
    }
    
    func testFormat_EmptySet() {
        // Given: Leeres Set
        let ports: Set<Int> = []
        
        // When: Format wird aufgerufen
        let result = PortListParser.format(ports)
        
        // Then: Leerer String
        XCTAssertEqual(result, "")
    }
    
    func testFormat_CommonPorts() {
        // Given: Standard-Ports
        let ports: Set<Int> = [22, 80, 443, 8080, 3306]
        
        // When: Format wird aufgerufen
        let result = PortListParser.format(ports)
        
        // Then: Sortiert formatiert
        XCTAssertEqual(result, "22, 80, 443, 3306, 8080")
    }
    
    func testFormat_LargePorts() {
        // Given: Hohe Port-Nummern
        let ports: Set<Int> = [65535, 1, 32768]
        
        // When: Format wird aufgerufen
        let result = PortListParser.format(ports)
        
        // Then: Korrekt sortiert
        XCTAssertEqual(result, "1, 32768, 65535")
    }
    
    func testFormat_ManyPorts() {
        // Given: Viele Ports
        let ports: Set<Int> = Set(1...100)
        
        // When: Format wird aufgerufen
        let result = PortListParser.format(ports)
        
        // Then: Alle Ports sind enthalten und sortiert
        XCTAssertTrue(result.hasPrefix("1, 2, 3"))
        XCTAssertTrue(result.hasSuffix("98, 99, 100"))
        XCTAssertEqual(result.components(separatedBy: ", ").count, 100)
    }
    
    // MARK: - Round-Trip Tests
    
    func testRoundTrip_ParseAndFormat() {
        // Given: Formatierter String
        let original = "22, 80, 443, 8080"
        
        // When: Parse und dann Format
        let parsed = PortListParser.parse(original)
        let formatted = PortListParser.format(parsed)
        
        // Then: Ergebnis ist identisch
        XCTAssertEqual(formatted, original)
    }
    
    func testRoundTrip_WithInvalidEntries() {
        // Given: String mit ungültigen Einträgen
        let input = "22, abc, 80, xyz, 443"
        
        // When: Parse und dann Format
        let parsed = PortListParser.parse(input)
        let formatted = PortListParser.format(parsed)
        
        // Then: Nur gültige Ports bleiben
        XCTAssertEqual(formatted, "22, 80, 443")
    }
    
    func testRoundTrip_UnsortedInput() {
        // Given: Unsortierte Eingabe
        let input = "8080, 22, 443, 80"
        
        // When: Parse und dann Format
        let parsed = PortListParser.parse(input)
        let formatted = PortListParser.format(parsed)
        
        // Then: Output ist sortiert
        XCTAssertEqual(formatted, "22, 80, 443, 8080")
    }
    
    func testRoundTrip_WithDuplicates() {
        // Given: Input mit Duplikaten
        let input = "80, 80, 443, 22, 443"
        
        // When: Parse und dann Format
        let parsed = PortListParser.parse(input)
        let formatted = PortListParser.format(parsed)
        
        // Then: Duplikate werden entfernt
        XCTAssertEqual(formatted, "22, 80, 443")
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_NetworkConstantsDefaultPorts() {
        // Given: NetworkConstants.defaultPorts
        let defaultPorts = NetworkConstants.defaultPorts
        
        // When: Format wird aufgerufen
        let formatted = PortListParser.format(defaultPorts)
        
        // Then: Kann wieder geparst werden
        let reparsed = PortListParser.parse(formatted)
        XCTAssertEqual(reparsed, defaultPorts)
    }
    
    func testIntegration_EmptyToEmptyRoundTrip() {
        // Given: Leerer String
        let input = ""
        
        // When: Parse und Format
        let parsed = PortListParser.parse(input)
        let formatted = PortListParser.format(parsed)
        
        // Then: Ergebnis ist auch leer
        XCTAssertEqual(formatted, "")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_ParseManyPorts() {
        let input = (1...1000).map(String.init).joined(separator: ", ")
        
        measure {
            _ = PortListParser.parse(input)
        }
    }
    
    func testPerformance_FormatManyPorts() {
        let ports = Set(1...1000)
        
        measure {
            _ = PortListParser.format(ports)
        }
    }
    
    func testPerformance_ParseWithInvalidData() {
        let input = String(repeating: "abc, ", count: 1000) + "80, 443"
        
        measure {
            _ = PortListParser.parse(input)
        }
    }
}
