import Foundation
import Network
import SystemConfiguration

extension NetworkScanner {
    struct InterfaceAddress: Sendable {
        let ip: String
        let netmask: String?
    }
    
    nonisolated func getCurrentNetwork() -> String? {
        getInterfaceAddress()?.ip
    }
    
    nonisolated func getInterfaceAddress() -> InterfaceAddress? {
        final class AddressBox: @unchecked Sendable {
            var value: InterfaceAddress?
            let lock = NSLock()
            
            func set(_ newValue: InterfaceAddress?) {
                lock.lock()
                defer { lock.unlock() }
                value = newValue
            }
            
            func get() -> InterfaceAddress? {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
        }
        
        let addressBox = AddressBox()
        let monitor = NWPathMonitor()
        let group = DispatchGroup()
        group.enter()
        
        monitor.pathUpdateHandler = { path in
            defer {
                group.leave()
                monitor.cancel()
            }
            guard path.status == .satisfied else { return }
            
            // Prefer Wi‑Fi, then wired — never use cellular for LAN scanning.
            let preferred =
                path.availableInterfaces.first(where: { $0.type == .wifi })
                ?? path.availableInterfaces.first(where: { $0.type == .wiredEthernet })
            
            if let preferred {
                addressBox.set(self.getInterfaceAddress(forInterfaceNamed: preferred.name))
            } else {
                addressBox.set(self.getInterfaceAddress(forInterfaceNamed: nil, excludingCellularLike: true))
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
        _ = group.wait(timeout: .now() + 1.0)
        
        return addressBox.get()
    }
    
    /// Resolves IPv4 + netmask for a named interface (e.g. `en0`).
    nonisolated private func getInterfaceAddress(forInterfaceNamed name: String?, excludingCellularLike: Bool = false) -> InterfaceAddress? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var fallback: InterfaceAddress?
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            
            let ifName = String(cString: current.pointee.ifa_name)
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                addr,
                socklen_t(MemoryLayout<sockaddr_in>.size),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard status == 0 else { continue }
            
            let address = String(cString: hostname)
            guard !address.hasPrefix("127.") else { continue }
            
            var netmaskString: String?
            if let maskAddr = current.pointee.ifa_netmask,
               maskAddr.pointee.sa_family == UInt8(AF_INET) {
                var maskBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    maskAddr,
                    socklen_t(MemoryLayout<sockaddr_in>.size),
                    &maskBuf,
                    socklen_t(maskBuf.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    netmaskString = String(cString: maskBuf)
                }
            }
            
            let entry = InterfaceAddress(ip: address, netmask: netmaskString)
            
            if let name, ifName == name {
                return entry
            }
            
            if excludingCellularLike || name == nil {
                if ifName.hasPrefix("pdp_ip") || ifName.hasPrefix("utun") {
                    continue
                }
                if fallback == nil {
                    fallback = entry
                }
            }
        }
        
        return fallback
    }
    
    /// Legacy helper kept for callers that only need the IP string.
    nonisolated private func getInterfaceAddress(forInterfaceNamed name: String?, excludingCellularLike: Bool = false) -> String? {
        getInterfaceAddress(forInterfaceNamed: name, excludingCellularLike: excludingCellularLike)?.ip
    }
    
    func refreshSubnet(from ip: String? = nil) {
        let localIP = ip ?? currentNetwork
        let netmask = getInterfaceAddress()?.netmask
        let subnet = SubnetConfig.from(localIP: localIP, netmask: netmask)
        currentSubnet = subnet
        subnetPrefixLength = subnet.prefixLength
        subnetScanNote = subnet.scanNote
        networkRange = subnet.displayRange
        
        // Keep the UI scoped to the active LAN (avoids leftover hosts from other networks).
        let before = devices.count
        devices = devices.filter { subnet.contains($0.ipAddress) }
        if devices.count != before {
            previousDevices = Set(devices.filter { $0.status != .missing }.map(\.ipAddress))
            saveSettings()
        }
    }
    
    internal func validateIPAddress(_ ipAddress: String) -> Bool {
        IPAddressValidator.isValidIPv4(ipAddress)
    }
    
    func updateNetworkRange() {
        refreshSubnet(from: currentNetwork)
    }
    
    /// Reverse-DNS lookup with caching and a hard timeout that does not wait
    /// for blocked `getnameinfo` (see `TimedNameLookup`).
    internal func getHostName(for ip: String, timeout: TimeInterval = 0.8) async -> String? {
        if let cached = await dnsCache.get(ip) {
            return cached
        }
        
        let name = await TimedNameLookup.reverseDNS(ip: ip, timeout: timeout, requireName: true)
        if let name {
            await dnsCache.set(name, for: ip)
        }
        return name
    }
    
    /// Gibt DNS-Cache-Statistiken zurück
    ///
    /// - Returns: Formatierter String mit Cache-Statistiken
    func getDNSCacheStatistics() async -> String {
        await dnsCache.formattedStatistics()
    }
    
    /// Leert den DNS-Cache
    ///
    /// Nützlich zum Testen oder wenn aktuelle DNS-Einträge erzwungen werden sollen.
    func clearDNSCache() {
        Task {
            await dnsCache.clear()
        }
    }
    
    /// Entfernt abgelaufene DNS-Cache-Einträge
    ///
    /// Kann periodisch aufgerufen werden, um Memory zu sparen.
    func pruneExpiredDNSCache() {
        Task {
            await dnsCache.pruneExpired()
        }
    }
}
