import XCTest
@testable import TToolsIPScanner

final class HostNameVendorTests: XCTestCase {
    func testAppleUsesWordBoundaryForMac() {
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Johns-MacBook.local"), "Apple, Inc.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Living-Room-Mac"), "Apple, Inc.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "iPhone"), "Apple, Inc.")
        XCTAssertNil(HostNameVendor.manufacturer(from: "machine-room"))
        XCTAssertNil(HostNameVendor.manufacturer(from: "emacserver"))
    }
    
    func testAndroidIsNotSamsung() {
        XCTAssertEqual(HostNameVendor.manufacturer(from: "android-phone"), "Android")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Galaxy-S24"), "Samsung Electronics")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "android-samsung-tv"), "Samsung Electronics")
    }
    
    func testHomeNetworkBrands() {
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Fritz!Box 7590"), "AVM GmbH")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Sonos-One"), "Sonos, Inc.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "shellyplus1pm"), "Allterco Robotics (Shelly)")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "esp32-cam"), "Espressif Inc.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "esphome-kitchen"), "Espressif Inc.")
        XCTAssertNil(HostNameVendor.manufacturer(from: "especially-loud"))
        XCTAssertEqual(HostNameVendor.manufacturer(from: "HP-LaserJet"), "HP Inc.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Brother-MFC"), "Brother Industries, Ltd.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "EPSON-XP-4100"), "Seiko Epson Corporation")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "Synology-DS920"), "Synology Incorporated")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "QNAP-NAS"), "QNAP Systems, Inc.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "GT-AX11000"), "ASUSTek COMPUTER INC.")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "TP-Link_Archer"), "TP-Link Technologies")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "bosch-washerdryer"), "Bosch")
        XCTAssertEqual(HostNameVendor.manufacturer(from: "BRAVIA 4K GB"), "Sony Corporation")
        XCTAssertNil(HostNameVendor.manufacturer(from: "canonical-mirror"))
    }
    
    func testBonjourTXTManufacturerAndModel() {
        var bytes = Data()
        func append(_ pair: String) {
            let raw = Array(pair.utf8)
            bytes.append(UInt8(raw.count))
            bytes.append(contentsOf: raw)
        }
        append("md=HP")
        append("ty=HP LaserJet M404")
        append("product=(HP LaserJet)")
        
        let txt = BonjourScanner.parseTXT(bytes)
        XCTAssertEqual(txt["md"], "HP")
        XCTAssertEqual(txt["ty"], "HP LaserJet M404")
        
        var info = BonjourHostInfo()
        info.txt = txt
        XCTAssertEqual(info.manufacturerLabel, "HP")
        XCTAssertEqual(info.modelLabel, "HP LaserJet M404")
        XCTAssertEqual(HostNameVendor.manufacturer(fromBonjour: info), "HP Inc.")
        XCTAssertEqual(BonjourHostInfo.cleanTXTValue("(HP LaserJet)"), "HP LaserJet")
        
        var junk = BonjourHostInfo()
        junk.txt = ["md": "0,1,2"]
        XCTAssertNil(HostNameVendor.manufacturer(fromBonjour: junk))
    }
}
