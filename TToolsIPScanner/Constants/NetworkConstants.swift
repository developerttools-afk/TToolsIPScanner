import SwiftUI

enum NetworkConstants {
    static let portDescriptions: [Int: String] = [
        20: "FTP (Data)",
        21: "FTP (Control)",
        22: "SSH",
        23: "Telnet",
        25: "SMTP",
        53: "DNS",
        67: "DHCP Server",
        68: "DHCP Client",
        69: "TFTP",
        80: "HTTP",
        110: "POP3",
        123: "NTP",
        137: "NetBIOS Name",
        138: "NetBIOS Datagram",
        139: "NetBIOS Session",
        143: "IMAP",
        161: "SNMP",
        162: "SNMP Trap",
        389: "LDAP",
        443: "HTTPS",
        445: "Microsoft-DS (SMB)",
        548: "AFP",
        465: "SMTP over SSL",
        500: "ISAKMP/IKE",
        514: "Syslog",
        515: "LPD/LPR",
        520: "RIP",
        587: "SMTP (Submission)",
        631: "IPP (Printing)",
        636: "LDAPS",
        993: "IMAPS",
        995: "POP3S",
        1433: "MS SQL",
        1434: "MS SQL Browser",
        1521: "Oracle",
        1723: "PPTP",
        3306: "MySQL",
        3389: "RDP",
        5432: "PostgreSQL",
        5900: "VNC",
        8000: "HTTP Alternate",
        8080: "HTTP Alternate",
        8443: "HTTPS Alternate",
        1883: "MQTT",
        6053: "ESPHome",
        8123: "Home Assistant",
        8883: "MQTT over SSL"
    ]
    
    /// Compact letters for list/table badges (s = SSH, w = Web, …).
    static let portLetters: [Int: String] = [
        20: "f", 21: "f",
        22: "s",
        23: "t",
        25: "m", 465: "m", 587: "m", 110: "m", 143: "m", 993: "m", 995: "m",
        53: "d",
        67: "c", 68: "c",
        80: "w", 443: "w", 8080: "w", 8443: "w",
        123: "n",
        137: "b", 139: "b", 445: "b",
        161: "g",
        389: "l", 636: "l",
        515: "p", 631: "p",
        548: "a",
        1883: "q", 8883: "q",
        3306: "y", 5432: "y", 1433: "y",
        3389: "r",
        5900: "v"
    ]
    
    static func portLetter(for port: Int) -> String {
        portLetters[port] ?? "\(port)"
    }
    
    /// Short names for the badge letters, in legend order.
    static let portLetterNames: [(letter: String, name: String)] = [
        ("w", "Web"),
        ("s", "SSH"),
        ("t", "Telnet"),
        ("f", "FTP"),
        ("m", "Mail"),
        ("d", "DNS"),
        ("b", "SMB"),
        ("p", "Druck"),
        ("a", "AFP"),
        ("r", "RDP"),
        ("v", "VNC"),
        ("q", "MQTT"),
        ("y", "DB"),
        ("g", "SNMP"),
        ("n", "NTP"),
        ("c", "DHCP"),
        ("l", "LDAP")
    ]
    
    /// Letters that actually appear on the given open ports, in legend order.
    static func portLetterLegend(for ports: [Int]) -> [(letter: String, name: String)] {
        let used = Set(ports.compactMap { portLetters[$0] })
        return portLetterNames.filter { used.contains($0.letter) }
    }
    
    static func portBadgeHelp(for port: Int) -> String {
        if let name = portDescriptions[port] {
            return "\(name) · \(port)"
        }
        return "Port \(port)"
    }
    
