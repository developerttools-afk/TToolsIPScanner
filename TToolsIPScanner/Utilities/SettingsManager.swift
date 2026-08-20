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
    
    /// Bevorzugter Scan-Modus (Quick/Full).
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
            Keys.preferredScanMode
        ]
        
        keys.forEach { storage.removeObject(forKey: $0) }
    }
    
    /// Exportiert alle Einstellungen als Dictionary (für Debugging/Backup).
    func exportSettings() -> [String: Any] {
        return [
            "customPorts": Array(customPorts),
            "preferredScanMode": preferredScanMode == .fullScan ? "fullScan" : "quickScan",
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
