import Foundation
import Darwin

struct NetBIOSNodeStatus: Sendable, Equatable {
    var name: String?
    /// Six-byte Unit ID that follows the name table. This is the NIC MAC.
    var macAddress: String?
}

/// NetBIOS Node Status Query (UDP/137) — hostname and Unit ID for Windows/Samba hosts.
enum NetBIOSQuery {
    static func lookup(for ip: String, timeout: TimeInterval = 0.6) async -> NetBIOSNodeStatus {
        await Task.detached(priority: .utility) {
            lookupBlocking(ip: ip, timeout: timeout)
        }.value
    }
    
    static func lookupName(for ip: String, timeout: TimeInterval = 0.6) async -> String? {
        await lookup(for: ip, timeout: timeout).name
    }
    
    private static func lookupBlocking(ip: String, timeout: TimeInterval) -> NetBIOSNodeStatus {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return NetBIOSNodeStatus() }
        defer { Darwin.close(sock) }
        
        // Sub-second timeouts must set tv_usec — Int(0.2) == 0 would mean "wait forever".
        var tv = SocketTimeout.makeTimeval(from: timeout)
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(137).bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return NetBIOSNodeStatus() }
        
        // Minimal NBSTAT query (transaction id 0x1234, flags 0x0010)
        let query: [UInt8] = [
            0x12, 0x34, 0x01, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x20, 0x43, 0x4B, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x00, 0x00, 0x21, 0x00, 0x01
        ]
        
        let sent = query.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.sendto(sock, raw.baseAddress, query.count, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return NetBIOSNodeStatus() }
        
        var buf = [UInt8](repeating: 0, count: 1024)
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let n = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &addrLen)
            }
        }
        guard n > 56 else { return NetBIOSNodeStatus() }
        
        return parseNodeStatus(bytes: buf, length: n)
    }
    
    /// Prefer the DNS resource-record walk (Unit ID sits after the name table).
    /// Fall back to the historical fixed offset when that walk finds no name.
    static func parseNodeStatus(bytes: [UInt8], length: Int) -> NetBIOSNodeStatus {
        let modern = parseStructured(bytes: bytes, length: length)
        let legacyName = parseLegacyName(bytes: bytes, length: length)
        if modern.macAddress != nil || isPlausibleName(modern.name) {
            return NetBIOSNodeStatus(
                name: isPlausibleName(modern.name) ? modern.name : legacyName,
                macAddress: modern.macAddress
            )
        }
        return NetBIOSNodeStatus(name: legacyName, macAddress: nil)
    }
    
    private static func parseStructured(bytes: [UInt8], length: Int) -> NetBIOSNodeStatus {
        guard length >= 12 else { return NetBIOSNodeStatus() }
        let questions = Int(bytes[4]) << 8 | Int(bytes[5])
        let answers = Int(bytes[6]) << 8 | Int(bytes[7])
        guard questions <= 4, answers >= 1, answers <= 4 else { return NetBIOSNodeStatus() }
        
        var index = 12
        for _ in 0..<questions {
            guard skipDNSName(bytes: bytes, length: length, index: &index) else { return NetBIOSNodeStatus() }
            guard index + 4 <= length else { return NetBIOSNodeStatus() }
            index += 4
        }
        guard skipDNSName(bytes: bytes, length: length, index: &index) else { return NetBIOSNodeStatus() }
        guard index + 10 <= length else { return NetBIOSNodeStatus() }
        index += 8
        let recordLength = Int(bytes[index]) << 8 | Int(bytes[index + 1])
        index += 2
        guard recordLength >= 1, index + recordLength <= length else { return NetBIOSNodeStatus() }
        let recordEnd = index + recordLength
        
        let nameCount = Int(bytes[index])
        index += 1
        guard nameCount > 0, nameCount <= 32 else { return NetBIOSNodeStatus() }
        
        var name: String?
        for _ in 0..<nameCount {
            guard index + 18 <= recordEnd else { return NetBIOSNodeStatus(name: name, macAddress: nil) }
            let flags = bytes[index + 16]
            if name == nil, (flags & 0x80) == 0 {
                let raw = String(bytes: bytes[index..<(index + 15)], encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces)
                if isPlausibleName(raw) { name = raw }
            }
            index += 18
        }
        
        var mac: String?
        if index + 6 <= recordEnd {
            mac = MACAddress.format(bytes[index..<(index + 6)])
        }
        return NetBIOSNodeStatus(name: name, macAddress: mac)
    }
    
    /// Older replies observed with the name count at byte 57.
    private static func parseLegacyName(bytes: [UInt8], length: Int) -> String? {
        guard length > 57 else { return nil }
        let nameCount = Int(bytes[57])
        guard nameCount > 0, nameCount <= 32, length >= 58 + nameCount * 18 else { return nil }
        
        var offset = 58
        for _ in 0..<nameCount {
            guard offset + 18 <= length else { break }
            let flags = bytes[offset + 16]
            let name = String(bytes: bytes[offset..<(offset + 15)], encoding: .ascii)?
                .trimmingCharacters(in: .whitespaces)
            if (flags & 0x80) == 0, isPlausibleName(name) {
                return name
            }
            offset += 18
        }
        return nil
    }
    
    private static func isPlausibleName(_ name: String?) -> Bool {
        guard let name, (1...15).contains(name.count) else { return false }
        let letters = name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == " " }
        return letters.count >= 2 && letters.count == name.count
    }
    
    private static func skipDNSName(bytes: [UInt8], length: Int, index: inout Int) -> Bool {
        var cursor = index
        var steps = 0
        while steps < 16 {
            guard cursor < length else { return false }
            let label = Int(bytes[cursor])
            if label == 0 {
                index = cursor + 1
                return true
            }
            if label & 0xC0 == 0xC0 {
                guard cursor + 1 < length else { return false }
                index = cursor + 2
                return true
            }
            guard label & 0xC0 == 0 else { return false }
            let next = cursor + 1 + label
            guard next <= length else { return false }
            cursor = next
            index = cursor
            steps += 1
        }
        return false
    }
}
