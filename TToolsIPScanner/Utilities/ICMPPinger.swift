import Foundation
import Darwin

struct PingSweepResult: Sendable {
    var alive: Set<String> = []
    var ttlByIP: [String: UInt8] = [:]
}

/// Unprivileged ICMP Echo (SOCK_DGRAM + IPPROTO_ICMP).
enum ICMPPinger {
    private static let echoRequest: UInt8 = 8
    private static let echoReply: UInt8 = 0
    
    /// Ping `prefix.1` … `prefix.254` (optionally a host subset) with pacing.
    static func sweep(
        prefix: String,
        hostNumbers: Set<Int>? = nil,
        timeout: TimeInterval = NetworkConstants.icmpTimeout,
        pacingNanoseconds: UInt64 = NetworkConstants.icmpPacingNanoseconds
    ) async -> PingSweepResult {
        await Task.detached(priority: .userInitiated) {
            sweepBlocking(prefix: prefix, hostNumbers: hostNumbers, timeout: timeout, pacingNanoseconds: pacingNanoseconds)
        }.value
    }
    
    private static func sweepBlocking(
        prefix: String,
        hostNumbers: Set<Int>?,
        timeout: TimeInterval,
        pacingNanoseconds: UInt64
    ) -> PingSweepResult {
        let targets = hostNumbers ?? Set(1...254)
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else { return PingSweepResult() }
        defer { Darwin.close(sock) }
        
        var nosig: Int32 = 1
        _ = setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
        
        var rcvbuf: Int32 = 256 * 1024
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, socklen_t(MemoryLayout<Int32>.size))
        
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
        
        let identifier = UInt16(truncatingIfNeeded: getpid())
        
        for host in targets.sorted() {
            sendEcho(sock: sock, ip: "\(prefix).\(host)", identifier: identifier, sequence: UInt16(host))
            if pacingNanoseconds > 0 {
                usleep(useconds_t(pacingNanoseconds / 1_000))
            }
        }
        
        // Broadcast ping — some stacks reply for active subnet hosts.
        sendEcho(sock: sock, ip: "\(prefix).255", identifier: identifier, sequence: 0xFFFE)
        
        var result = PingSweepResult()
        let deadline = Date().addingTimeInterval(timeout)
        
        while true {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }
            
            var fds = fd_set()
            __darwin_fd_set(sock, &fds)
            let seconds = Int(remaining)
            let microseconds = Int32((remaining - Double(seconds)) * 1_000_000)
            var tv = timeval(tv_sec: seconds, tv_usec: microseconds)
            
            let ready = select(sock + 1, &fds, nil, nil, &tv)
            guard ready > 0 else { break }
            
            let batch = drainReplies(sock: sock, identifier: identifier, prefix: prefix)
            for (ip, ttl) in batch {
                result.alive.insert(ip)
                if let ttl { result.ttlByIP[ip] = ttl }
            }
        }
        
        return result
    }
    
    static func osHintFromTTL(_ ttl: UInt8) -> String {
        switch ttl {
        case 1...64: return "Unix/Linux/macOS?"
        case 65...128: return "Windows?"
        case 129...255: return "Netzwerkgerät?"
        default: return ""
        }
    }
    
    private static func sendEcho(sock: Int32, ip: String, identifier: UInt16, sequence: UInt16) {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return }
        
        var packet = [UInt8](repeating: 0, count: 16)
        packet[0] = echoRequest
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xff)
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xff)
        let csum = internetChecksum(packet)
        packet[2] = UInt8(csum >> 8)
        packet[3] = UInt8(csum & 0xff)
        
        _ = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.sendto(
                        sock,
                        raw.baseAddress,
                        packet.count,
                        0,
                        sockAddr,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }
    }
    
    private static func drainReplies(
        sock: Int32,
        identifier: UInt16,
        prefix: String
    ) -> [(String, UInt8?)] {
        var replies: [(String, UInt8?)] = []
        var buf = [UInt8](repeating: 0, count: 256)
        
        while true {
            var addr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &addrLen)
                }
            }
            
            if n < 0 { break }
            
            if let parsed = parseEchoReply(
                bytes: buf,
                length: Int(n),
                identifier: identifier,
                source: addr,
                prefix: prefix
            ) {
                replies.append(parsed)
            }
        }
        
        return replies
    }
    
    private static func parseEchoReply(
        bytes: [UInt8],
        length: Int,
        identifier: UInt16,
        source: sockaddr_in,
        prefix: String
    ) -> (String, UInt8?)? {
        guard length >= 8 else { return nil }
        
        var offset = 0
        var ttl: UInt8?
        if bytes[0] >> 4 == 4, length >= 20 {
            ttl = bytes[8]
            offset = Int(bytes[0] & 0x0f) * 4
        }
        guard length >= offset + 8, bytes[offset] == echoReply else { return nil }
        
        let id = UInt16(bytes[offset + 4]) << 8 | UInt16(bytes[offset + 5])
        guard id == identifier else { return nil }
        
        var addr = source.sin_addr
        var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &addr, &ipBuf, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
        let ip = String(cString: ipBuf)
        guard ip.hasPrefix(prefix + ".") else { return nil }
        return (ip, ttl)
    }
    
    private static func internetChecksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i + 1 < bytes.count {
            sum += UInt32(bytes[i]) << 8 | UInt32(bytes[i + 1])
            i += 2
        }
        if i < bytes.count {
            sum += UInt32(bytes[i]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xffff) + (sum >> 16)
        }
        return ~UInt16(truncatingIfNeeded: sum)
    }
}
