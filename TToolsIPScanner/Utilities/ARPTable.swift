import Foundation

#if os(macOS) || os(iOS)
import Darwin

/// Kernel ARP table via sysctl.
/// macOS 27 and iOS 27 hide these entries unless the app has
/// `com.apple.developer.networking.topology-observation`.
enum ARPTable {
    /// All IPv4 → MAC entries in `prefix.*`.
    static func entries(matchingPrefix prefix: String) -> [String: String] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [:] }
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer { buffer.deallocate() }
        guard sysctl(&mib, 6, buffer, &length, nil, 0) == 0 else { return [:] }
        
        var result: [String: String] = [:]
        var cursor = buffer
        let end = buffer.advanced(by: length)
        
        while cursor < end {
            let rtm = cursor.withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0.pointee }
            let msgLen = Int(rtm.rtm_msglen)
            guard msgLen > 0 else { break }
            
            if let (ip, mac) = parseEntry(cursor, length: msgLen),
               ip.hasPrefix(prefix + "."),
               !mac.isEmpty {
                result[ip] = mac
            }
            cursor = cursor.advanced(by: msgLen)
        }
        
        // The Mac never appears in its own ARP table.
        for (ip, mac) in localInterfaceMACs(matchingPrefix: prefix) where result[ip] == nil {
            result[ip] = mac
        }
        return result
    }
    
    static func macAddress(for ip: String) -> String? {
        let prefix = ip.split(separator: ".").dropLast().joined(separator: ".")
        return entries(matchingPrefix: prefix)[ip]
    }
    
    private static func parseEntry(
        _ base: UnsafeMutablePointer<UInt8>,
        length: Int
    ) -> (String, String)? {
        let rtm = base.withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0.pointee }
        var addrPtr = base.advanced(by: MemoryLayout<rt_msghdr>.stride)
        let end = base.advanced(by: length)
        
        var ip: String?
        var mac: String?
        var bit: Int32 = 1
        
        while bit != 0, addrPtr < end {
            defer { bit <<= 1 }
            guard (Int32(rtm.rtm_addrs) & bit) != 0 else { continue }
            
            let saLen = Int(addrPtr.pointee)
            let family = Int32(addrPtr.advanced(by: 1).pointee)
            let strideLen = RouteSocketAddress.stride(saLen: saLen)
            guard addrPtr.advanced(by: strideLen) <= end else { return nil }
            
            if bit == RTA_DST, family == AF_INET {
                let sin = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var addr = sin.sin_addr
                var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                ip = String(cString: ipBuf)
            }
            
            if bit == RTA_GATEWAY, family == AF_LINK {
                let sdl = addrPtr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                let alen = Int(sdl.sdl_alen)
                if alen == 6 {
                    let dataStart = addrPtr
                        .advanced(by: MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) ?? 8)
                    let macStart = dataStart.advanced(by: Int(sdl.sdl_nlen))
                    if macStart.advanced(by: 6) <= end {
                        let bytes = (0..<6).map { macStart.advanced(by: $0).pointee }
                        mac = MACAddress.format(bytes)
                    }
                }
            }
            
            addrPtr = addrPtr.advanced(by: strideLen)
        }
        
        guard let ip, let mac, !mac.isEmpty else { return nil }
        return (ip, mac)
    }
    
    /// AF_LINK address of each interface whose IPv4 is inside `prefix`.
    private static func localInterfaceMACs(matchingPrefix prefix: String) -> [String: String] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [:] }
        defer { freeifaddrs(first) }
        
        var macByName: [String: String] = [:]
        var addressesByName: [String: [String]] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            cursor = ptr.pointee.ifa_next
            let name = String(cString: ptr.pointee.ifa_name)
            guard let addr = ptr.pointee.ifa_addr else { continue }
            let family = Int32(addr.pointee.sa_family)
            
            if family == AF_LINK, let mac = macAddress(fromLink: addr) {
                macByName[name] = mac
            }
            if family == AF_INET {
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                let ip = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var raw = sin.pointee.sin_addr
                    guard inet_ntop(AF_INET, &raw, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return "" }
                    return String(cString: buffer)
                }
                guard ip.hasPrefix(prefix + "."), !ip.hasPrefix("127.") else { continue }
                addressesByName[name, default: []].append(ip)
            }
        }
        
        var result: [String: String] = [:]
        for (name, ips) in addressesByName {
            guard let mac = macByName[name] else { continue }
            for ip in ips {
                result[ip] = mac
            }
        }
        return result
    }
    
    private static func macAddress(fromLink addr: UnsafePointer<sockaddr>) -> String? {
        let sdl = addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
        guard sdl.sdl_alen == 6 else { return nil }
        let nameLength = Int(sdl.sdl_nlen)
        let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) ?? 8
        guard Int(sdl.sdl_len) >= dataOffset + nameLength + 6 else { return nil }
        let macStart = UnsafeRawPointer(addr).advanced(by: dataOffset + nameLength)
        let bytes = (0..<6).map { macStart.load(fromByteOffset: $0, as: UInt8.self) }
        return MACAddress.format(bytes)
    }
}

#else

/// Platforms without the route-table sysctl.
enum ARPTable {
    static func entries(matchingPrefix prefix: String) -> [String: String] { [:] }
    static func macAddress(for ip: String) -> String? { nil }
}

#endif
