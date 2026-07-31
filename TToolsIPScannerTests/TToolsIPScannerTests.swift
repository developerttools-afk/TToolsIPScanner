import Testing
@testable import TToolsIPScanner

struct TToolsIPScannerTests {

    // MARK: - IP validation
    
    @Test func validIPv4Addresses() {
        #expect(IPAddressValidator.isValidIPv4("192.168.1.1"))
        #expect(IPAddressValidator.isValidIPv4("0.0.0.0"))
        #expect(IPAddressValidator.isValidIPv4("255.255.255.255"))
        #expect(IPAddressValidator.isValidIPv4("10.0.0.1"))
    }
    
    @Test func invalidIPv4Addresses() {
        #expect(!IPAddressValidator.isValidIPv4(""))
        #expect(!IPAddressValidator.isValidIPv4("192.168.1"))
        #expect(!IPAddressValidator.isValidIPv4("192.168.1.256"))
        #expect(!IPAddressValidator.isValidIPv4("192.168.1.-1"))
        #expect(!IPAddressValidator.isValidIPv4("abc.def.ghi.jkl"))
        #expect(!IPAddressValidator.isValidIPv4("192.168.01.1"))
        #expect(!IPAddressValidator.isValidIPv4("192.168.1.1.1"))
    }
    
    // MARK: - Port list parsing
    
    @Test func parsePortList() {
        #expect(PortListParser.parse("80, 443, 22") == Set([80, 443, 22]))
        #expect(PortListParser.parse("80,abc,443") == Set([80, 443]))
        #expect(PortListParser.parse("") == [])
        #expect(PortListParser.parse("0, 65536, 8080") == Set([8080]))
    }
    
    @Test func formatPortList() {
        #expect(PortListParser.format([443, 80, 22]) == "22, 80, 443")
    }
    
    // MARK: - OUI parser
    
    @Test func parseWiresharkManufLine() {
        let entry = OUIParser.parseLine("00:1A:11\tGoogle\tGoogle, Inc.")
        #expect(entry?.oui == "001A11")
        #expect(entry?.vendor == "Google, Inc.")
    }
    
    @Test func parseIEEEOuiLine() {
        let entry = OUIParser.parseLine("B8-27-EB   (hex)\t\tRaspberry Pi Foundation")
        #expect(entry?.oui == "B827EB")
        #expect(entry?.vendor == "Raspberry Pi Foundation")
    }
    
    @Test func parseOUIContentSkipsComments() {
        let content = """
        # comment
        00:1A:11\tGoogle
        """
        let db = OUIParser.parse(content: content)
        #expect(db["001A11"] == "Google")
        #expect(db.count == 1)
    }
    
    // MARK: - Device status
    
    @Test func statusForNewAndCurrentDevices() {
        let previous: Set<String> = ["192.168.1.10", "192.168.1.20"]
        #expect(DeviceStatusResolver.status(for: "192.168.1.10", previousIPs: previous) == .current)
        #expect(DeviceStatusResolver.status(for: "192.168.1.99", previousIPs: previous) == .new)
    }
    
    @Test func missingIPsDetection() {
        let previous: Set<String> = ["192.168.1.10", "192.168.1.20", "192.168.1.30"]
        let found: Set<String> = ["192.168.1.10", "192.168.1.99"]
        #expect(DeviceStatusResolver.missingIPs(previousIPs: previous, foundIPs: found) == ["192.168.1.20", "192.168.1.30"])
    }
    
    // MARK: - Alias key
    
    @Test func aliasKeyPrefersMACThenIP() {
        let withMAC = DeviceInfo(
            ipAddress: "192.168.1.5",
            hostName: "host",
            macAddress: "AA:BB:CC:DD:EE:FF",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        #expect(withMAC.aliasKey == "AA:BB:CC:DD:EE:FF")
        
        let withoutMAC = DeviceInfo(
            ipAddress: "192.168.1.5",
            hostName: "host",
            macAddress: "",
            manufacturer: "",
            openPorts: [],
            status: .new,
            isExpanded: false
        )
        #expect(withoutMAC.aliasKey == "192.168.1.5")
    }
    
    // MARK: - Sorting
    
    @Test func sortDevicesByIP() {
        let scanner = NetworkScanner()
        scanner.devices = [
            DeviceInfo(ipAddress: "192.168.1.20", hostName: "b", macAddress: "", manufacturer: "Z", openPorts: [], status: .current, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.2", hostName: "a", macAddress: "", manufacturer: "A", openPorts: [], status: .new, isExpanded: false),
            DeviceInfo(ipAddress: "192.168.1.100", hostName: "c", macAddress: "", manufacturer: "M", openPorts: [], status: .current, isExpanded: false)
        ]
        scanner.sortOption = .ip
        scanner.sortAscending = true
        scanner.sortDevices()
        #expect(scanner.devices.map(\.ipAddress) == ["192.168.1.2", "192.168.1.20", "192.168.1.100"])
    }
}
