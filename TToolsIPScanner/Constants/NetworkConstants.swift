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
        8080: "HTTP Alternate",
        8443: "HTTPS Alternate",
        1883: "MQTT",
        8883: "MQTT over SSL"
    ]
    
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
    static let fullScanPorts: [Int] = [20, 21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 5900]
    
    /// Ports probed during host discovery (any open → host considered reachable).
    /// Ordered by likelihood - most common ports first for faster discovery
    static let discoveryPorts: [Int] = [
        80,           // HTTP (most common)
        443,          // HTTPS
        22,           // SSH
        445,          // SMB (Windows/NAS)
        8080,         // Alt HTTP
        139,          // NetBIOS
        23,           // Telnet
        3389,         // RDP
        21,           // FTP
        8443,         // Alt HTTPS
        5900,         // VNC
        631,          // Drucker
        53,           // DNS
        1883          // MQTT
    ]
    /// Unified timeout for both platforms
    /// 0.2s balances speed (11 ports × 0.2s = 2.2s per dead host)
    /// vs reliability (LAN RTT + TCP handshake)
    static let discoveryTimeout: TimeInterval = 0.2
} 