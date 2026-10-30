import XCTest
@testable import TToolsIPScanner

final class IPv6DiscoveryTests: XCTestCase {
    private func makeDevice(ip: String, name: String, mac: String) -> DeviceInfo {
        DeviceInfo(
            ipAddress: ip,
            hostName: name,
            macAddress: mac,
            manufacturer: "",
            openPorts: [],
            status: .current,
            isExpanded: false
        )
    }
   
    func testRouteMessageHeaderMatchesTheKernelStruct() {
        XCTAssertEqual(MemoryLayout<RouteMessageHeader>.stride, MemoryLayout<rt_msghdr>.stride)
        XCTAssertEqual(MemoryLayout<RouteMessageHeader>.offset(of: \.rtm_addrs), MemoryLayout<rt_msghdr>.offset(of: \.rtm_addrs))
    }
    
    func testRouteAddressStrideRoundsUpToFour() {
        XCTAssertEqual(RouteSocketAddress.stride(saLen: 0), 4)
        XCTAssertEqual(RouteSocketAddress.stride(saLen: 16), 16)
        XCTAssertEqual(RouteSocketAddress.stride(saLen: 20), 20)
        XCTAssertEqual(RouteSocketAddress.stride(saLen: 28), 28)
        XCTAssertEqual(RouteSocketAddress.stride(saLen: 18), 20)
    }
    
    func testIPv6LiteralParsing() {
        XCTAssertTrue(IPv6Address.isIPv6("2001:db8::1"))
        XCTAssertTrue(IPv6Address.isHostAddress("fe80::1%en0"))
        XCTAssertFalse(IPv6Address.isIPv6("192.168.1.1"))
        XCTAssertFalse(IPv6Address.isHostAddress("ff02::1"))
        XCTAssertFalse(IPv6Address.isHostAddress("::1"))
    }
    
    func testPreferredAddressKeepsGlobal() {
        let chosen = IPv6Address.preferred("fe80::1%en0", "2001:db8::1")
        XCTAssertEqual(chosen, "2001:db8::1")
    }
    
    func testCollapseKeepsOneAddressPerMAC() {
        let hosts = IPv6Discovery.collapse([
            IPv6Discovery.Candidate(address: "fe80::1%en0", macAddress: "aa:bb:cc:dd:ee:ff"),
            IPv6Discovery.Candidate(address: "2001:db8::1", macAddress: "AA:BB:CC:DD:EE:FF")
        ])
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].address, "2001:db8::1")
        XCTAssertEqual(hosts[0].macAddress, "AA:BB:CC:DD:EE:FF")
    }
    
    func testHostLiteralBracketsIPv6() {
        XCTAssertEqual(IPv6Address.hostLiteral("2001:db8::1"), "[2001:db8::1]")
        XCTAssertEqual(IPv6Address.hostLiteral("192.168.1.1"), "192.168.1.1")
        XCTAssertEqual(
            NetworkConstants.openAction(ip: "2001:db8::1", port: 80)?.urlString,
            "http://[2001:db8::1]"
        )
    }
    
    func testEmbeddedScopeUsesTheSameHostAsLinkLocal() {
        var bytes = IPv6Address.bytes(of: "fe80::cdc:f5b7:de2b:81b7")!
        bytes[3] = 0x10
        let formatted = IPv6Address.format(bytes)
        XCTAssertTrue(formatted?.hasPrefix("fe80::cdc:f5b7:de2b:81b7") == true)
        
        let hosts = IPv6Discovery.collapse([
            IPv6Discovery.Candidate(address: "fe80::cdc:f5b7:de2b:81b7%en0", macAddress: ""),
            IPv6Discovery.Candidate(address: "fe80:10::cdc:f5b7:de2b:81b7", macAddress: "f2:f7:c5:25:43:f9")
        ])
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].macAddress, "F2:F7:C5:25:43:F9")
        XCTAssertTrue(hosts[0].address.hasPrefix("fe80::cdc:f5b7:de2b:81b7"))
    }
    
    func testCollapseCopiesMACOntoTheSameAddress() {
        let hosts = IPv6Discovery.collapse([
            IPv6Discovery.Candidate(address: "2001:db8::1", macAddress: ""),
            IPv6Discovery.Candidate(address: "2001:db8::1", macAddress: "aa:bb:cc:dd:ee:ff")
        ])
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].macAddress, "AA:BB:CC:DD:EE:FF")
    }
    
    func testPairingFoldsIPv6RowOntoIPv4ByMAC() {
        let paired = IPv6Pairing.pair([
            makeDevice(ip: "192.168.1.20", name: "Wohnzimmer", mac: "AA:BB:CC:DD:EE:FF"),
            makeDevice(ip: "2001:db8::20", name: "Wohnzimmer", mac: "aa:bb:cc:dd:ee:ff")
        ])
        XCTAssertEqual(paired.count, 1)
        XCTAssertEqual(paired[0].ipAddress, "192.168.1.20")
        XCTAssertEqual(paired[0].ipv6Address, "2001:db8::20")
    }
    
    func testPairingFoldsEUI64WithoutStoredMAC() {
        let paired = IPv6Pairing.pair([
            makeDevice(ip: "192.168.1.21", name: "Gerät .21", mac: "AA:BB:CC:DD:EE:FF"),
            makeDevice(ip: "2001:db8::a8bb:ccff:fedd:eeff", name: "Gerät ab", mac: "")
        ])
        XCTAssertEqual(paired.count, 1)
        XCTAssertEqual(paired[0].ipv6Address, "2001:db8::a8bb:ccff:fedd:eeff")
    }
    
    func testPairingUsesASharedHostName() {
        let paired = IPv6Pairing.pair([
            makeDevice(ip: "192.168.1.30", name: "Drucker", mac: ""),
            makeDevice(ip: "2001:db8::30", name: "Drucker", mac: "")
        ])
        XCTAssertEqual(paired.count, 1)
        XCTAssertEqual(paired[0].ipAddress, "192.168.1.30")
        XCTAssertEqual(paired[0].ipv6Address, "2001:db8::30")
    }
    
    func testPairingDoesNotFoldPlaceholderNames() {
        let paired = IPv6Pairing.pair([
            makeDevice(ip: "192.168.1.31", name: "Gerät .31", mac: ""),
            makeDevice(ip: "2001:db8::31", name: "Gerät 31", mac: "")
        ])
        XCTAssertEqual(paired.count, 2)
    }
    
    func testScanIPv6DefaultsOff() {
        let defaults = UserDefaults(suiteName: "IPv6DiscoveryTests_\(UUID().uuidString)")!
        let settings = SettingsManager(storage: defaults)
        XCTAssertFalse(settings.scanIPv6)
        settings.scanIPv6 = true
        XCTAssertTrue(SettingsManager(storage: defaults).scanIPv6)
    }
}
