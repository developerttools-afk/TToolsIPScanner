import XCTest
@testable import TToolsIPScanner

final class ServiceOpenActionTests: XCTestCase {
    private let ip = "192.168.1.20"
    
    func testPortSchemes() {
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 80)?.urlString, "http://\(ip)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 8080)?.urlString, "http://\(ip):8080")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 8000)?.urlString, "http://\(ip):8000")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 443)?.urlString, "https://\(ip)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 8443)?.urlString, "https://\(ip):8443")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 22)?.urlString, "ssh://\(ip)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 445)?.urlString, "smb://\(ip)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 548)?.urlString, "afp://\(ip)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 5900)?.urlString, "vnc://\(ip)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 21)?.urlString, "ftp://\(ip)")
        
        let rdp = NetworkConstants.openAction(ip: ip, port: 3389)
        XCTAssertTrue(rdp?.urlString.hasPrefix("rdp://") == true)
        XCTAssertTrue(rdp?.urlString.contains(ip) == true)
        XCTAssertEqual(rdp?.title, "Remote Desktop (:3389)")
        XCTAssertEqual(NetworkConstants.openAction(ip: ip, port: 443)?.title, "Webseite (HTTPS :443)")
        XCTAssertNil(NetworkConstants.openAction(ip: ip, port: 53))
    }
    
    func testHTTPSWinsOverHTTP() {
        let primary = NetworkConstants.primaryOpenAction(ip: ip, openPorts: [80, 443, 22])
        XCTAssertEqual(primary?.urlString, "https://\(ip)")
    }
    
    func testOnlyHTTPSDoesNotOpenHTTP() {
        let actions = NetworkConstants.openActions(ip: ip, openPorts: [443])
        XCTAssertEqual(actions.map(\.urlString), ["https://\(ip)"])
    }
    
    func testBonjourServiceAddsActionWithoutOpenPort() {
        let actions = NetworkConstants.openActions(
            ip: ip,
            openPorts: [],
            advertisedServices: ["_https._tcp", "_ssh._tcp."]
        )
        let urls = Set(actions.map(\.urlString))
        XCTAssertTrue(urls.contains("https://\(ip)"))
        XCTAssertTrue(urls.contains("ssh://\(ip)"))
    }
    
    func testBonjourDoesNotDuplicateOpenPort() {
        let actions = NetworkConstants.openActions(
            ip: ip,
            openPorts: [443],
            advertisedServices: ["_https._tcp.local."]
        )
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.urlString, "https://\(ip)")
    }
    
    func testPortLetterLegendKeepsKnownOrder() {
        let legend = NetworkConstants.portLetterLegend(for: [22, 443, 445, 9999])
        XCTAssertEqual(legend.map(\.letter), ["w", "s", "b"])
        XCTAssertEqual(legend.map(\.name), ["Web", "SSH", "SMB"])
        XCTAssertTrue(NetworkConstants.portLetterLegend(for: []).isEmpty)
    }
    
    func testLANHTTPParsesStatusAndServer() {
        let raw = Data("HTTP/1.1 200 OK\r\nServer: lighttpd\r\n\r\n<title>Pi-hole</title>".utf8)
        let page = LANHTTP.parse(raw)
        XCTAssertEqual(page?.status, 200)
        XCTAssertEqual(page?.headers["server"], "lighttpd")
        XCTAssertEqual(String(data: page?.body ?? Data(), encoding: .utf8), "<title>Pi-hole</title>")
    }
    
    func testDeviceLegendIncludesDiscoveryAndPortLetters() {
        let device = DeviceInfo(
            ipAddress: "192.168.1.20",
            hostName: "host",
            macAddress: "",
            manufacturer: "",
            openPorts: [80, 22, 445, 5900],
            status: .current,
            isExpanded: false
        )
        XCTAssertEqual(
            DeviceBadges.legend(for: [device]).map(\.letter),
            ["W", "P", "w", "s", "b", "v"]
        )
    }
}
