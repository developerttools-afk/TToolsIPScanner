import Foundation
import Darwin

struct IPv6Host: Sendable, Equatable {
    var address: String
    var macAddress: String
}

/// Finds IPv6 neighbors on local interfaces. A /64 is not walked address by address.
enum IPv6Discovery {
    struct Candidate: Sendable, Equatable {
        var address: String
        var macAddress: String
    }
    
    static func scan(timeout: TimeInterval = 1.6) async -> [IPv6Host] {
        await Task.detached(priority: .userInitiated) {
            scanBlocking(timeout: timeout)
        }.value
    }
    
    /// One address per host. Global beats unique-local, which beats link-local.
    static func collapse(_ candidates: [Candidate]) -> [IPv6Host] {
        struct Item {
            var address: String
            var mac: String
            var rank: Int
            var eui: Bool
        }
        
        var macByAddress: [String: String] = [:]
        for candidate in candidates {
            let key = IPv6Address.unscoped(IPv6Address.canonical(candidate.address)).lowercased()
            if let mac = MACAddress.normalize(candidate.macAddress) {
                macByAddress[key] = mac
            }
        }
        
        var groups: [String: [Item]] = [:]
        for candidate in candidates {
            let address = IPv6Address.canonical(candidate.address)
            guard let raw = IPv6Address.bytes(of: address), IPv6Address.rank(raw) > 0 else { continue }
            let iid = raw.suffix(8).map { String(format: "%02x", $0) }.joined()
            let addressKey = IPv6Address.unscoped(address).lowercased()
            let euiMAC = MACAddress.fromEUI64(interfaceID: Array(raw.suffix(8)))
            let eui = euiMAC != nil
            let mac = MACAddress.normalize(candidate.macAddress)
                ?? macByAddress[addressKey]
                ?? euiMAC
                ?? ""
            let key: String
            if !mac.isEmpty {
                key = "mac:" + mac
            } else if eui {
                key = "iid:" + iid
            } else {
                key = "addr:" + IPv6Address.unscoped(candidate.address).lowercased()
            }
            groups[key, default: []].append(Item(address: address, mac: mac, rank: IPv6Address.rank(raw), eui: eui))
        }
        
        return groups.values.compactMap { group -> IPv6Host? in
            guard let best = group.max(by: { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                if lhs.eui != rhs.eui { return !lhs.eui }
                let lhsZone = lhs.address.contains("%")
                let rhsZone = rhs.address.contains("%")
                if lhsZone != rhsZone { return !lhsZone }
                return lhs.address.count > rhs.address.count
            }) else { return nil }
            return IPv6Host(address: best.address, macAddress: best.mac)
        }
        .sorted { $0.address < $1.address }
    }
    
    private static func scanBlocking(timeout: TimeInterval) -> [IPv6Host] {
        let interfaces = localInterfaces()
        guard !interfaces.isEmpty else { return [] }
        
        let prefixes = Set(interfaces.flatMap(\.prefixes))
        var candidates: [Candidate] = []
        
        let slice = max(0.45, timeout / Double(interfaces.count))
        for interface in interfaces {
            for address in pingAllNodes(index: interface.index, timeout: slice) {
                guard accept(address, prefixes: prefixes) else { continue }
                candidates.append(Candidate(address: address, macAddress: ""))
            }
        }
        
        // Neighbor replies are written after the echo. Read the table once they settle.
        usleep(useconds_t(NetworkConstants.neighborSettleDelay * 1_000_000))
        
        for neighbor in neighborEntries() {
            guard accept(neighbor.address, prefixes: prefixes) else { continue }
            candidates.append(neighbor)
        }
        
        return collapse(candidates)
    }
    
    private struct LocalInterface {
        var name: String
        var index: UInt32
        var prefixes: Set<[UInt8]>
    }
    
