import Foundation

enum DeviceStatus: String, Codable, Comparable {
    case current
    case new
    case missing
    
    static func < (lhs: DeviceStatus, rhs: DeviceStatus) -> Bool {
        let order: [DeviceStatus] = [.current, .new, .missing]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
} 