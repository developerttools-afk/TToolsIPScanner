import Foundation

#if os(macOS)
import Darwin

/// Kernel ARP / neighbor table via sysctl (sandbox-safe, macOS).
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
            let strideLen = max(saLen == 0 ? 4 : saLen, 4)
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
                        mac = (0..<6).map { String(format: "%02X", macStart.advanced(by: $0).pointee) }
                            .joined(separator: ":")
                    }
                }
            }
            
            addrPtr = addrPtr.advanced(by: strideLen)
        }
        
        guard let ip, let mac, !mac.isEmpty else { return nil }
        return (ip, mac)
    }
}

#else

/// iOS does not expose the route-table sysctl API used for ARP lookup.
enum ARPTable {
    static func entries(matchingPrefix prefix: String) -> [String: String] { [:] }
    static func macAddress(for ip: String) -> String? { nil }
}

#endif