    static let portSymbols: [Int: (symbol: String, color: Color)] = [
        20: ("arrow.down", .blue),
        21: ("arrow.up.arrow.down", .blue),
        22: ("terminal", .green),
        23: ("terminal", .red),
        25: ("envelope", .blue),
        53: ("network", .orange),
        80: ("safari", .blue),
        110: ("envelope.badge.shield", .blue),
        143: ("envelope.open", .blue),
        443: ("lock.shield", .green),
        445: ("folder", .blue),
        1883: ("antenna.radiowaves.left.and.right", .purple),
        3306: ("database", .orange),
        3389: ("display", .blue),
        5900: ("rectangle.on.rectangle", .purple),
        8080: ("safari.fill", .blue),
        8443: ("lock.shield.fill", .green),
        8883: ("antenna.radiowaves.left.and.right.shield", .purple)
    ]
    
    static let additionalOUIs: [String: String] = [
        "C2906D": "Apple, Inc.",
        "C82A14": "Apple, Inc.",
        "CCCDB8": "Apple, Inc.",
        "D0C637": "Apple, Inc.",
        "D89695": "Apple, Inc.",
        "DC2B61": "Apple, Inc.",
        "E0B52D": "Apple, Inc.",
        "E0F847": "Apple, Inc.",
        "E48B7F": "Apple, Inc.",
        "E498D6": "Apple, Inc.",
        "E4E0C5": "Apple, Inc.",
        "E8040B": "Apple, Inc.",
        "F0B479": "Apple, Inc.",
        "F431C3": "Apple, Inc.",
        "F437B7": "Apple, Inc.",
        "F45C89": "Apple, Inc.",
        "F4F951": "Apple, Inc.",
        "F80377": "Apple, Inc.",
        "FCC2DE": "Apple, Inc.",
        "B827EB": "Raspberry Pi Foundation",
        "D83ADD": "Raspberry Pi Trading Ltd",
        "DCA632": "Raspberry Pi Trading Ltd",
        "E45F01": "Raspberry Pi Trading Ltd",
        "288088": "Raspberry Pi Trading Ltd",
        "E42F37": "ASUSTek COMPUTER INC.",
        "04D4C4": "ASUSTek COMPUTER INC.",
        "2C4D54": "ASUSTek COMPUTER INC.",
        "AC9E17": "ASUSTek COMPUTER INC.",
        "E4B323": "Espressif Inc.",
        "3C61DA": "Espressif Inc.",
        "C4DEE2": "Espressif Inc.",
        "A4CF12": "Espressif Inc.",
        "240AC4": "Espressif Inc.",
        "842F75": "IKEA of Sweden AB",
        "004E35": "Amazon Technologies Inc.",
        "FCA667": "Amazon Technologies Inc.",
        "0C47C9": "Amazon Technologies Inc.",
        "68A40E": "Amazon Technologies Inc.",
        "DC44B6": "Samsung Electronics Co.,Ltd",
        "1C1448": "ARRIS Group, Inc.",
        "001A11": "Google, Inc.",
        "F4BD9E": "Cisco Systems, Inc",
        "00E04C": "Realtek Semiconductor Corp.",
        "001C42": "Parallels, Inc.",
        "080027": "Oracle Corporation",
        "525400": "QEMU Virtual NIC",
        "00163E": "Xensource, Inc.",
        "00155D": "Microsoft Corporation"
    ]
    
    static let defaultPorts: Set<Int> = [21, 22, 80, 443]
    static let fullScanPorts: [Int] = [20, 21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 5900, 6053, 8123]
    
    /// Ports probed during host discovery (any open → host considered reachable).
    static let discoveryPorts: [Int] = [
        80, 443, 22, 445, 8080, 139, 23, 3389, 21, 8443, 5900, 631, 53, 1883, 6053, 8123
    ]
    
    /// Minimal TCP set for „Schnell“ discovery.
    static let fastDiscoveryPorts: [Int] = [80, 443, 22]
    
    /// Parallel ports probed first; dead hosts stop after this wave.
    static let discoveryWaveSize: Int = 4
    
    /// Cap concurrent TCP connects per host (avoids iOS NECP / flow limits).
    static let portScanBatchSize: Int = 6
    
