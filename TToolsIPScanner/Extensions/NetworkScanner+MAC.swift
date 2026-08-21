import Foundation

#if os(macOS)
import Darwin
#endif

extension NetworkScanner {
    nonisolated internal func getMacAddress(
        for ip: String,
        openPorts: [Int] = [],
        knownHostName: String? = nil,
        ouiDB: [String: String]
    ) -> (mac: String, manufacturer: String) {
        #if os(macOS)
        // Prefer sysctl only — spawning /usr/sbin/arp under App Sandbox triggers
        // Console noise: "Unable to obtain a task name port right".
        if let mac = lookupMacFromARPTable(ip: ip) {
            let vendor = lookupManufacturer(mac: mac, ouiDB: ouiDB)
            return (mac, vendor == "Unbekannt" ? (manufacturerFromOpenPorts(openPorts) ?? vendor) : vendor)
        }
        #endif
        
        var manufacturer = manufacturerFromOpenPorts(openPorts) ?? "Unbekannt"
        
        if manufacturer == "Unbekannt" {
            let hostName = knownHostName?.lowercased()
            if let hostName {
                if hostName.contains("iphone") || hostName.contains("ipad") || hostName.contains("mac") {
                    manufacturer = "Apple, Inc."
                } else if hostName.contains("android") || hostName.contains("samsung") {
                    manufacturer = "Samsung Electronics"
                }
            }
        }
        
        // Never invent MAC addresses — alias lookup falls back to IP via DeviceInfo.aliasKey.
        return ("", manufacturer)
    }
    
    #if os(macOS)
    /// Read kernel ARP/routing table via sysctl (works under App Sandbox without subprocess).
    nonisolated private func lookupMacFromARPTable(ip: String) -> String? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer { buffer.deallocate() }
        guard sysctl(&mib, 6, buffer, &length, nil, 0) == 0 else { return nil }
        
        var cursor = buffer
        let end = buffer.advanced(by: length)
        
        while cursor < end {
            let rtm = cursor.withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0.pointee }
            let msgLen = Int(rtm.rtm_msglen)
            guard msgLen > 0 else { break }
            
            if let mac = macAddress(inRouteMessage: cursor, length: msgLen, matchingIP: ip) {
                return mac
            }
            cursor = cursor.advanced(by: msgLen)
        }
        return nil
    }
    
    nonisolated private func macAddress(inRouteMessage base: UnsafeMutablePointer<UInt8>, length: Int, matchingIP: String) -> String? {
        let rtm = base.withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0.pointee }
        var addrPtr = base.advanced(by: MemoryLayout<rt_msghdr>.stride)
        let end = base.advanced(by: length)
        
        var foundIP = false
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
                foundIP = String(cString: ipBuf) == matchingIP
            }
            
            if bit == RTA_GATEWAY, family == AF_LINK {
                let sdl = addrPtr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                let alen = Int(sdl.sdl_alen)
                if alen == 6 {
                    // sdl_data starts with interface name (nlen), then MAC (alen)
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
        
        return foundIP ? mac : nil
    }
    #endif
    
    nonisolated private func manufacturerFromOpenPorts(_ openPorts: [Int]) -> String? {
        if openPorts.contains(548) || openPorts.contains(5009) || openPorts.contains(5353) || openPorts.contains(62078) {
            return "Apple, Inc."
        }
        if openPorts.contains(137) || openPorts.contains(139) || openPorts.contains(445) {
            return "Microsoft Corporation"
        }
        if openPorts.contains(22) {
            return "Unix/Linux Device"
        }
        if openPorts.contains(1883) || openPorts.contains(8883) {
            return "IoT Device"
        }
        return nil
    }
    
    nonisolated private func lookupManufacturer(mac: String, ouiDB: [String: String]) -> String {
        let cleanMac = mac.replacingOccurrences(of: ":", with: "").uppercased()
        let oui = String(cleanMac.prefix(6))
        
        if let manufacturer = ouiDB[oui] {
            return manufacturer
        }
        if let manufacturer = NetworkConstants.additionalOUIs[oui] {
            return manufacturer
        }
        return "Unbekannt"
    }

    nonisolated internal func getManufacturerFromPortScan(openPorts: [Int]) -> String? {
        manufacturerFromOpenPorts(openPorts)
    }
}
