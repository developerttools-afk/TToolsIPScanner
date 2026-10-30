import Foundation

/// Zentrale Settings-Verwaltung für die App mit type-safe Zugriff auf UserDefaults.
///
/// Alle App-Einstellungen werden über diese Klasse verwaltet, um:
/// - Type-Safety zu garantieren
/// - Magic Strings zu vermeiden
/// - Wartbarkeit zu verbessern
/// - Tests zu vereinfachen
///
/// Verwendung:
/// ```swift
/// let settings = SettingsManager.shared
/// settings.sortOption = .hostname
/// ```
final class SettingsManager {
    // MARK: - Singleton
    
    /// Shared Instance für die gesamte App.
    static let shared = SettingsManager()
    
    /// Optionale Instance für Tests (ermöglicht Mocking).
    static func forTesting(storage: UserDefaults = UserDefaults(suiteName: "test")!) -> SettingsManager {
        return SettingsManager(storage: storage)
    }
    
    // MARK: - Storage
    
    private let storage: UserDefaults
    
    // MARK: - Keys (private, werden nur intern verwendet)
    
    private enum Keys {
        static let customPorts = "customPorts"
        static let lastScanResults = "lastScanResults"
        static let recentNetworks = "recentNetworks"
        static let deviceAliases = "deviceAliases"
        static let sortOption = "sortOption"
        static let sortAscending = "sortAscending"
        static let preferredScanMode = "preferredScanMode"
        static let preferredDiscoveryDepth = "preferredDiscoveryDepth"
        static let fritzTR064Enabled = "fritzTR064Enabled"
        static let fritzHost = "fritzHost"
        static let fritzUsername = "fritzUsername"
        static let snmpARPEnabled = "snmpARPEnabled"
        static let snmpCommunity = "snmpCommunity"
        static let shareMACOveriCloud = "shareMACOveriCloud"
    }
    
    // MARK: - Initialization
    
    init(storage: UserDefaults = .standard) {
        self.storage = storage
    }
    
    // MARK: - Scan Settings
    
