import Foundation

extension NetworkScanner {
    /// Returns (isHostAlive, openPorts) - Host is alive if ANY port responds (even if closed)
    /// Fast sequential probe with aggressive early exit for maximum speed
    nonisolated internal func discoverHost(_ ip: String) -> (isAlive: Bool, openPorts: [Int]) {
        let timeout = NetworkConstants.discoveryTimeout
        var isAlive = false
        var openPorts: [Int] = []
        
        // Strategy: Probe 3-4 most common ports with early exit
        // Most devices respond on port 80, 443, or 22
        // Router/gateways often have 53, 80, or 8080 open
        let primaryPorts = Array(NetworkConstants.discoveryPorts.prefix(3))
        
        for port in primaryPorts {
            let (hostAlive, portOpen) = probeHost(ip: ip, port: port, timeout: timeout)
            
            if hostAlive {
                isAlive = true
                if portOpen {
                    openPorts.append(port)
                    // Early exit: found host with open port, we're done
                    return (true, openPorts)
                }
                // Host alive but port closed - continue to find open ports
            }
        }
        
        // If host is alive but no open ports yet, try 2 more common ports
        if isAlive {
            for port in NetworkConstants.discoveryPorts.dropFirst(3).prefix(2) {
                let (_, portOpen) = probeHost(ip: ip, port: port, timeout: timeout)
                if portOpen {
                    openPorts.append(port)
                    return (true, openPorts)
                }
            }
        }
        
        // If still no response, try port 53 (DNS) as last resort for routers
        if !isAlive {
            if let dnsPort = NetworkConstants.discoveryPorts.first(where: { $0 == 53 }) {
                let (hostAlive, portOpen) = probeHost(ip: ip, port: dnsPort, timeout: timeout)
                if hostAlive {
                    isAlive = true
                    if portOpen {
                        openPorts.append(dnsPort)
                    }
                }
            }
        }
        
        return (isAlive, openPorts.sorted())
    }
    
    /// Legacy compatibility - now checks if host is alive (not just open ports)
    nonisolated internal func isHostReachable(_ ip: String) -> Bool {
        discoverHost(ip).isAlive
    }
    
    /// Legacy compatibility - returns open ports
    nonisolated internal func probeOpenDiscoveryPorts(_ ip: String) -> [Int] {
        discoverHost(ip).openPorts
    }
    
    /// Tests every given port and returns those that are open (no early exit).
    nonisolated internal func probeOpenPorts(
        _ ip: String,
        ports: [Int],
        timeout: TimeInterval = 0.5
    ) -> [Int] {
        var open: [Int] = []
        for port in ports {
            if isPortOpen(ip: ip, port: port, timeout: timeout) {
                open.append(port)
            }
        }
        return open
    }
    
    /// Returns (isHostAlive, isPortOpen)
    nonisolated internal func probeHost(ip: String, port: Int, timeout: TimeInterval) -> (Bool, Bool) {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return (false, false) }
        
        var linger = linger(l_onoff: 1, l_linger: 0)
        _ = setsockopt(
            socket,
            SOL_SOCKET,
            SO_LINGER,
            &linger,
            socklen_t(MemoryLayout<linger>.size)
        )
        
        var noSigPipe: Int32 = 1
        _ = setsockopt(
            socket,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSigPipe,
            socklen_t(MemoryLayout<Int32>.size)
        )
        
        defer {
            Darwin.shutdown(socket, SHUT_RDWR)
            Darwin.close(socket)
        }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return (false, false) }
        
        let flags = fcntl(socket, F_GETFL, 0)
        _ = fcntl(socket, F_SETFL, flags | O_NONBLOCK)
        
        let result = withUnsafePointer(to: addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(socket, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if result == 0 {
            return (true, true) // Connected immediately - host alive, port open
        }
        
        // ECONNREFUSED = host is alive but port is closed
        if errno == ECONNREFUSED {
            return (true, false)
        }
        
        guard errno == EINPROGRESS else { return (false, false) }
        
        var fds = fd_set()
        let seconds = Int(timeout)
        let microseconds = Int32((timeout - Double(seconds)) * 1_000_000)
        var tv = timeval(tv_sec: seconds, tv_usec: microseconds)
        
        __darwin_fd_set(socket, &fds)
        
        let selectResult = select(socket + 1, nil, &fds, nil, &tv)
        guard selectResult > 0 else { return (false, false) }
        
        var error: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &len) == 0 else {
            return (false, false)
        }
        
        if error == 0 {
            return (true, true) // Connection succeeded - host alive, port open
        } else if error == ECONNREFUSED {
            return (true, false) // Connection refused - host alive, port closed
        } else {
            return (false, false) // Other error - likely no host
        }
    }
    
    nonisolated internal func isPortOpen(ip: String, port: Int, timeout: TimeInterval) -> Bool {
        let (_, portOpen) = probeHost(ip: ip, port: port, timeout: timeout)
        return portOpen
    }
}
