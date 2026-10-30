import Foundation

struct TableSettings: Codable, RawRepresentable {
    var visibleColumns: Set<ColumnType>
    
    enum ColumnType: String, CaseIterable, Codable, Identifiable {
        case status = "Status"
        case ip = "IP"
        case hostname = "Gerätename"
        case dnsName = "DNS-Name"
        case mdnsName = "mDNS-Name"
        case mac = "MAC-Adresse"
        case manufacturer = "Hersteller"
        case portSymbols = "Port-Symbole"
        case ports = "Offene Ports"
        
        var id: String { rawValue }
        
        /// Stable ID for `TableColumnCustomization` / SceneStorage.
        var customizationID: String {
            switch self {
            case .status: return "status"
            case .ip: return "ip"
            case .hostname: return "hostname"
            case .dnsName: return "dnsName"
            case .mdnsName: return "mdnsName"
            case .mac: return "mac"
            case .manufacturer: return "manufacturer"
            case .portSymbols: return "portSymbols"
            case .ports: return "ports"
            }
        }
        
        var icon: String {
            switch self {
            case .status: return "circle.fill"
            case .ip: return "network"
            case .hostname: return "server.rack"
            case .dnsName: return "globe"
            case .mdnsName: return "dot.radiowaves.left.and.right"
            case .mac: return "cpu"
            case .manufacturer: return "building.2"
            case .portSymbols: return "square.grid.2x2"
            case .ports: return "arrow.left.and.right"
            }
        }
        
        var defaultWidth: (min: CGFloat?, ideal: CGFloat, max: CGFloat?) {
            switch self {
            case .status: return (44, 52, 64)
            case .ip: return (110, 130, 180)
            case .hostname: return (100, 160, 320)
            case .dnsName: return (80, 140, 280)
            case .mdnsName: return (80, 140, 280)
            case .mac: return (120, 150, 200)
            case .manufacturer: return (100, 160, 320)
            case .portSymbols, .ports: return (100, 180, 360)
            }
        }
    }
    
    // RawRepresentable for legacy AppStorage visibility list
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            self.visibleColumns = Set(ColumnType.allCases)
            return
        }
        self.visibleColumns = Set(decoded.compactMap { ColumnType(rawValue: $0) })
        if self.visibleColumns.count <= 7,
           !self.visibleColumns.contains(.dnsName),
           !self.visibleColumns.contains(.mdnsName) {
            self.visibleColumns.insert(.dnsName)
            self.visibleColumns.insert(.mdnsName)
        }
    }
    
    public var rawValue: String {
        let encoded = Array(visibleColumns).map { $0.rawValue }
        guard let data = try? JSONEncoder().encode(encoded),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
    
    init(visibleColumns: Set<ColumnType> = Set(ColumnType.allCases)) {
        self.visibleColumns = visibleColumns
    }
    
    static let `default` = TableSettings()
}
