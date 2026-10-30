import XCTest
@testable import TToolsIPScanner

final class DeviceFingerprintTests: XCTestCase {
    func testSSHBannerIdentifiesRaspberryPiOS() {
        let banner = "SSH-2.0-OpenSSH_9.2p1 Raspbian-1"
        XCTAssertEqual(DeviceFingerprint.manufacturer(text: banner), DeviceFingerprint.raspberryPi)
        XCTAssertEqual(DeviceFingerprint.osHint(fromSSH: banner), "Raspberry Pi OS")
        XCTAssertNil(DeviceFingerprint.manufacturer(text: "SSH-2.0-OpenSSH_9.2p1 Debian-2"))
        XCTAssertEqual(DeviceFingerprint.osHint(fromSSH: "SSH-2.0-OpenSSH_8.9"), "OpenSSH")
    }
    
    func testHomeAssistantPortIsNotAPi() {
        XCTAssertEqual(DeviceFingerprint.manufacturer(ports: [8123]), DeviceFingerprint.homeAssistant)
        XCTAssertEqual(
            DeviceFingerprint.manufacturer(services: ["_home-assistant._tcp"]),
            DeviceFingerprint.homeAssistant
        )
        let banner = "SSH-2.0-OpenSSH_9.2p1 Raspberry Pi OS"
        XCTAssertEqual(
            DeviceFingerprint.manufacturer(text: banner, ports: [8123]),
            DeviceFingerprint.raspberryPi
        )
        XCTAssertTrue(DeviceFingerprint.replaces(current: DeviceFingerprint.homeAssistant, with: DeviceFingerprint.raspberryPi))
        XCTAssertFalse(DeviceFingerprint.replaces(current: DeviceFingerprint.raspberryPi, with: DeviceFingerprint.homeAssistant))
    }
    
    func testESPSignals() {
        XCTAssertEqual(DeviceFingerprint.manufacturer(ports: [6053]), DeviceFingerprint.espressif)
        XCTAssertEqual(DeviceFingerprint.manufacturer(services: ["_tasmota._tcp"]), DeviceFingerprint.espressif)
        XCTAssertEqual(DeviceFingerprint.manufacturer(services: ["_wled._tcp"]), DeviceFingerprint.espressif)
        XCTAssertEqual(
            DeviceFingerprint.manufacturer(services: ["_arduino._tcp"], txt: ["board": "ESP32"]),
            DeviceFingerprint.espressif
        )
        XCTAssertNil(DeviceFingerprint.manufacturer(services: ["_arduino._tcp"], txt: ["board": "uno"]))
        XCTAssertEqual(DeviceFingerprint.manufacturer(text: "ESP8266"), DeviceFingerprint.espressif)
    }
    
    func testHTTPTitleBeatsGenericServer() {
        let raw = "HTTP/1.1 200 OK\r\nServer: lighttpd/1.4.59\r\n\r\n<html><title>Pi-hole</title></html>"
        let fields = BannerGrabber.fields(fromHTTPResponse: raw)
        XCTAssertEqual(fields.server, "lighttpd/1.4.59")
        XCTAssertEqual(fields.title, "Pi-hole")
        XCTAssertEqual(DeviceFingerprint.httpDetail(server: fields.server, title: fields.title), "Pi-hole")
        XCTAssertEqual(DeviceFingerprint.manufacturer(text: "Pi-hole"), DeviceFingerprint.piHole)
        XCTAssertEqual(DeviceFingerprint.manufacturer(text: "OctoPrint"), DeviceFingerprint.octoPrint)
        XCTAssertEqual(DeviceFingerprint.httpDetail(server: "nginx", title: "WLED"), "WLED")
    }
    
    func testHostNamesAndCategory() {
        XCTAssertEqual(HostNameVendor.manufacturer(from: "wled-livingroom"), DeviceFingerprint.espressif)
        XCTAssertEqual(HostNameVendor.manufacturer(from: "pi-hole"), DeviceFingerprint.piHole)
        XCTAssertEqual(HostNameVendor.manufacturer(from: "octoprint.local"), DeviceFingerprint.octoPrint)
        
        var info = BonjourHostInfo()
        info.serviceTypes = ["_arduino._tcp"]
        info.txt = ["board": "esp32"]
        XCTAssertEqual(HostNameVendor.manufacturer(fromBonjour: info), DeviceFingerprint.espressif)
        
        XCTAssertEqual(
            DeviceCategoryResolver.categorize(
                ipAddress: "192.168.1.20",
                openPorts: [22, 8123],
                manufacturer: "",
                advertisedServices: [],
                hostName: "",
                osHint: ""
            ),
            .smartHome
        )
        XCTAssertEqual(
            DeviceCategoryResolver.categorize(
                ipAddress: "192.168.1.21",
                openPorts: [6053],
                manufacturer: "",
                advertisedServices: [],
                hostName: "",
                osHint: ""
            ),
            .iot
        )
    }
}
