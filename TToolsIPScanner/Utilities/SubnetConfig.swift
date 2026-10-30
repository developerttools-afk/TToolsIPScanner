import Foundation
import Darwin

/// IPv4 subnet derived from interface address + netmask.
struct SubnetConfig: Sendable, Equatable {
    /// First three octets used with host number, e.g. `192.168.1`.
    let prefix: String
    let prefixLength: Int
    /// Host octets to scan (last byte of IPv4).
    let hostNumbers: [Int]
    /// Shown when the interface subnet is larger than we scan.
    let scanNote: String
    
    static let maxHosts = 1024
    
    var totalHosts: Int { hostNumbers.count }
    
    func ip(for host: Int) -> String { "\(prefix).\(host)" }
    
    var allIPs: [String] { hostNumbers.map { ip(for: $0) } }
    
    var hostNumberSet: Set<Int> { Set(hostNumbers) }
    
    /// True when `ip` is in this scan range (prefix + scanned host numbers).
    func contains(_ ip: String) -> Bool {
        guard ip.hasPrefix(prefix + ".") else { return false }
        guard let last = ip.split(separator: ".").last, let host = Int(last) else { return false }
        return hostNumberSet.contains(host)
    }
    
    var displayRange: String {
        guard let first = hostNumbers.first, let last = hostNumbers.last else {
            return "Keine Hosts"
        }
        var text = "\(prefix).\(first) – \(prefix).\(last)"
        text += " (/\(prefixLength))"
        if !scanNote.isEmpty {
            text += " · \(scanNote)"
        }
        return text
    }
    
    static func from(localIP: String, netmask: String?) -> SubnetConfig {
        guard let ipValue = ipv4ToUInt32(localIP) else {
            return fallback(prefix: fallbackPrefix(from: localIP))
        }
        
        let mask = netmask.flatMap { ipv4ToUInt32($0) } ?? 0xFFFF_FF00
        let prefixLen = prefixLength(from: mask)
        
        // Very large subnets: scan only the /24 slice that contains this host.
        if prefixLen < 24 {
            let note = "Subnetz /\(prefixLen) — scanne lokales /24"
            return fallback(prefix: fallbackPrefix(from: localIP), prefixLength: 24, scanNote: note)
        }
        
        let network = ipValue & mask
        let broadcast = network | ~mask
        let prefix = formatPrefix(network)
        
        let networkHost = Int(network & 0xFF)
        let broadcastHost = Int(broadcast & 0xFF)
        
        var hosts: [Int]
        switch prefixLen {
        case 31:
            hosts = [networkHost, broadcastHost]
        case 32:
            hosts = [networkHost]
        default:
            hosts = Array((networkHost + 1)..<broadcastHost)
        }
        
        var scanNote = ""
        if hosts.count > maxHosts {
            hosts = Array(hosts.prefix(maxHosts))
            scanNote = "Auf \(maxHosts) Hosts begrenzt"
        }
        
        return SubnetConfig(
            prefix: prefix,
            prefixLength: prefixLen,
            hostNumbers: hosts,
            scanNote: scanNote
        )
    }
    
    private static func fallback(
        prefix: String,
        prefixLength: Int = 24,
        scanNote: String = ""
    ) -> SubnetConfig {
        SubnetConfig(
            prefix: prefix,
            prefixLength: prefixLength,
            hostNumbers: Array(1...254),
            scanNote: scanNote
        )
    }
    
    private static func fallbackPrefix(from ip: String) -> String {
        ip.split(separator: ".").dropLast().joined(separator: ".")
    }
    
    private static func ipv4ToUInt32(_ ip: String) -> UInt32? {
        var addr = in_addr()
        guard ip.withCString({ inet_pton(AF_INET, $0, &addr) }) == 1 else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }
    
    private static func formatPrefix(_ network: UInt32) -> String {
        let b0 = (network >> 24) & 0xFF
        let b1 = (network >> 16) & 0xFF
        let b2 = (network >> 8) & 0xFF
        return "\(b0).\(b1).\(b2)"
    }
    
    private static func prefixLength(from mask: UInt32) -> Int {
        var bits = 0
        var value = mask
        while value & 0x8000_0000 != 0 {
            bits += 1
            value <<= 1
        }
        return bits
    }
}
