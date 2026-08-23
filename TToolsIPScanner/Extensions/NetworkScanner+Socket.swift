import Foundation

extension NetworkScanner {
    /// Returns (isHostAlive, openPorts) - Host is alive if ANY port responds (even if closed)
    /// Fast discovery with 6 ports covering 98% of devices
    nonisolated internal func discoverHost(_ ip: String) -> (isAlive: Bool, openPorts: [Int]) {
        let timeout = NetworkConstants.discoveryTimeout
        var openPorts: [Int] = []
        
        // CRITICAL: Expanded port list to catch stubborn routers/gateways!
        // Many routers ONLY respond to specific ports or have firewalls
        // Testing more ports to ensure we catch everything:
        // - 80, 8080, 8443: HTTP/Alt HTTP/Alt HTTPS (most common)
        // - 443: HTTPS (web admin)
        // - 22, 23: SSH/Telnet (management)
        // - 53: DNS (critical for gateways)
        // - 445, 139: SMB (Windows/NAS)
        // - 3389: RDP (Windows)
        // - 5900: VNC (remote access)
        //
        // Strategy: Try most common first, then management ports
        let criticalPorts = [80, 8080, 443, 22, 53, 8443, 445, 23, 139, 3389, 5900]
        
        for port in criticalPorts {
            let (hostAlive, portOpen) = probeHost(ip: ip, port: port, timeout: timeout)
            
            // DEBUG LOGGING (temporary)
            if ip.hasSuffix(".1") || ip.hasSuffix(".141") || ip.hasSuffix(".100") {
                print("🔍 \(ip):\(port) → alive=\(hostAlive) open=\(portOpen)")
            }
            
            if hostAlive {
                if portOpen {
                    openPorts.append(port)
                }
                // Host is alive - check remaining ports for more open ones
                for remainingPort in criticalPorts where remainingPort > port {
                    let (_, open) = probeHost(ip: ip, port: remainingPort, timeout: timeout)
                    if open {
                        openPorts.append(remainingPort)
                    }
                }
                return (true, openPorts)
            }
        }
        
        // No response on any port - host is down
        return (false, [])
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
