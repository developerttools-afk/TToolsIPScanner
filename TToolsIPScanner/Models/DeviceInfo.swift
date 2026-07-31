import Foundation

struct DeviceInfo: Identifiable, Hashable, Codable {
    let id: UUID
    let ipAddress: String
    var hostName: String
    var macAddress: String
    var manufacturer: String
    var openPorts: [Int]
    var status: DeviceStatus
    var isExpanded: Bool
    
    /// Key for alias lookup: prefer MAC when available, otherwise IP.
    var aliasKey: String {
        macAddress.isEmpty ? ipAddress : macAddress
    }
    
    init(id: UUID = UUID(),
         ipAddress: String,
         hostName: String,
         macAddress: String,
         manufacturer: String,
         openPorts: [Int],
         status: DeviceStatus,
         isExpanded: Bool) {
        self.id = id
        self.ipAddress = ipAddress
        self.hostName = hostName
        self.macAddress = macAddress
        self.manufacturer = manufacturer
        self.openPorts = openPorts
        self.status = status
        self.isExpanded = isExpanded
    }
    
    static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
