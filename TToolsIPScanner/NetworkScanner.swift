import Foundation
import Network
import SystemConfiguration
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Types
enum ScanMode {
    case quickScan
    case fullScan
}

enum ScanPhase {
    case idle
    case scanningNetwork
    case scanningPorts
    case finished
}

// MARK: - NetworkScanner Class
@MainActor
class NetworkScanner: ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var devices: [DeviceInfo] = []
    @Published var currentNetwork: String = ""
    @Published var networkRange: String = ""
    @Published var recentNetworks: [String] = []
    @Published var scanProgress: String = ""
    @Published var progressPercentage: Double = 0
    @Published var customPorts: Set<Int> = NetworkConstants.defaultPorts
    @Published var scanPhase: ScanPhase = .idle
    @Published var currentScanIP: String = ""
    @Published var debugMessage: String = ""
    @Published var isUpdatingOUI = false
    @Published var deviceAliases: [String: DeviceAlias] = [:]
    @Published var ouiDatabaseCount: Int = 0
    @Published var ouiDatabaseTimestamp: Date?
    @Published var isOUIDatabaseValid: Bool = false
    @Published var currentScanPort: Int = 0
    @Published var scanError: String?
    @Published var preferredScanMode: ScanMode = .quickScan {
        didSet {
            UserDefaults.standard.set(
                preferredScanMode == .fullScan ? "fullScan" : "quickScan",
                forKey: preferredScanModeKey
            )
        }
    }
    @Published var sortOption: SortOption = .ip {
        didSet {
            UserDefaults.standard.set(sortOption.rawValue, forKey: sortOptionKey)
            sortDevices()
        }
    }
    @Published var sortAscending: Bool = true {
        didSet {
            UserDefaults.standard.set(sortAscending, forKey: sortAscendingKey)
            sortDevices()
        }
    }
    
    // MARK: - Internal Properties
    internal var previousDevices: Set<String> = []
    internal var ouiDatabase: [String: String] = [:]
    /// Current scan task - used for structured cancellation with async/await
    internal var currentScanTask: Task<Void, Never>?
    
    // MARK: - UserDefaults Keys
    internal let customPortsKey = "customPorts"
    internal let lastScanResultsKey = "lastScanResults"
    internal let recentNetworksKey = "recentNetworks"
    internal let deviceAliasesKey = "deviceAliases"
    internal let ouiDatabaseTimestampKey = "ouiDatabaseTimestamp"
    internal let sortOptionKey = "sortOption"
    internal let sortAscendingKey = "sortAscending"
    internal let preferredScanModeKey = "preferredScanMode"
    internal let ouiDatabaseValidityDuration: TimeInterval = 7 * 24 * 60 * 60
    
    // MARK: - Initialization
    init() {
        if let savedSortOption = UserDefaults.standard.string(forKey: sortOptionKey),
           let option = SortOption(rawValue: savedSortOption) {
            sortOption = option
        }
        sortAscending = UserDefaults.standard.bool(forKey: sortAscendingKey)
        
        if UserDefaults.standard.string(forKey: preferredScanModeKey) == "fullScan" {
            preferredScanMode = .fullScan
        }
        
        currentNetwork = getCurrentNetwork() ?? "192.168.1.0"
        loadSettings()
        updateNetworkRange()
        loadOUIDatabase()
        if let savedData = UserDefaults.standard.data(forKey: deviceAliasesKey),
           let savedAliases = try? JSONDecoder().decode([String: DeviceAlias].self, from: savedData) {
            deviceAliases = savedAliases
        }
    }
    
    // MARK: - Public Methods
    public func updateCustomPorts(_ ports: Set<Int>) {
        customPorts = ports
        saveSettings()
    }
}
