import Foundation

struct DeviceInfo: Identifiable, Hashable, Codable {
    let id: UUID
    let ipAddress: String
    /// Second address when the same host was also found via IPv6.
    var ipv6Address: String
    var hostName: String
    var macAddress: String
    var manufacturer: String
    var openPorts: [Int]
    var status: DeviceStatus
    var isExpanded: Bool
    /// Friendly name from Bonjour service browse.
    var bonjourName: String
    /// Windows/Samba name from NetBIOS, if available.
    var netbiosName: String
    /// Unicast reverse-DNS name.
    var dnsName: String
    /// mDNS / `.local` reverse name.
    var mdnsName: String
    /// Short hint from HTTP title, Server header, or SSH banner.
    var detailHint: String
    /// OS guess from ICMP TTL or SSH banner.
    var osHint: String
    /// Bonjour service types seen for this host (e.g. `_airplay._tcp`).
    var advertisedServices: [String]
    /// First time this host appeared in a scan.
    var firstSeen: Date?
    /// Most recent time this host was seen alive.
    var lastSeen: Date?
    /// Heuristic device type from ports, services, and vendor.
    var category: DeviceCategory
    
    /// Key for alias lookup: prefer MAC when available, otherwise IP.
    var aliasKey: String {
        macAddress.isEmpty ? ipAddress : macAddress
    }
    
    init(id: UUID = UUID(),
         ipAddress: String,
         ipv6Address: String = "",
         hostName: String,
         macAddress: String,
         manufacturer: String,
         openPorts: [Int],
         status: DeviceStatus,
         isExpanded: Bool,
         bonjourName: String = "",
         netbiosName: String = "",
         dnsName: String = "",
         mdnsName: String = "",
         detailHint: String = "",
         osHint: String = "",
         advertisedServices: [String] = [],
         firstSeen: Date? = nil,
         lastSeen: Date? = nil,
         category: DeviceCategory = .unknown) {
        self.id = id
        self.ipAddress = ipAddress
        self.ipv6Address = ipv6Address
        self.hostName = hostName
        self.macAddress = macAddress
        self.manufacturer = manufacturer
        self.openPorts = openPorts
        self.status = status
        self.isExpanded = isExpanded
        self.bonjourName = bonjourName
        self.netbiosName = netbiosName
        self.dnsName = dnsName
        self.mdnsName = mdnsName
        self.detailHint = detailHint
        self.osHint = osHint
        self.advertisedServices = advertisedServices
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.category = category
    }
    
    enum CodingKeys: String, CodingKey {
        case id, ipAddress, ipv6Address, hostName, macAddress, manufacturer, openPorts, status, isExpanded
        case bonjourName, netbiosName, dnsName, mdnsName, detailHint, osHint, advertisedServices
        case firstSeen, lastSeen, category
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ipAddress = try c.decode(String.self, forKey: .ipAddress)
        ipv6Address = try c.decodeIfPresent(String.self, forKey: .ipv6Address) ?? ""
        hostName = try c.decode(String.self, forKey: .hostName)
        macAddress = try c.decode(String.self, forKey: .macAddress)
        manufacturer = try c.decode(String.self, forKey: .manufacturer)
        openPorts = try c.decode([Int].self, forKey: .openPorts)
        status = try c.decode(DeviceStatus.self, forKey: .status)
        isExpanded = try c.decode(Bool.self, forKey: .isExpanded)
        bonjourName = try c.decodeIfPresent(String.self, forKey: .bonjourName) ?? ""
        netbiosName = try c.decodeIfPresent(String.self, forKey: .netbiosName) ?? ""
        dnsName = try c.decodeIfPresent(String.self, forKey: .dnsName) ?? ""
        mdnsName = try c.decodeIfPresent(String.self, forKey: .mdnsName) ?? ""
        detailHint = try c.decodeIfPresent(String.self, forKey: .detailHint) ?? ""
        osHint = try c.decodeIfPresent(String.self, forKey: .osHint) ?? ""
        advertisedServices = try c.decodeIfPresent([String].self, forKey: .advertisedServices) ?? []
        firstSeen = try c.decodeIfPresent(Date.self, forKey: .firstSeen)
        lastSeen = try c.decodeIfPresent(Date.self, forKey: .lastSeen)
        category = try c.decodeIfPresent(DeviceCategory.self, forKey: .category) ?? .unknown
    }
    
    static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
