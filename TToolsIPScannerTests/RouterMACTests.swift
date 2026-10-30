import XCTest
@testable import TToolsIPScanner

final class RouterMACTests: XCTestCase {
    func testFritzMD5Challenge() {
        let response = FritzBoxHosts.response(challenge: "1234567z", password: "äbc")
        XCTAssertEqual(response, "1234567z-9e224a41eeefa284df7bb0f26c2913e2")
    }
    
    func testFritzPBKDF2Challenge() {
        let challenge = "2$1$0011223344556677$1$8899aabbccddeeff"
        let response = FritzBoxHosts.response(challenge: challenge, password: "test")
        XCTAssertEqual(
            response,
            "8899aabbccddeeff$302c3da7314810b834f7625e5e7e2dde543a941d48f31a1d6eeec80c7539a129"
        )
    }
    
    func testFritzHostEntryXML() {
        let xml = """
        <NewIPAddress>192.168.178.20</NewIPAddress>
        <NewMACAddress>AA:BB:CC:DD:EE:FF</NewMACAddress>
        <NewHostName>arbeitszimmer</NewHostName>
        """
        XCTAssertEqual(FritzBoxHosts.xmlValue("NewIPAddress", in: xml), "192.168.178.20")
        XCTAssertEqual(FritzBoxHosts.xmlValue("NewMACAddress", in: xml), "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(MACAddress.normalize(FritzBoxHosts.xmlValue("NewMACAddress", in: xml) ?? ""), "AA:BB:CC:DD:EE:FF")
    }
    
    func testSNMPPhysAddressIndex() {
        let oid: [UInt64] = [1, 3, 6, 1, 2, 1, 4, 22, 1, 2, 1, 192, 168, 1, 10]
        let mac: [UInt8] = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]
        let host = SNMPProbe.hostFromPhysAddress(oid: oid, value: mac)
        XCTAssertEqual(host?.ip, "192.168.1.10")
        XCTAssertEqual(host?.mac, "00:11:22:33:44:55")
        XCTAssertNil(SNMPProbe.hostFromPhysAddress(oid: [1, 3, 6, 1], value: mac))
    }
    
    func testSNMPGetResponseRoundTrip() {
        let oidBytes: [UInt8] = [
            0x2B, 0x06, 0x01, 0x02, 0x01, 0x04, 0x16, 0x01, 0x02, 0x01,
            0x81, 0x40, 0x81, 0x28, 0x01, 0x0A
        ]
        let oidTLV: [UInt8] = [0x06, UInt8(oidBytes.count)] + oidBytes
        let value: [UInt8] = [0x04, 0x06, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55]
        let varbind: [UInt8] = [0x30, UInt8(oidTLV.count + value.count)] + oidTLV + value
        let list: [UInt8] = [0x30, UInt8(varbind.count)] + varbind
        let pduBody: [UInt8] = [0x02, 0x01, 0x01, 0x02, 0x01, 0x00, 0x02, 0x01, 0x00] + list
        let pdu: [UInt8] = [0xA2, UInt8(pduBody.count)] + pduBody
        let messageBody: [UInt8] = [0x02, 0x01, 0x00, 0x04, 0x06] + Array("public".utf8) + pdu
        let packet: [UInt8] = [0x30, UInt8(messageBody.count)] + messageBody
        
        let parsed = SNMPBER.parseGetResponse(packet)
        XCTAssertEqual(parsed?.error, 0)
        let host = parsed.flatMap { SNMPProbe.hostFromPhysAddress(oid: $0.oid, value: $0.value) }
        XCTAssertEqual(host?.ip, "192.168.1.10")
        XCTAssertEqual(host?.mac, "00:11:22:33:44:55")
    }
}
