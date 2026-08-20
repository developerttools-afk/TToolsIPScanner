import Foundation
import Network
import SystemConfiguration

extension NetworkScanner {
    func getCurrentNetwork() -> String? {
        var address: String?
        
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
                address = self.getIPAddress(forInterfaceNamed: preferred.name)
            } else {
                address = self.getIPAddress(forInterfaceNamed: nil, excludingCellularLike: true)
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
        _ = group.wait(timeout: .now() + 1.0)
        
        return address
    }
    
    /// Resolves IPv4 for a named interface (e.g. `en0`). If `name` is nil, returns
    /// the first non-loopback IPv4 that does not look like WWAN.
    private func getIPAddress(forInterfaceNamed name: String?, excludingCellularLike: Bool = false) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var fallback: String?
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
            
            if let name, ifName == name {
                return address
            }
            
            // Skip typical cellular interface names when scanning for LAN.
            if excludingCellularLike || name == nil {
                if ifName.hasPrefix("pdp_ip") || ifName.hasPrefix("utun") {
                    continue
                }
                if fallback == nil {
                    fallback = address
                }
            }
        }
        
        return fallback
    }
    
    internal func validateIPAddress(_ ipAddress: String) -> Bool {
        IPAddressValidator.isValidIPv4(ipAddress)
    }
    
    func updateNetworkRange() {
        let components = currentNetwork.split(separator: ".")
        if components.count == 4 {
            let baseIP = components.dropLast().joined(separator: ".")
            networkRange = "\(baseIP).1 - \(baseIP).255"
        }
    }
    
    /// Reverse-DNS lookup with timeout on a matching utility QoS queue.
    internal func getHostName(for ip: String, timeout: TimeInterval = 0.8) -> String? {
        let lock = NSLock()
        var resolvedName: String?
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.ttools.ipscanner.dns", qos: .utility)
        
        group.enter()
        queue.async {
            defer { group.leave() }
            
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM
            hints.ai_flags = AI_NUMERICHOST
            
            var result: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(ip, nil, &hints, &result) == 0, let info = result else {
                return
            }
            defer { freeaddrinfo(info) }
            guard let addr = info.pointee.ai_addr else { return }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                addr,
                info.pointee.ai_addrlen,
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NAMEREQD
            )
            guard status == 0 else { return }
            
            let name = String(cString: hostname)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            
            lock.lock()
            resolvedName = name
            lock.unlock()
        }
        
        _ = group.wait(timeout: .now() + timeout)
        lock.lock()
        defer { lock.unlock() }
        return resolvedName
    }
}
