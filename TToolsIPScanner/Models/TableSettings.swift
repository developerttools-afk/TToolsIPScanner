import Foundation

struct TableSettings: Codable, RawRepresentable {
    var visibleColumns: Set<ColumnType>
    
    enum ColumnType: String, CaseIterable, Codable {
        case status = "Status"
        case ip = "IP"
        case hostname = "Gerätename"
        case mac = "MAC-Adresse"
        case manufacturer = "Hersteller"
        case portSymbols = "Port-Symbole"
        case ports = "Offene Ports"
        
        var icon: String {
            switch self {
            case .status: return "circle.fill"
            case .ip: return "network"
            case .hostname: return "server.rack"
            case .mac: return "cpu"
            case .manufacturer: return "building.2"
            case .portSymbols: return "square.grid.2x2"
            case .ports: return "arrow.left.and.right"
            }
        }
    }
    
    // RawRepresentable Implementierung für AppStorage
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            self.visibleColumns = Set(ColumnType.allCases)
            return
        }
        self.visibleColumns = Set(decoded.compactMap { ColumnType(rawValue: $0) })
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