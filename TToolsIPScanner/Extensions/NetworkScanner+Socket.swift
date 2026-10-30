import Foundation

extension NetworkScanner {
    nonisolated internal func discoveryPorts(for depth: DiscoveryDepth) -> [Int] {
        switch depth {
        case .fast: return NetworkConstants.fastDiscoveryPorts
        case .normal, .thorough: return NetworkConstants.discoveryPorts
        }
    }
    
    /// Returns (isHostAlive, openPorts).
    /// Uses a short parallel first wave so dead hosts fail fast (critical on iOS/Wi‑Fi).
    nonisolated internal func discoverHost(_ ip: String, depth: DiscoveryDepth) -> (isAlive: Bool, openPorts: [Int]) {
        let ports = discoveryPorts(for: depth)
        let primaryTimeout = depth == .fast
            ? NetworkConstants.discoveryTimeoutFast
            : NetworkConstants.discoveryTimeoutNormal
        let retryTimeout = NetworkConstants.discoveryTimeoutRetry
        
        if let result = probePorts(ports, ip: ip, timeout: primaryTimeout, depth: depth) {
            return result
        }
        
        // One short retry on the first wave only — never re-walk all ports at 1s each.
        if depth != .fast {
            let wave = Array(ports.prefix(NetworkConstants.discoveryWaveSize))
            if let result = probePorts(wave, ip: ip, timeout: retryTimeout, depth: .fast) {
                return result
            }
        }
        
        if depth == .thorough, tryUDPProbe(ip) {
            return (true, [])
        }
        
        return (false, [])
    }
    
    nonisolated internal func isHostReachable(_ ip: String, depth: DiscoveryDepth = .normal) -> Bool {
        discoverHost(ip, depth: depth).isAlive
    }
    
    nonisolated internal func probeOpenDiscoveryPorts(_ ip: String, depth: DiscoveryDepth = .normal) -> [Int] {
        discoverHost(ip, depth: depth).openPorts
    }
    
    /// Parallel first wave; if any host answers (open or RST), probe the rest in parallel.
    /// Dead hosts only pay for the wave — not all discovery ports.
    nonisolated private func probePorts(
        _ ports: [Int],
        ip: String,
        timeout: TimeInterval,
        depth: DiscoveryDepth
    ) -> (isAlive: Bool, openPorts: [Int])? {
        guard !ports.isEmpty else { return nil }
        
        let waveSize = min(NetworkConstants.discoveryWaveSize, ports.count)
        let wave = Array(ports.prefix(waveSize))
        let (waveAlive, waveOpen) = probePortsParallel(wave, ip: ip, timeout: timeout)
        
        guard waveAlive else {
            // Thorough: one extra parallel pass on remaining ports before giving up.
            if depth == .thorough, ports.count > waveSize {
                let rest = Array(ports.dropFirst(waveSize))
                let (restAlive, restOpen) = probePortsParallel(rest, ip: ip, timeout: timeout)
                if restAlive {
                    return (true, restOpen.sorted())
                }
            }
            return nil
        }
        
        var openPorts = waveOpen
        if ports.count > waveSize {
            let rest = Array(ports.dropFirst(waveSize))
            let (_, restOpen) = probePortsParallel(rest, ip: ip, timeout: timeout)
            openPorts.append(contentsOf: restOpen)
        }
        return (true, Array(Set(openPorts)).sorted())
    }
    
    nonisolated private func probePortsParallel(
        _ ports: [Int],
        ip: String,
        timeout: TimeInterval
    ) -> (alive: Bool, open: [Int]) {
        guard !ports.isEmpty else { return (false, []) }
        let lock = NSLock()
        var open: [Int] = []
        var alive = false
        DispatchQueue.concurrentPerform(iterations: ports.count) { index in
            let port = ports[index]
            let (hostAlive, portOpen) = probeHost(ip: ip, port: port, timeout: timeout)
            lock.lock()
            if portOpen { open.append(port) }
            if hostAlive { alive = true }
            lock.unlock()
        }
        return (alive, open)
    }
    
    /// Tests every given port and returns those that are open (parallel, capped batch size).
    nonisolated internal func probeOpenPorts(
        _ ip: String,
        ports: [Int],
        timeout: TimeInterval = 0.25
    ) -> [Int] {
        guard !ports.isEmpty else { return [] }
        let lock = NSLock()
        var open: [Int] = []
        let batch = NetworkConstants.portScanBatchSize
        var start = 0
        while start < ports.count {
            let end = min(start + batch, ports.count)
            let slice = Array(ports[start..<end])
            DispatchQueue.concurrentPerform(iterations: slice.count) { index in
                let port = slice[index]
                if isPortOpen(ip: ip, port: port, timeout: timeout) {
                    lock.lock()
                    open.append(port)
                    lock.unlock()
                }
            }
            start = end
        }
        return open.sorted()
    }
    
    /// Returns (isHostAlive, isPortOpen)
    nonisolated internal func probeHost(ip: String, port: Int, timeout: TimeInterval) -> (Bool, Bool) {
        if IPv6Address.isIPv6(ip) {
            return probeHost6(ip: ip, port: port, timeout: timeout)
        }
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
            return (true, true)
        }
        
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
            return (true, true)
        } else if error == ECONNREFUSED {
            return (true, false)
        } else {
            return (false, false)
        }
    }
    
    nonisolated private func probeHost6(ip: String, port: Int, timeout: TimeInterval) -> (Bool, Bool) {
        guard var addr = IPv6Address.socketAddress(ip, port: port) else { return (false, false) }
        let socket = Darwin.socket(AF_INET6, SOCK_STREAM, 0)
        guard socket >= 0 else { return (false, false) }
        
        var linger = linger(l_onoff: 1, l_linger: 0)
        _ = setsockopt(socket, SOL_SOCKET, SO_LINGER, &linger, socklen_t(MemoryLayout<linger>.size))
        var noSigPipe: Int32 = 1
        _ = setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        defer {
            Darwin.shutdown(socket, SHUT_RDWR)
            Darwin.close(socket)
        }
        
        let flags = fcntl(socket, F_GETFL, 0)
        _ = fcntl(socket, F_SETFL, flags | O_NONBLOCK)
        
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(socket, sockAddr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        if result == 0 { return (true, true) }
        if errno == ECONNREFUSED { return (true, false) }
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
        guard getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &len) == 0 else { return (false, false) }
        if error == 0 { return (true, true) }
        if error == ECONNREFUSED { return (true, false) }
        return (false, false)
    }
    
    nonisolated internal func isPortOpen(ip: String, port: Int, timeout: TimeInterval) -> Bool {
        let (_, portOpen) = probeHost(ip: ip, port: port, timeout: timeout)
        return portOpen
    }
    
    nonisolated private func tryUDPProbe(_ ip: String) -> Bool {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }
        
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
        
        var tv = timeval(tv_sec: 0, tv_usec: 100_000)
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        let udpPorts: [UInt16] = [53, 123, 67]
        
        for port in udpPorts {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { continue }
            
            var dummyByte: UInt8 = 0
            let sent = withUnsafePointer(to: &dummyByte) { dataPtr in
                withUnsafePointer(to: &addr) { addrPtr in
                    addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                        Darwin.sendto(sock, dataPtr, 1, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            
            if sent >= 0 {
                var buf = [UInt8](repeating: 0, count: 1)
                var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let received = withUnsafeMutablePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                        Darwin.recvfrom(sock, &buf, 1, 0, sockAddr, &addrLen)
                    }
                }
                
                if received < 0 && errno == ECONNREFUSED {
                    return true
                }
            }
        }
        
        return false
    }
}
