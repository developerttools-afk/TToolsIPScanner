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
    @Published var scanError: ScanError?
    @Published var preferredScanMode: ScanMode = .quickScan {
        didSet {
            settings.preferredScanMode = preferredScanMode
        }
    }
    @Published var sortOption: SortOption = .ip {
        didSet {
            settings.sortOption = sortOption
            sortDevices()
        }
    }
    @Published var sortAscending: Bool = true {
        didSet {
            settings.sortAscending = sortAscending
            sortDevices()
        }
    }
    
    // MARK: - Internal Properties
    internal var previousDevices: Set<String> = []
    internal var ouiDatabase: [String: String] = [:]
    /// Bumped on start/stop so in-flight work can detect cancellation.
    internal var scanGeneration: Int = 0
    internal let settings: SettingsManager
    internal let ouiDatabaseTimestampKey = "ouiDatabaseTimestamp"
    internal let ouiDatabaseValidityDuration: TimeInterval = 7 * 24 * 60 * 60
    
    // MARK: - Initialization
    init(settings: SettingsManager = .shared) {
        self.settings = settings
        
        // Load settings from SettingsManager
        sortOption = settings.sortOption
        sortAscending = settings.sortAscending
        preferredScanMode = settings.preferredScanMode
        
        currentNetwork = getCurrentNetwork() ?? "192.168.1.0"
        loadSettings()
        updateNetworkRange()
        loadOUIDatabase()
        deviceAliases = settings.deviceAliases
    }
    
    // MARK: - Public Methods
    public func updateCustomPorts(_ ports: Set<Int>) {
        customPorts = ports
        settings.customPorts = ports
        saveSettings()
    }
}
