import XCTest
@testable import TToolsIPScanner

/// Umfassende Tests für OUIParser.
final class OUIParserTests: XCTestCase {
    
    // MARK: - normalizeOUI Tests
    
    func testNormalizeOUI_ColonSeparated() {
        // Given: Colon-separated MAC
        let input = "AA:BB:CC:DD:EE:FF"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Uppercase, ohne Trennzeichen
        XCTAssertEqual(result, "AABBCCDDEEFF")
    }
    
    func testNormalizeOUI_HyphenSeparated() {
        // Given: Hyphen-separated MAC
        let input = "AA-BB-CC-DD-EE-FF"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Uppercase, ohne Trennzeichen
        XCTAssertEqual(result, "AABBCCDDEEFF")
    }
    
    func testNormalizeOUI_DotSeparated() {
        // Given: Dot-separated MAC
        let input = "AA.BB.CC.DD.EE.FF"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Uppercase, ohne Trennzeichen
        XCTAssertEqual(result, "AABBCCDDEEFF")
    }
    
    func testNormalizeOUI_Lowercase() {
        // Given: Lowercase MAC
        let input = "aa:bb:cc:dd:ee:ff"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Konvertiert zu Uppercase
        XCTAssertEqual(result, "AABBCCDDEEFF")
    }
    
    func testNormalizeOUI_MixedCase() {
        // Given: Mixed case MAC
        let input = "Aa:bB:Cc:dD:eE:Ff"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Konvertiert zu Uppercase
        XCTAssertEqual(result, "AABBCCDDEEFF")
    }
    
    func testNormalizeOUI_NoSeparators() {
        // Given: Bereits ohne Trennzeichen
        let input = "AABBCCDDEEFF"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Bleibt unverändert
        XCTAssertEqual(result, "AABBCCDDEEFF")
    }
    
    func testNormalizeOUI_OnlyOUI() {
        // Given: Nur OUI (erste 6 Hex-Ziffern)
        let input = "AA:BB:CC"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Korrekt normalisiert
        XCTAssertEqual(result, "AABBCC")
    }
    
    func testNormalizeOUI_WithNonHexCharacters() {
        // Given: Mit nicht-hex Zeichen
        let input = "AA:BB:CC:XY:ZZ:00"
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Nur Hex-Zeichen bleiben
        XCTAssertEqual(result, "AABBCC00")
    }
    
    func testNormalizeOUI_EmptyString() {
        // Given: Leerer String
        let input = ""
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Leerer String
        XCTAssertEqual(result, "")
    }
    
    func testNormalizeOUI_OnlySeparators() {
        // Given: Nur Trennzeichen
        let input = "::--::.."
        
        // When: Normalisierung
        let result = OUIParser.normalizeOUI(input)
        
        // Then: Leerer String (alle Trennzeichen entfernt)
        XCTAssertEqual(result, "")
    }
    
    // MARK: - parseLine Wireshark Format Tests
    
