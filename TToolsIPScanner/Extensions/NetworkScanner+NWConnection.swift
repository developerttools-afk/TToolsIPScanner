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

    /// Sequential TCP discovery — one connection at a time, stop at first alive response.
    nonisolated func discoverHostModern(ip: String) async -> (Bool, [Int]) {
        var openPorts: [Int] = []
        var alive = false

        for port: UInt16 in [80, 443, 22] {
            let result = await probeHostModern(ip: ip, port: port, timeout: 0.4)
            if result.open {
                openPorts.append(Int(port))
            }
            if result.alive {
                alive = true
                break
            }
        }

        return (alive, openPorts)
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
