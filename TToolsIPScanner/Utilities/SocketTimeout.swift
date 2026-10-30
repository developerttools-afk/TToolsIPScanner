import Foundation
import Darwin

enum SocketTimeout {
    /// Builds a timeval that preserves sub-second precision.
    /// `Int(0.2) == 0` must not become "wait forever" for SO_RCVTIMEO.
    static func makeTimeval(from timeout: TimeInterval, minimumMicroseconds: Int32 = 50_000) -> timeval {
        let clamped = max(0, timeout)
        var seconds = Int(clamped)
        var microseconds = Int32((clamped - Double(seconds)) * 1_000_000)
        if seconds == 0 && microseconds < minimumMicroseconds {
            microseconds = minimumMicroseconds
        }
        if microseconds >= 1_000_000 {
            seconds += 1
            microseconds -= 1_000_000
        }
        return Darwin.timeval(tv_sec: seconds, tv_usec: microseconds)
    }
}
