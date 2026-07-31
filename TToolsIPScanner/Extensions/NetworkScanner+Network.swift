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
            if path.status == .satisfied {
                if let interface = path.availableInterfaces.first {
                    address = self.getIPAddress(for: interface)
                }
            }
            group.leave()
            monitor.cancel()
        }
        
        monitor.start(queue: DispatchQueue.global())
        _ = group.wait(timeout: .now() + 1.0)
        
        return address
    }
    
    private func getIPAddress(for interface: NWInterface) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while let currentPtr = ptr {
            defer { ptr = currentPtr.pointee.ifa_next }
            
            guard let addr = currentPtr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            
            let len = socklen_t(INET_ADDRSTRLEN)
            
            guard getnameinfo(
                UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr.self),
                len,
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else {
                continue
            }
            
            let address = String(cString: hostname)
            if !address.hasPrefix("127") {
                return address
            }
        }
        
        return nil
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