    #if os(iOS) || os(visionOS)
    static let discoveryTimeoutFast: TimeInterval = 0.12
    static let discoveryTimeoutNormal: TimeInterval = 0.18
    static let discoveryTimeoutRetry: TimeInterval = 0.35
    static let phase1HostConcurrencyFast: Int = 24
    static let phase1HostConcurrencyNormal: Int = 20
    static let fillPortsTimeout: TimeInterval = 0.22
    static let phase2PortTimeout: TimeInterval = 0.2
    /// iOS needs longer Bonjour + PTR windows than macOS.
    static let bonjourBrowseTimeout: TimeInterval = 6.0
    static let dnsLookupTimeout: TimeInterval = 1.5
    static let mdnsLookupTimeout: TimeInterval = 1.8
    static let netbiosLookupTimeout: TimeInterval = 0.7
    static let nameResolveConcurrency: Int = 5
    #else
    static let discoveryTimeoutFast: TimeInterval = 0.15
    static let discoveryTimeoutNormal: TimeInterval = 0.25
    static let discoveryTimeoutRetry: TimeInterval = 0.5
    static let phase1HostConcurrencyFast: Int = 16
    static let phase1HostConcurrencyNormal: Int = 12
    static let fillPortsTimeout: TimeInterval = 0.35
    static let phase2PortTimeout: TimeInterval = 0.22
    static let bonjourBrowseTimeout: TimeInterval = 3.5
    static let dnsLookupTimeout: TimeInterval = 0.8
    static let mdnsLookupTimeout: TimeInterval = 1.0
    static let netbiosLookupTimeout: TimeInterval = 0.45
    static let nameResolveConcurrency: Int = 8
    #endif
    
    /// Background prefetch — reused on the next user scan within this window.
    static let prefetchMaxAge: TimeInterval = 300
    static let prefetchPingTimeout: TimeInterval = 2.0
    static let prefetchBonjourTimeout: TimeInterval = 4.0
    static let prefetchSSDTimeout: TimeInterval = 2.5
    static let prefetchGatewayTimeout: TimeInterval = 1.5
    static let prefetchPortTimeout: TimeInterval = 0.15
    static let prefetchNetbiosTimeout: TimeInterval = 0.25
    static let prefetchHostConcurrency: Int = 12
    
    static let icmpTimeout: TimeInterval = 2.5
    static let icmpRetryTimeout: TimeInterval = 3.5
    static let icmpPacingNanoseconds: UInt64 = 5_000_000
    
    /// Legacy alias — normal discovery timeout.
    static let discoveryTimeout: TimeInterval = discoveryTimeoutNormal
    
    /// One openable service on a host (browser, SSH, share, remote desktop, …).
    struct ServiceOpenAction: Identifiable, Hashable, Sendable {
        let title: String
        let urlString: String
        let systemImage: String
        let priority: Int
        
        var id: String { urlString }
        var url: URL? { URL(string: urlString) }
    }
    