    /// Benutzerdefinierte Ports für den Scan (komma-getrennt gespeichert).
    var customPorts: Set<Int> {
        get {
            guard let portsString = storage.string(forKey: Keys.customPorts) else {
                return NetworkConstants.defaultPorts
            }
            return Set(portsString.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
        set {
            let portsString = newValue.sorted().map(String.init).joined(separator: ",")
            storage.set(portsString, forKey: Keys.customPorts)
        }
    }
    
    /// Bevorzugter Scan-Modus (Quick/Full) für Phase-2 Port-Scan.
    var preferredScanMode: ScanMode {
        get {
            let rawValue = storage.string(forKey: Keys.preferredScanMode) ?? "quickScan"
            return rawValue == "fullScan" ? .fullScan : .quickScan
        }
        set {
            let value = newValue == .fullScan ? "fullScan" : "quickScan"
            storage.set(value, forKey: Keys.preferredScanMode)
        }
    }
    
    /// Host-Discovery-Tiefe (Schnell/Normal/Gründlich) für Phase 1.
    var preferredDiscoveryDepth: DiscoveryDepth {
        get {
            guard let raw = storage.string(forKey: Keys.preferredDiscoveryDepth),
                  let depth = DiscoveryDepth(rawValue: raw) else {
                return .normal
            }
            return depth
        }
        set {
            storage.set(newValue.rawValue, forKey: Keys.preferredDiscoveryDepth)
        }
    }
    
    // MARK: - Router MAC sources
    
    /// TR-064 Hosts:GetGenericHostEntry. Off until the user opts in.
    var fritzTR064Enabled: Bool {
        get { storage.bool(forKey: Keys.fritzTR064Enabled) }
        set { storage.set(newValue, forKey: Keys.fritzTR064Enabled) }
    }
    
    /// Empty means the gateway, or `fritz.box` when no gateway is known.
    var fritzHost: String {
        get { storage.string(forKey: Keys.fritzHost) ?? "" }
        set { storage.set(newValue, forKey: Keys.fritzHost) }
    }
    
    var fritzUsername: String {
        get { storage.string(forKey: Keys.fritzUsername) ?? "" }
        set { storage.set(newValue, forKey: Keys.fritzUsername) }
    }
    
    /// SNMP walk of the gateway ARP table. Fails fast when the router has no SNMP.
    var snmpARPEnabled: Bool {
        get {
            if storage.object(forKey: Keys.snmpARPEnabled) == nil { return true }
            return storage.bool(forKey: Keys.snmpARPEnabled)
        }
        set { storage.set(newValue, forKey: Keys.snmpARPEnabled) }
    }
    
    var snmpCommunity: String {
        get {
            let value = storage.string(forKey: Keys.snmpCommunity) ?? "public"
            return value.isEmpty ? "public" : value
        }
        set { storage.set(newValue, forKey: Keys.snmpCommunity) }
    }
    
    /// macOS publishes MAC addresses; iOS reads them for the same subnet.
    var shareMACOveriCloud: Bool {
        get {
            if storage.object(forKey: Keys.shareMACOveriCloud) == nil { return true }
            return storage.bool(forKey: Keys.shareMACOveriCloud)
        }
        set { storage.set(newValue, forKey: Keys.shareMACOveriCloud) }
    }
    
    // MARK: - Sort Settings
    
    /// Aktuelle Sortier-Option.
    @EnumUserDefault(key: Keys.sortOption, defaultValue: .ip)
    var sortOption: SortOption
    
    /// Aufsteigende Sortierung?
    @UserDefault(key: Keys.sortAscending, defaultValue: true)
    var sortAscending: Bool
    
    // MARK: - Network Settings
    
    /// Zuletzt verwendete Netzwerke.
    var recentNetworks: [String] {
        get {
            storage.stringArray(forKey: Keys.recentNetworks) ?? []
        }
        set {
            storage.set(newValue, forKey: Keys.recentNetworks)
        }
    }
    
    // MARK: - Scan Results
    
    /// Zuletzt gescannte Geräte (persistent).
    @CodableUserDefault(key: Keys.lastScanResults, defaultValue: [])
    var lastScanResults: [DeviceInfo]
    
    // MARK: - Device Aliases
    
    /// Benutzerdefinierte Geräte-Aliase (IP/MAC → Alias).
    @CodableUserDefault(key: Keys.deviceAliases, defaultValue: [:])
    var deviceAliases: [String: DeviceAlias]
    
    // MARK: - Utility Methods
    
    /// Löscht alle gespeicherten Einstellungen (für Reset/Tests).
    func resetAllSettings() {
        let keys = [
            Keys.customPorts,
            Keys.lastScanResults,
            Keys.recentNetworks,
            Keys.deviceAliases,
            Keys.sortOption,
            Keys.sortAscending,
            Keys.preferredScanMode,
            Keys.preferredDiscoveryDepth
        ]
        
        keys.forEach { storage.removeObject(forKey: $0) }
    }
    
    /// Exportiert alle Einstellungen als Dictionary (für Debugging/Backup).
    func exportSettings() -> [String: Any] {
        return [
            "customPorts": Array(customPorts),
            "preferredScanMode": preferredScanMode == .fullScan ? "fullScan" : "quickScan",
            "preferredDiscoveryDepth": preferredDiscoveryDepth.rawValue,
            "sortOption": sortOption.rawValue,
            "sortAscending": sortAscending,
            "recentNetworks": recentNetworks,
            "deviceAliasesCount": deviceAliases.count,
            "lastScanResultsCount": lastScanResults.count
        ]
    }
    
    /// Synchronisiert UserDefaults sofort (normalerweise automatisch).
    func synchronize() {
        storage.synchronize()
    }
}

// MARK: - Notification Support

extension SettingsManager {
    /// Benachrichtigt über Änderungen an den Einstellungen.
    static let didChangeNotification = Notification.Name("SettingsManagerDidChange")
    
    /// Sendet eine Benachrichtigung, dass sich Einstellungen geändert haben.
    func notifyChange(key: String? = nil) {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self,
            userInfo: key.map { ["key": $0] }
        )
    }
}
