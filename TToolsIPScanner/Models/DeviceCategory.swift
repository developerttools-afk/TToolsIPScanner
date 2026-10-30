import Foundation

enum DeviceCategory: String, Codable, CaseIterable {
    case unknown
    case router
    case computer
    case phone
    case printer
    case nas
    case tv
    case iot
    case smartHome
    
    var displayName: String {
        switch self {
        case .unknown: return "Unbekannt"
        case .router: return "Router"
        case .computer: return "Computer"
        case .phone: return "Smartphone"
        case .printer: return "Drucker"
        case .nas: return "NAS"
        case .tv: return "TV / Streaming"
        case .iot: return "IoT"
        case .smartHome: return "Smart Home"
        }
    }
    
    var systemImage: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .router: return "wifi.router"
        case .computer: return "desktopcomputer"
        case .phone: return "iphone"
        case .printer: return "printer"
        case .nas: return "externaldrive"
        case .tv: return "tv"
        case .iot: return "sensor"
        case .smartHome: return "house"
        }
    }
}

enum DeviceCategoryResolver {
    nonisolated static func categorize(
        ipAddress: String,
        openPorts: [Int],
        manufacturer: String,
        advertisedServices: [String],
        hostName: String,
        osHint: String
    ) -> DeviceCategory {
        let services = Set(advertisedServices.map { $0.lowercased() })
        let ports = Set(openPorts)
        let name = hostName.lowercased()
        let vendor = manufacturer.lowercased()
        
        if services.contains(where: { $0.contains("_printer") || $0.contains("_ipp") || $0.contains("_uscan") }) {
            return .printer
        }
        if ports.contains(631) || ports.contains(9100) {
            return .printer
        }
        
        if services.contains(where: { $0.contains("_hap") || $0.contains("_home-assistant") || $0.contains("_hassio") })
            || ports.contains(8123) {
            return .smartHome
        }
        if services.contains(where: {
            $0.contains("_esphome") || $0.contains("_tasmota") || $0.contains("_wled")
                || $0.contains("_arduino") || $0.contains("_shelly")
        }) || ports.contains(6053) {
            return .iot
        }
        
        if services.contains(where: { $0.contains("_airplay") || $0.contains("_raop") || $0.contains("_googlecast") || $0.contains("_sonos") }) {
            return .tv
        }
        
        if ports.contains(548) || ports.contains(5009) || ports.contains(62078) {
            return vendor.contains("apple") ? .computer : .nas
        }
        if ports.contains(2049) || ports.contains(111) && ports.contains(445) {
            return .nas
        }
        
        if name.contains("iphone") || name.contains("ipad") || osHint.lowercased().contains("ios") {
            return .phone
        }
        
        if ipAddress.hasSuffix(".1") && (ports.contains(80) || ports.contains(443) || ports.contains(53)) {
            return .router
        }
        if ports.contains(53) && ports.count <= 4 {
            return .router
        }
        
        if ports.contains(1883) || ports.contains(8883) || ports.contains(5683) {
            return .iot
        }
        
        if ports.contains(22) || ports.contains(3389) || ports.contains(445) || ports.contains(139) {
            return .computer
        }
        
        if vendor.contains("apple") {
            return name.contains("iphone") || name.contains("ipad") ? .phone : .computer
        }
        
        return .unknown
    }
}
