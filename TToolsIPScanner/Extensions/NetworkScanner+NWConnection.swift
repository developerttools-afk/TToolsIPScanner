import Foundation
import Network

/// Thread-safe one-shot flag for NWConnection callbacks vs. timeout.
final class ProbeStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var consumed = false

    func consume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if consumed { return false }
        consumed = true
        return true
    }
}

extension NetworkScanner {
    /// TCP probe via Network.framework. Treats ECONNREFUSED / ECONNRESET as "host alive".
    /// `.waiting` must be handled — iOS often reports RST there instead of `.failed`.
    nonisolated func probeHostModern(
        ip: String,
        port: UInt16,
        timeout: TimeInterval = 0.4
    ) async -> (alive: Bool, open: Bool) {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(ip),
                port: NWEndpoint.Port(integerLiteral: port),
                using: .tcp
            )
            let box = ProbeStateBox()

            let finish: @Sendable (Bool, Bool) -> Void = { alive, open in
                guard box.consume() else { return }
                connection.cancel()
                continuation.resume(returning: (alive, open))
            }

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                finish(false, false)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutTask.cancel()
                    finish(true, true)

                case .waiting(let error), .failed(let error):
                    if Self.hostIsAlive(despite: error) {
                        timeoutTask.cancel()
                        finish(true, false)
                    } else if case .failed = state {
                        timeoutTask.cancel()
                        finish(false, false)
                    }
                    // `.waiting` with a "path down" error: keep waiting until timeout.

                case .cancelled:
                    break

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Sequential TCP discovery — stop at first alive response.
    nonisolated func discoverHostModern(ip: String, depth: DiscoveryDepth) async -> (Bool, [Int]) {
        let ports = discoveryPorts(for: depth)
        let primaryTimeout = depth == .fast
            ? NetworkConstants.discoveryTimeoutFast
            : NetworkConstants.discoveryTimeoutNormal
        let retryTimeout = NetworkConstants.discoveryTimeoutRetry
        
        if let result = await probePortsModern(ports, ip: ip, timeout: primaryTimeout) {
            return result
        }
        
        if depth != .fast, let result = await probePortsModern(ports, ip: ip, timeout: retryTimeout) {
            return result
        }
        
        return (false, [])
    }
    
    private nonisolated func probePortsModern(
        _ ports: [Int],
        ip: String,
        timeout: TimeInterval
    ) async -> (Bool, [Int])? {
        var openPorts: [Int] = []
        
        for (index, port) in ports.enumerated() {
            let result = await probeHostModern(ip: ip, port: UInt16(clamping: port), timeout: timeout)
            if result.open { openPorts.append(port) }
            
            if result.alive {
                for remaining in ports[(index + 1)...] {
                    let r = await probeHostModern(ip: ip, port: UInt16(clamping: remaining), timeout: timeout)
                    if r.open { openPorts.append(remaining) }
                }
                return (true, openPorts)
            }
        }
        return nil
    }

    /// Phase-2 port scan for already discovered hosts. Parallel TCP probes;
    /// only `.ready` counts as an open port.
    nonisolated func probeOpenPortsModern(
        _ ip: String,
        ports: [Int],
        timeout: TimeInterval = 0.3
    ) async -> [Int] {
        guard !ports.isEmpty else { return [] }
        return await withTaskGroup(of: Int?.self, returning: [Int].self) { group in
            for port in ports {
                group.addTask {
                    let result = await self.probeHostModern(
                        ip: ip,
                        port: UInt16(clamping: port),
                        timeout: timeout
                    )
                    return result.open ? port : nil
                }
            }
            var open: [Int] = []
            for await port in group {
                if let port { open.append(port) }
            }
            return open.sorted()
        }
    }

    nonisolated private static func hostIsAlive(despite error: NWError) -> Bool {
        guard case .posix(let code) = error else { return false }
        switch code {
        case .ECONNREFUSED, .ECONNRESET:
            return true
        default:
            return false
        }
    }
}
