import Foundation
import Darwin

/// One-shot race helper: first caller wins; later results are ignored.
final class OnceBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private let continuation: CheckedContinuation<T, Never>
    
    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }
    
    func finish(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        continuation.resume(returning: value)
    }
}

/// Reverse DNS / mDNS lookups that must not block the scan pipeline.
///
/// Important: wrapping blocking `getnameinfo` in a `TaskGroup` does **not** work —
/// the group waits for cancelled children, so a "timeout" still hangs until the
/// system resolver returns (often many seconds on the last hosts).
enum TimedNameLookup {
    static func reverseDNS(ip: String, timeout: TimeInterval, requireName: Bool) async -> String? {
        await withCheckedContinuation { continuation in
            let box = OnceBox<String?>(continuation)
            
            Thread.detachNewThread {
                let name = blockingReverse(ip: ip, requireName: requireName)
                box.finish(name)
            }
            
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                box.finish(nil)
            }
        }
    }
    
    private static func blockingReverse(ip: String, requireName: Bool) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_NUMERICHOST
        
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(ip, nil, &hints, &result) == 0, let info = result else { return nil }
        defer { freeaddrinfo(info) }
        guard let addr = info.pointee.ai_addr else { return nil }
        
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let flags: Int32 = requireName ? NI_NAMEREQD : 0
        let status = getnameinfo(
            addr,
            info.pointee.ai_addrlen,
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            flags
        )
        guard status == 0 else { return nil }
        
        let name = String(cString: hostname)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ip else { return nil }
        return name
    }
}