    private static func localInterfaces() -> [LocalInterface] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(first) }
        
        var map: [String: LocalInterface] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            cursor = ptr.pointee.ifa_next
            guard let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET6) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard shouldScan(name) else { continue }
            if Int32(ptr.pointee.ifa_flags) & IFF_LOOPBACK != 0 { continue }
            
            let sin6 = sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
            let raw = ipv6Bytes(sin6.sin6_addr)
            guard IPv6Address.rank(raw) > 0 else { continue }
            let index = if_nametoindex(name)
            guard index != 0 else { continue }
            var entry = map[name] ?? LocalInterface(name: name, index: index, prefixes: [])
            if IPv6Address.isGlobal(raw) || IPv6Address.isULA(raw) {
                entry.prefixes.insert(Array(raw.prefix(8)))
            }
            map[name] = entry
        }
        return Array(map.values)
    }
    
    private static func shouldScan(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower == "lo0" || lower.hasPrefix("lo") { return false }
        let skipped = ["awdl", "llw", "utun", "ipsec", "gif", "stf", "pktap", "anpi", "ap"]
        return !skipped.contains { lower.hasPrefix($0) }
    }
    
    private static func accept(_ address: String, prefixes: Set<[UInt8]>) -> Bool {
        guard let raw = IPv6Address.bytes(of: address), IPv6Address.rank(raw) > 0 else { return false }
        if IPv6Address.isLinkLocal(raw) { return true }
        guard !prefixes.isEmpty else { return true }
        return prefixes.contains(Array(raw.prefix(8)))
    }
    
    private static func pingAllNodes(index: UInt32, timeout: TimeInterval) -> [String] {
        let sock = Darwin.socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        guard sock >= 0 else { return [] }
        defer { Darwin.close(sock) }
        
        var nosig: Int32 = 1
        _ = setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
        var bound = index
        _ = setsockopt(sock, IPPROTO_IPV6, IPV6_BOUND_IF, &bound, socklen_t(MemoryLayout<UInt32>.size))
        var hops: Int32 = 255
        _ = setsockopt(sock, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, &hops, socklen_t(MemoryLayout<Int32>.size))
        
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
        
        var dest = sockaddr_in6()
        dest.sin6_family = sa_family_t(AF_INET6)
        dest.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        dest.sin6_scope_id = index
        guard inet_pton(AF_INET6, "ff02::1", &dest.sin6_addr) == 1 else { return [] }
        
        let identifier = UInt16(truncatingIfNeeded: getpid())
        var packet = [UInt8](repeating: 0, count: 16)
        packet[0] = 128
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xff)
        packet[6] = UInt8((index >> 8) & 0xff)
        packet[7] = UInt8(index & 0xff)
        
        _ = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &dest) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.sendto(sock, raw.baseAddress, packet.count, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        }
        
        var found: [String] = []
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
            
            while true {
                var source = sockaddr_in6()
                var sourceLen = socklen_t(MemoryLayout<sockaddr_in6>.size)
                var buffer = [UInt8](repeating: 0, count: 128)
                let count = withUnsafeMutablePointer(to: &source) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                        Darwin.recvfrom(sock, &buffer, buffer.count, 0, sockAddr, &sourceLen)
                    }
                }
                if count < 8 { break }
                guard buffer[0] == 129 else { continue }
                let id = UInt16(buffer[4]) << 8 | UInt16(buffer[5])
                guard id == identifier else { continue }
                let raw = ipv6Bytes(source.sin6_addr)
                let name = interfaceName(source.sin6_scope_id) ?? interfaceName(index)
                if let text = IPv6Address.format(raw, scope: source.sin6_scope_id == 0 ? index : source.sin6_scope_id, interface: name) {
                    found.append(text)
                }
            }
        }
        return found
    }
    
    private static func neighborEntries() -> [Candidate] {
        #if os(macOS) || os(iOS)
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET6, NET_RT_FLAGS, RTF_LLINFO]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [] }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer { buffer.deallocate() }
        guard sysctl(&mib, 6, buffer, &length, nil, 0) == 0 else { return [] }
        
        var result: [Candidate] = []
        var cursor = buffer
        let end = buffer.advanced(by: length)
        while cursor < end {
            let header = cursor.withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0.pointee }
            let messageLength = Int(header.rtm_msglen)
            guard messageLength > 0 else { break }
            if let entry = parseNeighbor(cursor, length: messageLength) {
                result.append(entry)
            }
            cursor = cursor.advanced(by: messageLength)
        }
        return result
        #else
        return []
        #endif
    }
    
    #if os(macOS) || os(iOS)
    private static func parseNeighbor(_ base: UnsafeMutablePointer<UInt8>, length: Int) -> Candidate? {
        let header = base.withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0.pointee }
        var addrPtr = base.advanced(by: MemoryLayout<rt_msghdr>.stride)
        let end = base.advanced(by: length)
        var address: String?
        var mac = ""
        var bit: Int32 = 1
        
        while bit != 0, addrPtr < end {
            defer { bit <<= 1 }
            guard (Int32(header.rtm_addrs) & bit) != 0 else { continue }
            let saLen = Int(addrPtr.pointee)
            let family = Int32(addrPtr.advanced(by: 1).pointee)
            let stride = RouteSocketAddress.stride(saLen: saLen)
            guard addrPtr.advanced(by: stride) <= end else { return nil }
            
            if bit == RTA_DST, family == AF_INET6 {
                let sin6 = addrPtr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                let raw = ipv6Bytes(sin6.sin6_addr)
                let name = interfaceName(sin6.sin6_scope_id)
                address = IPv6Address.format(raw, scope: sin6.sin6_scope_id, interface: name)
            }
            
            if bit == RTA_GATEWAY, family == AF_LINK {
                let sdl = addrPtr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                if sdl.sdl_alen == 6 {
                    let dataStart = addrPtr.advanced(by: MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) ?? 8)
                    let macStart = dataStart.advanced(by: Int(sdl.sdl_nlen))
                    if macStart.advanced(by: 6) <= end {
                        let bytes = (0..<6).map { macStart.advanced(by: $0).pointee }
                        if let formatted = MACAddress.format(bytes) {
                            mac = formatted
                        }
                    }
                }
            }
            
            addrPtr = addrPtr.advanced(by: stride)
        }
        
        guard let address else { return nil }
        return Candidate(address: address, macAddress: mac)
    }
    #endif
    
    private static func ipv6Bytes(_ addr: in6_addr) -> [UInt8] {
        withUnsafeBytes(of: addr) { Array($0) }
    }
    
    private static func interfaceName(_ index: UInt32) -> String? {
        guard index != 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        guard if_indextoname(index, &buffer) != nil else { return nil }
        let name = String(cString: buffer)
        return name.isEmpty ? nil : name
    }
}