    func testParseLine_WiresharkStandard() {
        // Given: Standard Wireshark manuf Format
        let line = "00:1A:11\tGoogle\tGoogle, Inc."
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: OUI und Vendor werden korrekt extrahiert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "001A11")
        XCTAssertEqual(result?.vendor, "Google, Inc.")
    }
    
    func testParseLine_WiresharkTwoFields() {
        // Given: Wireshark Format mit nur 2 Feldern
        let line = "00:1A:11\tGoogle"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Vendor ist das zweite Feld
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "001A11")
        XCTAssertEqual(result?.vendor, "Google")
    }
    
    func testParseLine_WiresharkWithHyphens() {
        // Given: Wireshark mit Hyphens
        let line = "B8-27-EB\tRaspberry\tRaspberry Pi Foundation"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Korrekt geparst
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "B827EB")
        XCTAssertEqual(result?.vendor, "Raspberry Pi Foundation")
    }
    
    func testParseLine_WiresharkLowercase() {
        // Given: Lowercase Wireshark Entry
        let line = "aa:bb:cc\tVendor\tFull Vendor Name"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: OUI wird zu Uppercase konvertiert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "AABBCC")
        XCTAssertEqual(result?.vendor, "Full Vendor Name")
    }
    
    // MARK: - parseLine IEEE Format Tests
    
    func testParseLine_IEEEStandard() {
        // Given: Standard IEEE oui.txt Format
        let line = "B8-27-EB   (hex)\t\tRaspberry Pi Foundation"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Korrekt geparst
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "B827EB")
        XCTAssertEqual(result?.vendor, "Raspberry Pi Foundation")
    }
    
    func testParseLine_IEEEWithSpaces() {
        // Given: IEEE Format mit vielen Spaces
        let line = "00-1A-11     (hex)    \t\t    Google, Inc."
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Spaces werden getrimmt
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "001A11")
        XCTAssertEqual(result?.vendor, "Google, Inc.")
    }
    
    func testParseLine_IEEELowercaseHex() {
        // Given: IEEE mit lowercase "(hex)"
        let line = "AA-BB-CC   (HEX)\t\tTest Vendor"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Case-insensitive parsing
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "AABBCC")
        XCTAssertEqual(result?.vendor, "Test Vendor")
    }
    
    func testParseLine_IEEEMixedCase() {
        // Given: IEEE mit mixed case
        let line = "aA-bB-cC   (HEx)\t\tMixed Vendor"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Korrekt geparst
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "AABBCC")
        XCTAssertEqual(result?.vendor, "Mixed Vendor")
    }
    
    // MARK: - parseLine Edge Cases
    
    func testParseLine_EmptyLine() {
        // Given: Leere Zeile
        let line = ""
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil wird zurückgegeben
        XCTAssertNil(result)
    }
    
    func testParseLine_CommentLine() {
        // Given: Kommentar-Zeile
        let line = "# This is a comment"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil wird zurückgegeben
        XCTAssertNil(result)
    }
    
    func testParseLine_OnlyWhitespace() {
        // Given: Nur Whitespace
        let line = "   \t   "
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil wird zurückgegeben
        XCTAssertNil(result)
    }
    
    func testParseLine_TooShortOUI() {
        // Given: Zu kurzer OUI (< 6 Hex-Ziffern)
        let line = "AA:BB\tVendor"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil (OUI muss mindestens 6 Zeichen haben)
        XCTAssertNil(result)
    }
    
    func testParseLine_NoVendor() {
        // Given: OUI ohne Vendor
        let line = "AA:BB:CC\t"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil (Vendor darf nicht leer sein)
        XCTAssertNil(result)
    }
    
    func testParseLine_IEEEWithoutVendor() {
        // Given: IEEE Format ohne Vendor
        let line = "AA-BB-CC   (hex)\t\t"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil
        XCTAssertNil(result)
    }
    
    func testParseLine_OnlyOUINoTab() {
        // Given: Nur OUI, kein Tab
        let line = "AA:BB:CC"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nil (kein Vendor-Feld)
        XCTAssertNil(result)
    }
    
    func testParseLine_LongOUI() {
        // Given: Längerer OUI (mehr als 6 Zeichen)
        let line = "AA:BB:CC:DD:EE:FF\tVendor\tFull Name"
        
        // When: Line wird geparst
        let result = OUIParser.parseLine(line)
        
        // Then: Nur die ersten 6 Zeichen werden verwendet
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.oui, "AABBCC")
        XCTAssertEqual(result?.vendor, "Full Name")
    }
    
    // MARK: - parse Content Tests
    
    func testParse_SimpleContent() {
        // Given: Einfacher Content mit 2 Entries
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc.
        B8:27:EB\tRaspberry\tRaspberry Pi Foundation
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Beide Entries sind im Dictionary
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["001A11"], "Google, Inc.")
        XCTAssertEqual(result["B827EB"], "Raspberry Pi Foundation")
    }
    
    func testParse_WithComments() {
        // Given: Content mit Kommentaren
        let content = """
        # Header comment
        00:1A:11\tGoogle\tGoogle, Inc.
        # Middle comment
        B8:27:EB\tRaspberry\tRaspberry Pi Foundation
        # End comment
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Kommentare werden ignoriert
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["001A11"], "Google, Inc.")
        XCTAssertEqual(result["B827EB"], "Raspberry Pi Foundation")
    }
    
    func testParse_WithEmptyLines() {
        // Given: Content mit leeren Zeilen
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc.
        
        
        B8:27:EB\tRaspberry\tRaspberry Pi Foundation
        
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Leere Zeilen werden ignoriert
        XCTAssertEqual(result.count, 2)
    }
    
    func testParse_MixedFormats() {
        // Given: Mix aus Wireshark und IEEE Format
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc.
        B8-27-EB   (hex)\t\tRaspberry Pi Foundation
        AA:BB:CC\tTest\tTest Vendor
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Beide Formate werden erkannt
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result["001A11"], "Google, Inc.")
        XCTAssertEqual(result["B827EB"], "Raspberry Pi Foundation")
        XCTAssertEqual(result["AABBCC"], "Test Vendor")
    }
    
    func testParse_DuplicateOUI() {
        // Given: Content mit dupliziertem OUI
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc.
        00:1A:11\tGoogle2\tGoogle Corporation
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Letzter Eintrag gewinnt
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["001A11"], "Google Corporation")
    }
    
    func testParse_EmptyContent() {
        // Given: Leerer Content
        let content = ""
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Leeres Dictionary
        XCTAssertEqual(result.count, 0)
    }
    
    func testParse_OnlyComments() {
        // Given: Nur Kommentare
        let content = """
        # Comment 1
        # Comment 2
        # Comment 3
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Leeres Dictionary
        XCTAssertEqual(result.count, 0)
    }
    
    func testParse_InvalidLines() {
        // Given: Content mit ungültigen Zeilen
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc.
        Invalid Line
        AA:BB\tTooShort
        B8:27:EB\tRaspberry\tRaspberry Pi Foundation
        Another Invalid Line
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Nur gültige Entries werden geparst
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["001A11"], "Google, Inc.")
        XCTAssertEqual(result["B827EB"], "Raspberry Pi Foundation")
    }
    
    func testParse_RealWorldSample() {
        // Given: Real-world sample (ähnlich wie echte oui.txt)
        let content = """
        # Wireshark manuf file
        # 
        # Last updated on 2024-01-01
        
        00:00:00\tXerox\tXEROX CORPORATION
        00:00:01\tXerox\tXEROX CORPORATION
        00:00:02\tXerox\tXEROX CORPORATION
        
        # Apple entries
        00:03:93\tApple\tApple, Inc.
        00:05:02\tApple\tApple, Inc.
        
        # IEEE format
        B8-27-EB   (hex)\t\tRaspberry Pi Foundation
        DC-A6-32   (hex)\t\tRaspberry Pi Trading Ltd
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Alle validen Entries sind vorhanden
        XCTAssertEqual(result.count, 7)
        XCTAssertEqual(result["000000"], "XEROX CORPORATION")
        XCTAssertEqual(result["000393"], "Apple, Inc.")
        XCTAssertEqual(result["B827EB"], "Raspberry Pi Foundation")
        XCTAssertEqual(result["DCA632"], "Raspberry Pi Trading Ltd")
    }
    
    func testParse_SpecialCharactersInVendor() {
        // Given: Vendor mit Sonderzeichen
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc. (USA) & Co.
        B8:27:EB\tRaspberry\tRaspberry Pi™ Foundation
        """
        
        // When: Content wird geparst
        let result = OUIParser.parse(content: content)
        
        // Then: Sonderzeichen bleiben erhalten
        XCTAssertEqual(result["001A11"], "Google, Inc. (USA) & Co.")
        XCTAssertEqual(result["B827EB"], "Raspberry Pi™ Foundation")
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_ParseAndLookup() {
        // Given: Content und MAC-Adresse
        let content = """
        00:1A:11\tGoogle\tGoogle, Inc.
        B8:27:EB\tRaspberry\tRaspberry Pi Foundation
        """
        let database = OUIParser.parse(content: content)
        
        // When: MAC wird für Lookup normalisiert
        let mac = "b8:27:eb:aa:bb:cc"
        let normalizedOUI = String(OUIParser.normalizeOUI(mac).prefix(6))
        
        // Then: Vendor kann gefunden werden
        XCTAssertEqual(database[normalizedOUI], "Raspberry Pi Foundation")
    }
    
    func testIntegration_NetworkConstantsAdditionalOUIs() {
        // Given: NetworkConstants.additionalOUIs
        let additionalOUIs = NetworkConstants.additionalOUIs
        
        // When: Jeder Eintrag wird geprüft
        for (oui, vendor) in additionalOUIs {
            // Then: OUI sollte normalisiert sein (6 Hex-Zeichen, Uppercase)
            XCTAssertEqual(oui.count, 6, "OUI '\(oui)' should be 6 characters")
            XCTAssertTrue(oui.allSatisfy { $0.isHexDigit }, "OUI '\(oui)' should be hex")
            XCTAssertEqual(oui, oui.uppercased(), "OUI '\(oui)' should be uppercase")
            XCTAssertFalse(vendor.isEmpty, "Vendor for '\(oui)' should not be empty")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_ParseLargeDatabase() {
        // Given: Große Datenbank (1000 Entries)
        var lines: [String] = []
        for i in 0..<1000 {
            let oui = String(format: "%02X:%02X:%02X", i / 256, (i / 16) % 16, i % 16)
            lines.append("\(oui)\tVendor\(i)\tFull Vendor Name \(i)")
        }
        let content = lines.joined(separator: "\n")
        
        // When/Then: Performance test
        measure {
            _ = OUIParser.parse(content: content)
        }
    }
    
    func testPerformance_NormalizeOUI() {
        let input = "AA:BB:CC:DD:EE:FF"
        
        measure {
            for _ in 0..<10000 {
                _ = OUIParser.normalizeOUI(input)
            }
        }
    }
    
    func testPerformance_ParseLine() {
        let line = "00:1A:11\tGoogle\tGoogle, Inc."
        
        measure {
            for _ in 0..<10000 {
                _ = OUIParser.parseLine(line)
            }
        }
    }
}
