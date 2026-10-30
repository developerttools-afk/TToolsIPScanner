import Foundation
import Darwin

/// Minimal SNMP v1 GET helpers (UDP/161, community `public`).
enum SNMPProbe {
    static func sysDescr(ip: String, timeout: TimeInterval = 0.8) async -> String? {
        await get(ip: ip, oid: sysDescrOID, timeout: timeout)
    }
    
    static func sysName(ip: String, timeout: TimeInterval = 0.8) async -> String? {
        await get(ip: ip, oid: sysNameOID, timeout: timeout)
    }
    
    private static func get(ip: String, oid: [UInt8], timeout: TimeInterval) async -> String? {
        await Task.detached(priority: .utility) {
            probeBlocking(ip: ip, oid: oid, timeout: timeout)
        }.value
    }
    
    private static func probeBlocking(ip: String, oid: [UInt8], timeout: TimeInterval) -> String? {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return nil }
        defer { Darwin.close(sock) }
        
        var tv = SocketTimeout.makeTimeval(from: timeout)
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(161).bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return nil }
        
        let packet = buildGet(oid: oid)
        let sent = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.sendto(sock, raw.baseAddress, packet.count, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var buf = [UInt8](repeating: 0, count: 512)
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let n = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &addrLen)
            }
        }
        guard n > 0 else { return nil }
        return parseOctetString(bytes: buf, length: n)
    }
    
    /// OID 1.3.6.1.2.1.1.1.0 — sysDescr
    private static let sysDescrOID: [UInt8] = [0x2B, 0x06, 0x01, 0x02, 0x01, 0x01, 0x01, 0x00]
    /// OID 1.3.6.1.2.1.1.5.0 — sysName
    private static let sysNameOID: [UInt8] = [0x2B, 0x06, 0x01, 0x02, 0x01, 0x01, 0x05, 0x00]
    
    private static func buildGet(oid: [UInt8]) -> [UInt8] {
        let oidLen = UInt8(oid.count)
        let varbindInner: [UInt8] = [0x06, oidLen] + oid + [0x05, 0x00]
        let varbind: [UInt8] = [0x30, UInt8(varbindInner.count)] + varbindInner
        let varbindList: [UInt8] = [0x30, UInt8(varbind.count)] + varbind
        let pduBody: [UInt8] =
            [0x02, 0x01, 0x01]
            + [0x02, 0x01, 0x00]
            + [0x02, 0x01, 0x00]
            + varbindList
        let pdu: [UInt8] = [0xA0, UInt8(pduBody.count)] + pduBody
        let community: [UInt8] = [0x04, 0x06, 0x70, 0x75, 0x62, 0x6C, 0x69, 0x63]
        let body: [UInt8] = [0x02, 0x01, 0x00] + community + pdu
        return [0x30, UInt8(body.count)] + body
    }
    
    private static func parseOctetString(bytes: [UInt8], length: Int) -> String? {
        guard length > 20 else { return nil }
        for i in stride(from: length - 2, through: 10, by: -1) where bytes[i] == 0x04 {
            let len = Int(bytes[i + 1])
            let start = i + 2
            guard len > 0, start + len <= length else { continue }
            let slice = bytes[start..<(start + len)]
            if let text = String(bytes: slice, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return String(text.prefix(120))
            }
        }
        return nil
    }
    
    /// Walk `ipNetToMediaPhysAddress` (1.3.6.1.2.1.4.22.1.2) on the gateway only.
    static func arpTable(
        gateway: String,
        community: String = "public",
        timeout: TimeInterval = 1.2
    ) async -> [String: String] {
        let cleaned = sanitizeCommunity(community)
        return await Task.detached(priority: .utility) {
            walkARP(gateway: gateway, community: cleaned, timeout: timeout)
        }.value
    }
    
    static func hostFromPhysAddress(oid: [UInt64], value: [UInt8]) -> (ip: String, mac: String)? {
        let base: [UInt64] = [1, 3, 6, 1, 2, 1, 4, 22, 1, 2]
        guard oid.count >= base.count + 5, oid.starts(with: base) else { return nil }
        let ipParts = oid.suffix(4)
        guard ipParts.allSatisfy({ $0 <= 255 }) else { return nil }
        let ip = ipParts.map(String.init).joined(separator: ".")
        guard let mac = MACAddress.format(value) else { return nil }
        return (ip, mac)
    }
    
    private static let arpColumn: [UInt64] = [1, 3, 6, 1, 2, 1, 4, 22, 1, 2]
    
    private static func sanitizeCommunity(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let ascii = trimmed.filter { $0.isASCII && !$0.isNewline }
        if ascii.isEmpty || ascii.count > 32 { return "public" }
        return ascii
    }
    
    private static func walkARP(gateway: String, community: String, timeout: TimeInterval) -> [String: String] {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return [:] }
        defer { Darwin.close(sock) }
        
        var tv = SocketTimeout.makeTimeval(from: min(timeout, 0.45))
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(161).bigEndian
        guard inet_pton(AF_INET, gateway, &addr.sin_addr) == 1 else { return [:] }
        
        var nextOID = arpColumn
        var result: [String: String] = [:]
        let deadline = Date().addingTimeInterval(timeout)
        var requestID = 1
        
        while Date() < deadline && result.count < 256 {
            let packet = SNMPBER.getNext(community: community, requestID: requestID, oid: nextOID)
            requestID += 1
            let sent = packet.withUnsafeBytes { raw in
                withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                        Darwin.sendto(sock, raw.baseAddress, packet.count, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            guard sent > 0 else { break }
            
            var buf = [UInt8](repeating: 0, count: 1500)
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &addrLen)
                }
            }
            guard n > 0, let parsed = SNMPBER.parseGetResponse(Array(buf.prefix(n))) else { break }
            if parsed.error != 0 || !parsed.oid.starts(with: arpColumn) || parsed.oid.count <= arpColumn.count {
                break
            }
            if let host = hostFromPhysAddress(oid: parsed.oid, value: parsed.value) {
                result[host.ip] = host.mac
            }
            nextOID = parsed.oid
        }
        return result
    }
}

