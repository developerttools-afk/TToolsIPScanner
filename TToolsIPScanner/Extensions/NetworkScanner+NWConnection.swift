import Foundation
import Network

// Thread-safe box for state tracking in NWConnection callbacks
private final class StateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _hasReturned = false
    
    var hasReturned: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasReturned
    }
    
    func markReturned() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if !_hasReturned {
            _hasReturned = true
            return true
        }
        return false
    }
}

// MARK: - Modern Network.framework based scanning (iOS optimized)
extension NetworkScanner {
    
    /// Probe a host using NWConnection (modern iOS-friendly API)
    /// Returns (isAlive, isPortOpen, rtt)
    nonisolated func probeHostModern(
        ip: String,
        port: UInt16,
        timeout: TimeInterval = 0.2
    ) async -> (Bool, Bool, TimeInterval?) {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let port = NWEndpoint.Port(integerLiteral: port)
            let connection = NWConnection(host: host, port: port, using: .tcp)
            
            // Thread-safe state tracking
            let stateBox = StateBox()
            
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if stateBox.markReturned() {
                    connection.cancel()
                    continuation.resume(returning: (false, false, nil))
                }
            }
            
            connection.stateUpdateHandler = { state in
                guard !stateBox.hasReturned else { return }
                
                switch state {
                case .ready:
                    // Connection successful - host is alive AND port is open
                    if stateBox.markReturned() {
                        timeoutTask.cancel()
                        let rtt = Date().timeIntervalSince(startTime)
                        connection.cancel()
                        continuation.resume(returning: (true, true, rtt))
                    }
                    
                case .failed(let error):
                    // Connection failed - but we need to distinguish why
                    if stateBox.markReturned() {
                        timeoutTask.cancel()
                        connection.cancel()
                        
                        // Check if connection was refused (host alive but port closed)
                        // TCP RST = Connection Refused = Host is ALIVE!
                        let isAlive: Bool
                        if case .posix(let posixCode) = error {
                            isAlive = (posixCode == .ECONNREFUSED)
                        } else {
                            isAlive = false
                        }
                        
                        continuation.resume(returning: (isAlive, false, nil))
                    }
                    
                case .cancelled:
                    // Already handled by timeout
                    break
                    
                default:
                    // Still waiting (.preparing, .waiting)
                    break
                }
            }
            
            connection.start(queue: .global(qos: .userInitiated))
        }
    }
    
    /// Discover a host using modern NWConnection API
    /// Probes critical ports in parallel, returns as soon as one responds
    nonisolated func discoverHostModern(ip: String) async -> (Bool, [Int]) {
        // Fast discovery: probe most common ports in parallel
        let criticalPorts: [UInt16] = [80, 443, 22]
        
        return await withTaskGroup(of: (UInt16, Bool, Bool, TimeInterval?).self) { group in
            var isAlive = false
            var openPorts: [Int] = []
            
            // Start all probes in parallel
            for port in criticalPorts {
                group.addTask {
                    let (alive, open, rtt) = await self.probeHostModern(ip: ip, port: port, timeout: 0.2)
                    return (port, alive, open, rtt)
                }
            }
            
            // Collect results
            for await (port, alive, open, _) in group {
                if alive {
                    isAlive = true
                }
                if open {
                    openPorts.append(Int(port))
                }
            }
            
            return (isAlive, openPorts)
        }
    }
}