    static func openActions(
        ip: String,
        openPorts: [Int],
        advertisedServices: [String] = []
    ) -> [ServiceOpenAction] {
        var byURL: [String: ServiceOpenAction] = [:]
        func consider(_ action: ServiceOpenAction?) {
            guard let action else { return }
            if let existing = byURL[action.urlString], existing.priority >= action.priority {
                return
            }
            byURL[action.urlString] = action
        }
        
        for port in openPorts {
            consider(openAction(ip: ip, port: port))
        }
        for service in advertisedServices {
            let normalized = normalizeBonjourType(service)
            guard let port = bonjourOpenPorts[normalized] else { continue }
            consider(openAction(ip: ip, port: port))
        }
        return byURL.values.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.title < rhs.title
        }
    }
    
    static func primaryOpenAction(
        ip: String,
        openPorts: [Int],
        advertisedServices: [String] = []
    ) -> ServiceOpenAction? {
        openActions(ip: ip, openPorts: openPorts, advertisedServices: advertisedServices).first
    }
    
    static func openAction(ip: String, port: Int) -> ServiceOpenAction? {
        guard let spec = openPortSpecs.first(where: { $0.ports.contains(port) }) else { return nil }
        let url = serviceURL(ip: ip, scheme: spec.scheme, port: port, defaultPort: spec.defaultPort)
        let title = "\(spec.label):\(port))"
        return ServiceOpenAction(
            title: title,
            urlString: url,
            systemImage: spec.systemImage,
            priority: spec.priorityByPort[port] ?? spec.priority
        )
    }
    
    static func normalizeBonjourType(_ raw: String) -> String {
        var value = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix(".local.") { value.removeLast(".local.".count) }
        else if value.hasSuffix(".local") { value.removeLast(".local".count) }
        while value.hasSuffix(".") { value.removeLast() }
        return value
    }
    
    private struct OpenPortSpec {
        let ports: Set<Int>
        let scheme: String
        let label: String
        let systemImage: String
        let defaultPort: Int
        let priority: Int
        let priorityByPort: [Int: Int]
    }
    
    private static let openPortSpecs: [OpenPortSpec] = [
        OpenPortSpec(
            ports: [80, 8080, 8000],
            scheme: "http",
            label: "Webseite (HTTP ",
            systemImage: "safari",
            defaultPort: 80,
            priority: 70,
            priorityByPort: [80: 90, 8080: 80, 8000: 75]
        ),
        OpenPortSpec(
            ports: [443, 8443],
            scheme: "https",
            label: "Webseite (HTTPS ",
            systemImage: "lock.shield",
            defaultPort: 443,
            priority: 85,
            priorityByPort: [443: 100, 8443: 85]
        ),
        OpenPortSpec(
            ports: [22],
            scheme: "ssh",
            label: "SSH (",
            systemImage: "terminal",
            defaultPort: 22,
            priority: 70,
            priorityByPort: [22: 70]
        ),
        OpenPortSpec(
            ports: [445],
            scheme: "smb",
            label: "Freigabe (SMB ",
            systemImage: "folder",
            defaultPort: 445,
            priority: 60,
            priorityByPort: [445: 60]
        ),
        OpenPortSpec(
            ports: [548],
            scheme: "afp",
            label: "Freigabe (AFP ",
            systemImage: "folder",
            defaultPort: 548,
            priority: 55,
            priorityByPort: [548: 55]
        ),
        OpenPortSpec(
            ports: [5900],
            scheme: "vnc",
            label: "Bildschirm (VNC ",
            systemImage: "rectangle.on.rectangle",
            defaultPort: 5900,
            priority: 50,
            priorityByPort: [5900: 50]
        ),
        OpenPortSpec(
            ports: [3389],
            scheme: "rdp",
            label: "Remote Desktop (",
            systemImage: "display",
            defaultPort: 3389,
            priority: 40,
            priorityByPort: [3389: 40]
        ),
        OpenPortSpec(
            ports: [21],
            scheme: "ftp",
            label: "FTP (",
            systemImage: "arrow.up.arrow.down",
            defaultPort: 21,
            priority: 30,
            priorityByPort: [21: 30]
        )
    ]
    
    /// Bonjour service type → default port. The port then uses the same scheme map.
    private static let bonjourOpenPorts: [String: Int] = [
        "_http._tcp": 80,
        "_https._tcp": 443,
        "_ssh._tcp": 22,
        "_sftp-ssh._tcp": 22,
        "_smb._tcp": 445,
        "_afpovertcp._tcp": 548,
        "_rfb._tcp": 5900,
        "_ftp._tcp": 21
    ]
    
    private static func serviceURL(ip: String, scheme: String, port: Int, defaultPort: Int) -> String {
        if scheme == "rdp" {
            if port == defaultPort {
                return "rdp://full%20address=s:\(ip)"
            }
            return "rdp://full%20address=s:\(ip):\(port)"
        }
        if port == defaultPort {
            return "\(scheme)://\(ip)"
        }
        return "\(scheme)://\(ip):\(port)"
    }
} 