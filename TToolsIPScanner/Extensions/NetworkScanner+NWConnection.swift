import Foundation
import Network

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
            
            var hasReturned = false
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !hasReturned {
                    hasReturned = true
                    connection.cancel()
                    continuation.resume(returning: (false, false, nil))
                }
            }
            
            connection.stateUpdateHandler = { state in
                guard !hasReturned else { return }
                
                switch state {
                case .ready:
                    // Connection successful - host is alive AND port is open
                    hasReturned = true
                    timeoutTask.cancel()
                    let rtt = Date().timeIntervalSince(startTime)
                    connection.cancel()
                    continuation.resume(returning: (true, true, rtt))
                    
                case .failed(let error):
                    // Connection failed - but we need to distinguish why
                    hasReturned = true
                    timeoutTask.cancel()
                    connection.cancel()
                    
                    // Connection refused = host is alive but port is closed
                    let isRefused = (error as? POSIXError)?.code == .ECONNREFUSED
                    continuation.resume(returning: (isRefused, false, nil))
                    
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
    nonisolated func discoverHostModern(ip: String) async -> (Bool, [UInt16]) {
        // Fast discovery: probe most common ports in parallel
        let criticalPorts: [UInt16] = [80, 443, 22]
        
        return await withTaskGroup(of: (UInt16, Bool, Bool, TimeInterval?).self) { group in
            var isAlive = false
            var openPorts: [UInt16] = []
            
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
                    openPorts.append(port)
                }
            }
            
            return (isAlive, openPorts)
        }
    }
}
