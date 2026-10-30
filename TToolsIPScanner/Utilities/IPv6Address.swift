import Foundation
import Darwin

/// Parsing and ranking for IPv6 literals, including an optional zone (`%en0`).
enum IPv6Address {
    static func isIPv6(_ text: String) -> Bool {
        bytes(of: text) != nil
    }
    
    /// Usable host address: global, unique-local, or link-local. Not multicast or loopback.
    static func isHostAddress(_ text: String) -> Bool {
        guard let raw = bytes(of: text) else { return false }
        return rank(raw) > 0
    }
    
    static func bytes(of text: String) -> [UInt8]? {
        let host = unscoped(text)
        var addr = in6_addr()
        guard host.withCString({ inet_pton(AF_INET6, $0, &addr) }) == 1 else { return nil }
        return withUnsafeBytes(of: addr) { Array($0) }
    }
    
    static func format(_ bytes: [UInt8], scope: UInt32 = 0, interface: String? = nil) -> String? {
        guard bytes.count == 16 else { return nil }
        let stripped = strippingEmbeddedScope(bytes)
        let zone = scope != 0 ? scope : stripped.scope
        var addr = in6_addr()
        withUnsafeMutableBytes(of: &addr) { raw in
            for (index, byte) in stripped.address.enumerated() where index < raw.count {
                raw[index] = byte
            }
        }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else { return nil }
        var text = String(cString: buffer)
        guard zone != 0, isLinkLocal(stripped.address) else { return text }
        if let interface, !interface.isEmpty {
            text += "%\(interface)"
        } else if let name = interfaceName(zone) {
            text += "%\(name)"
        }
        return text
    }
    
    /// Same host, whether the kernel left the zone in bytes 2–3 or wrote `%en0`.
    static func canonical(_ text: String) -> String {
        guard let raw = bytes(of: text) else { return text }
        let zone = text.split(separator: "%", maxSplits: 1).dropFirst().first.map(String.init)
        let explicit: UInt32
        if let zone, let numeric = UInt32(zone) {
            explicit = numeric
        } else if let zone {
            explicit = if_nametoindex(zone)
        } else {
            explicit = 0
        }
        return format(raw, scope: explicit, interface: zone) ?? text
    }
    
    /// Kernel sockaddrs store the interface index in bytes 2–3 of a link-local address.
    private static func strippingEmbeddedScope(_ bytes: [UInt8]) -> (address: [UInt8], scope: UInt32) {
        guard isLinkLocal(bytes) else { return (bytes, 0) }
        let scope = (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        guard scope != 0 else { return (bytes, 0) }
        var copy = bytes
        copy[2] = 0
        copy[3] = 0
        return (copy, scope)
    }
    
    static func socketAddress(_ text: String, port: Int) -> sockaddr_in6? {
        let parts = text.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)
        let host = String(parts[0])
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        addr.sin6_port = UInt16(clamping: port).bigEndian
        guard host.withCString({ inet_pton(AF_INET6, $0, &addr.sin6_addr) }) == 1 else { return nil }
        if parts.count == 2 {
            let zone = String(parts[1])
            if let numeric = UInt32(zone) {
                addr.sin6_scope_id = numeric
            } else {
                addr.sin6_scope_id = if_nametoindex(zone)
            }
        }
        return addr
    }
    
    static func unscoped(_ text: String) -> String {
        String(text.split(separator: "%", maxSplits: 1).first ?? Substring(text))
    }
    
    /// Higher is better to show: global, then unique-local, then link-local.
    static func rank(_ bytes: [UInt8]) -> Int {
        if isGlobal(bytes) { return 3 }
        if isULA(bytes) { return 2 }
        if isLinkLocal(bytes) { return 1 }
        return 0
    }
    
    static func isGlobal(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return false }
        return bytes[0] & 0xE0 == 0x20
    }
    
    static func isULA(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return false }
        return bytes[0] & 0xFE == 0xFC
    }
    
    static func isLinkLocal(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return false }
        return bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80
    }
    
    static func preferred(_ current: String, _ proposed: String) -> String {
        guard !proposed.isEmpty else { return current }
        guard !current.isEmpty else { return proposed }
        let currentRank = bytes(of: current).map(rank) ?? 0
        let proposedRank = bytes(of: proposed).map(rank) ?? 0
        if proposedRank != currentRank {
            return proposedRank > currentRank ? proposed : current
        }
        return proposed.count < current.count ? proposed : current
    }
    
    /// Bracket form for URLs. A zone marker is percent-encoded.
    static func hostLiteral(_ ip: String) -> String {
        guard isIPv6(ip) else { return ip }
        let escaped = ip.replacingOccurrences(of: "%", with: "%25")
        return "[\(escaped)]"
    }
    
    private static func interfaceName(_ index: UInt32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        guard if_indextoname(index, &buffer) != nil else { return nil }
        let name = String(cString: buffer)
        return name.isEmpty ? nil : name
    }
}
