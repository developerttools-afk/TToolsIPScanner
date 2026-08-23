import Foundation

extension NetworkScanner {
    /// TCP connect probe used for host discovery and port scanning.
    nonisolated internal func isHostReachable(_ ip: String) -> Bool {
        !probeOpenDiscoveryPorts(ip).isEmpty
    }
    
    /// Lightweight host discovery — only a small fixed port set, stops early once the host is up.
    nonisolated internal func probeOpenDiscoveryPorts(_ ip: String) -> [Int] {
        var open: [Int] = []
        for port in NetworkConstants.discoveryPorts {
            if isPortOpen(ip: ip, port: port, timeout: NetworkConstants.discoveryTimeout) {
                open.append(port)
                print("🎯 DEBUG: Found open port \(port) on \(ip)")
                if open.count >= 2 { break }
            }
        }
        if open.isEmpty {
            print("⚠️  DEBUG: No open ports found on \(ip)")
        }
        return open
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
    
    nonisolated internal func isPortOpen(ip: String, port: Int, timeout: TimeInterval) -> Bool {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        
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
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return false }
        
        let flags = fcntl(socket, F_GETFL, 0)
        _ = fcntl(socket, F_SETFL, flags | O_NONBLOCK)
        
        let result = withUnsafePointer(to: addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(socket, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if result == 0 {
            return true
        }
        
        guard errno == EINPROGRESS else { return false }
        
        var fds = fd_set()
        let seconds = Int(timeout)
        let microseconds = Int32((timeout - Double(seconds)) * 1_000_000)
        var tv = timeval(tv_sec: seconds, tv_usec: microseconds)
        
        __darwin_fd_set(socket, &fds)
        
        let selectResult = select(socket + 1, nil, &fds, nil, &tv)
        guard selectResult > 0 else { return false }
        
        var error: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &len) == 0 else {
            return false
        }
        return error == 0
    }
}
