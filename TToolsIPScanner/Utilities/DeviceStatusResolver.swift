import Foundation

enum DeviceStatusResolver {
    /// Derives status for a newly discovered host relative to the previous scan.
    static func status(for ip: String, previousIPs: Set<String>) -> DeviceStatus {
        previousIPs.contains(ip) ? .current : .new
    }
    
    /// IPs that were present before but are missing from the current result set.
    static func missingIPs(previousIPs: Set<String>, foundIPs: Set<String>) -> Set<String> {
        previousIPs.subtracting(foundIPs)
    }
}