enum SNMPBER {
    static func getNext(community: String, requestID: Int, oid: [UInt64]) -> [UInt8] {
        let varbind = tlv(0x30, oidTLV(oid) + [0x05, 0x00])
        let list = tlv(0x30, varbind)
        let body = integer(requestID) + integer(0) + integer(0) + list
        let pdu = tlv(0xA1, body)
        let communityBytes = Array(community.utf8)
        return tlv(0x30, integer(0) + tlv(0x04, communityBytes) + pdu)
    }
    
    static func parseGetResponse(_ bytes: [UInt8]) -> (error: Int, oid: [UInt64], value: [UInt8])? {
        var cursor = Cursor(bytes)
        guard let message = cursor.readTLV(), message.tag == 0x30 else { return nil }
        var body = Cursor(message.payload)
        guard body.readTLV()?.tag == 0x02, body.readTLV()?.tag == 0x04 else { return nil }
        guard let pdu = body.readTLV(), pdu.tag == 0xA2 else { return nil }
        var pduCursor = Cursor(pdu.payload)
        _ = pduCursor.readTLV()
        guard let errorTLV = pduCursor.readTLV(), errorTLV.tag == 0x02 else { return nil }
        let error = integerValue(errorTLV.payload)
        _ = pduCursor.readTLV()
        guard let list = pduCursor.readTLV(), list.tag == 0x30 else { return nil }
        var listCursor = Cursor(list.payload)
        guard let varbind = listCursor.readTLV(), varbind.tag == 0x30 else { return nil }
        var bindCursor = Cursor(varbind.payload)
        guard let oidTLV = bindCursor.readTLV(), oidTLV.tag == 0x06,
              let valueTLV = bindCursor.readTLV() else { return nil }
        let value = valueTLV.tag == 0x04 ? valueTLV.payload : []
        return (error, decodeOID(oidTLV.payload), value)
    }
    
    private static func oidTLV(_ components: [UInt64]) -> [UInt8] {
        guard components.count >= 2 else { return tlv(0x06, []) }
        var payload: [UInt8] = [UInt8(components[0] * 40 + components[1])]
        for component in components.dropFirst(2) {
            payload.append(contentsOf: base128(component))
        }
        return tlv(0x06, payload)
    }
    
    private static func decodeOID(_ bytes: [UInt8]) -> [UInt64] {
        guard let first = bytes.first else { return [] }
        var components: [UInt64] = [UInt64(first) / 40, UInt64(first) % 40]
        var value: UInt64 = 0
        for byte in bytes.dropFirst() {
            value = (value << 7) | UInt64(byte & 0x7F)
            if byte & 0x80 == 0 {
                components.append(value)
                value = 0
            }
        }
        return components
    }
    
    private static func base128(_ value: UInt64) -> [UInt8] {
        if value < 128 { return [UInt8(value)] }
        var parts: [UInt8] = []
        var remaining = value
        parts.append(UInt8(remaining & 0x7F))
        remaining >>= 7
        while remaining > 0 {
            parts.append(UInt8(remaining & 0x7F) | 0x80)
            remaining >>= 7
        }
        return parts.reversed()
    }
    
    private static func integer(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var remaining = value
        repeat {
            bytes.insert(UInt8(remaining & 0xFF), at: 0)
            remaining >>= 8
        } while remaining > 0
        if let first = bytes.first, first & 0x80 != 0 {
            bytes.insert(0, at: 0)
        }
        return tlv(0x02, bytes)
    }
    
    private static func integerValue(_ bytes: [UInt8]) -> Int {
        var value = 0
        for byte in bytes {
            value = (value << 8) | Int(byte)
        }
        return value
    }
    
    private static func tlv(_ tag: UInt8, _ payload: [UInt8]) -> [UInt8] {
        [tag] + length(payload.count) + payload
    }
    
    private static func length(_ count: Int) -> [UInt8] {
        if count < 128 { return [UInt8(count)] }
        var rest: [UInt8] = []
        var value = count
        while value > 0 {
            rest.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(rest.count)] + rest
    }
    
    private struct Cursor {
        let bytes: [UInt8]
        var index = 0
        
        init(_ bytes: [UInt8]) { self.bytes = bytes }
        
        mutating func readTLV() -> (tag: UInt8, payload: [UInt8])? {
            guard index < bytes.count else { return nil }
            let tag = bytes[index]
            index += 1
            guard let size = readLength(), index + size <= bytes.count else { return nil }
            let payload = Array(bytes[index..<(index + size)])
            index += size
            return (tag, payload)
        }
        
        private mutating func readLength() -> Int? {
            guard index < bytes.count else { return nil }
            let first = bytes[index]
            index += 1
            if first < 128 { return Int(first) }
            let count = Int(first & 0x7F)
            guard count > 0, count <= 3, index + count <= bytes.count else { return nil }
            var size = 0
            for _ in 0..<count {
                size = (size << 8) | Int(bytes[index])
                index += 1
            }
            return size
        }
    }
}
