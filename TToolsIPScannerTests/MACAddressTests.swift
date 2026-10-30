import XCTest
@testable import TToolsIPScanner

final class MACAddressTests: XCTestCase {
    func testNormalizeAcceptsSeparators() {
        XCTAssertEqual(MACAddress.normalize("aa:bb:cc:dd:ee:ff"), "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(MACAddress.normalize("AA-BB-CC-DD-EE-FF"), "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(MACAddress.normalize("aabbccddeeff"), "AA:BB:CC:DD:EE:FF")
    }
    
    func testNormalizeRejectsMulticastAndEmpty() {
        XCTAssertNil(MACAddress.normalize("01:00:5E:00:00:01"))
        XCTAssertNil(MACAddress.normalize("00:00:00:00:00:00"))
        XCTAssertNil(MACAddress.normalize("FF:FF:FF:FF:FF:FF"))
        XCTAssertNil(MACAddress.normalize("AA:BB:CC"))
    }
    
    func testRAOPInstanceName() {
        let parsed = MACAddress.raopInstance("A0B2C3D4E5F6@Wohnzimmer")
        XCTAssertEqual(parsed?.mac, "A0:B2:C3:D4:E5:F6")
        XCTAssertEqual(parsed?.friendly, "Wohnzimmer")
        XCTAssertNil(MACAddress.raopInstance("Wohnzimmer"))
        XCTAssertNil(MACAddress.raopInstance("not-a-mac@Wohnzimmer"))
    }
    
    func testWorkstationBracket() {
        let parsed = MACAddress.workstationName("homeassistant [b8:27:eb:11:22:33]")
        XCTAssertEqual(parsed?.mac, "B8:27:EB:11:22:33")
        XCTAssertEqual(parsed?.friendly, "homeassistant")
        XCTAssertNil(MACAddress.workstationName("host [wlan0]"))
    }
    
    func testAirPlayAndShellyTXT() {
        let airplay = MACAddress.bonjourIdentity(
            serviceType: "_airplay._tcp",
            instanceName: "Wohnzimmer",
            txt: ["deviceid": "aa:bb:cc:dd:ee:01"]
        )
        XCTAssertEqual(airplay.mac, "AA:BB:CC:DD:EE:01")
        
        let shelly = MACAddress.bonjourIdentity(
            serviceType: "_shelly._tcp",
            instanceName: "shellyplus1",
            txt: ["mac": "C45BBE112233"]
        )
        XCTAssertEqual(shelly.mac, "C4:5B:BE:11:22:33")
        
        let ignored = MACAddress.bonjourIdentity(
            serviceType: "_http._tcp",
            instanceName: "printer",
            txt: ["mac": "C45BBE112233", "deviceid": "aa:bb:cc:dd:ee:01"]
        )
        XCTAssertNil(ignored.mac)
    }
    
    func testEUI64FlipsBit7() {
        let iid: [UInt8] = [0x02, 0x1A, 0x2B, 0xFF, 0xFE, 0x3C, 0x4D, 0x5E]
        XCTAssertEqual(MACAddress.fromEUI64(interfaceID: iid), "00:1A:2B:3C:4D:5E")
        let privacy: [UInt8] = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
        XCTAssertNil(MACAddress.fromEUI64(interfaceID: privacy))
    }
    
    func testNetBIOSUnitIDFollowsNameTable() {
        var packet = [UInt8](repeating: 0, count: 12)
        packet[0] = 0x12
        packet[1] = 0x34
        packet[2] = 0x84
        packet[7] = 0x01
        packet.append(contentsOf: [0xC0, 0x0C, 0x00, 0x21, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
        packet.append(contentsOf: [0x00, 25, 0x01])
        var name = Array("LIVINGROOM".utf8)
        name.append(contentsOf: [UInt8](repeating: 0x20, count: 15 - name.count))
        name.append(0x00)
        name.append(contentsOf: [0x00, 0x00])
        packet.append(contentsOf: name)
        packet.append(contentsOf: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55])
        
        let status = NetBIOSQuery.parseNodeStatus(bytes: packet, length: packet.count)
        XCTAssertEqual(status.name, "LIVINGROOM")
        XCTAssertEqual(status.macAddress, "00:11:22:33:44:55")
    }
    
    func testLegacyNetBIOSOffsetStillYieldsName() {
        var packet = [UInt8](repeating: 0, count: 58)
        packet[57] = 1
        var name = Array("SERVER".utf8)
        name.append(contentsOf: [UInt8](repeating: 0x20, count: 15 - name.count))
        name.append(0x00)
        name.append(0x04)
        name.append(0x00)
        packet.append(contentsOf: name)
        
        let status = NetBIOSQuery.parseNodeStatus(bytes: packet, length: packet.count)
        XCTAssertEqual(status.name, "SERVER")
    }
}
