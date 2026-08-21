import Foundation
import Network
import SystemConfiguration

extension NetworkScanner {
    nonisolated func getCurrentNetwork() -> String? {
        final class AddressBox: @unchecked Sendable {
            var value: String?
            let lock = NSLock()
            
            func set(_ newValue: String?) {
                lock.lock()
                defer { lock.unlock() }
                value = newValue
            }
            
            func get() -> String? {
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
                addressBox.set(self.getIPAddress(forInterfaceNamed: preferred.name))
            } else {
                addressBox.set(self.getIPAddress(forInterfaceNamed: nil, excludingCellularLike: true))
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
        _ = group.wait(timeout: .now() + 1.0)
        
        return addressBox.get()
    }
    
    /// Resolves IPv4 for a named interface (e.g. `en0`). If `name` is nil, returns
    /// the first non-loopback IPv4 that does not look like WWAN.
    nonisolated private func getIPAddress(forInterfaceNamed name: String?, excludingCellularLike: Bool = false) -> String? {
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
    
    /// Reverse-DNS lookup with caching and timeout using async/await
    ///
    /// Diese Methode prüft zuerst den DNS-Cache. Bei Cache-Miss wird ein
    /// DNS-Lookup mit async/await durchgeführt und das Ergebnis im Cache gespeichert.
    ///
    /// - Parameters:
    ///   - ip: IP-Adresse für DNS-Lookup
    ///   - timeout: Timeout in Sekunden (Standard: 0.8s)
    /// - Returns: Hostname oder `nil` bei Timeout/Fehler
    internal func getHostName(for ip: String, timeout: TimeInterval = 0.8) async -> String? {
        // Prüfe Cache zuerst
        if let cached = await dnsCache.get(ip) {
            return cached
        }
        
        // Cache-Miss: Führe DNS-Lookup durch mit async/await
        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM
                hints.ai_flags = AI_NUMERICHOST
                
                var result: UnsafeMutablePointer<addrinfo>?
                guard getaddrinfo(ip, nil, &hints, &result) == 0, let info = result else {
                    return nil
                }
                defer { freeaddrinfo(info) }
                guard let addr = info.pointee.ai_addr else { return nil }
                
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
                guard status == 0 else { return nil }
                
                let name = String(cString: hostname)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }
            
            // Add timeout task
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            
            // Return first result (either resolved name or timeout)
            for await result in group {
                group.cancelAll()
                // Speichere Ergebnis im Cache
                if let hostname = result {
                    await dnsCache.set(hostname, for: ip)
                }
                return result
            }
            
            return nil
        }
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
