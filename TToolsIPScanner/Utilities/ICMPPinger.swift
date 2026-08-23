import Foundation
import Darwin

/// Unprivileged ICMP Echo (SOCK_DGRAM + IPPROTO_ICMP).
/// No special entitlements required; this is the same family Apple SimplePing uses.
enum ICMPPinger {
    private static let echoRequest: UInt8 = 8
    private static let echoReply: UInt8 = 0

    /// Ping `prefix.1` … `prefix.254` and return IPs that sent an Echo Reply.
    static func sweep(prefix: String, timeout: TimeInterval = 1.5) async -> Set<String> {
        await Task.detached(priority: .userInitiated) {
            sweepBlocking(prefix: prefix, timeout: timeout)
        }.value
    }

    private static func sweepBlocking(prefix: String, timeout: TimeInterval) -> Set<String> {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else { return [] }
        defer { Darwin.close(sock) }

        var nosig: Int32 = 1
        _ = setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))

        var rcvbuf: Int32 = 256 * 1024
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, socklen_t(MemoryLayout<Int32>.size))

        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        let identifier = UInt16(truncatingIfNeeded: getpid())

        for host in 1...254 {
            sendEcho(sock: sock, ip: "\(prefix).\(host)", identifier: identifier, sequence: UInt16(host))
        }

        var found = Set<String>()
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

            found.formUnion(drainReplies(sock: sock, identifier: identifier, prefix: prefix))
        }

        return found
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

    private static func drainReplies(sock: Int32, identifier: UInt16, prefix: String) -> Set<String> {
        var found = Set<String>()
        var buf = [UInt8](repeating: 0, count: 256)

        while true {
            var addr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &addrLen)
                }
            }

            if n < 0 {
                break
            }

            if let ip = parseEchoReply(
                bytes: buf,
                length: Int(n),
                identifier: identifier,
                source: addr,
                prefix: prefix
            ) {
                found.insert(ip)
            }
        }

        return found
    }

    private static func parseEchoReply(
        bytes: [UInt8],
        length: Int,
        identifier: UInt16,
        source: sockaddr_in,
        prefix: String
    ) -> String? {
        guard length >= 8 else { return nil }

        var offset = 0
        if bytes[0] >> 4 == 4 {
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
        return ip
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
