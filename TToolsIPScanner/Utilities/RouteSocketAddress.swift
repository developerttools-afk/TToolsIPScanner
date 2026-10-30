import Foundation

/// Sockaddr padding inside a kernel routing message (`rt_msghdr`).
enum RouteSocketAddress {
    /// The kernel advances to the next address on a 4-byte boundary.
    /// A length of 0 still occupies one aligned slot.
    static func stride(saLen: Int) -> Int {
        if saLen <= 0 { return 4 }
        return (saLen + 3) & ~3
    }
}
