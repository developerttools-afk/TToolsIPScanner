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

/// How aggressively phase-1 host discovery runs (ping, Bonjour, TCP breadth).
enum DiscoveryDepth: String, CaseIterable, Codable, Identifiable {
    case fast
    case normal
    case thorough
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fast: return "Schnell"
        case .normal: return "Normal"
        case .thorough: return "Gründlich"
        }
    }
}

enum ScanPhase: Equatable {
    case idle
    case scanningNetwork
    case scanningPorts
    case finished
}

/// Silent LAN warmup — reused when the user starts a scan.
struct LANPrefetchCache: Sendable {
    var networkPrefix: String
    var completedAt: Date
    var devices: [DeviceInfo]
    var bonjourByIP: [String: BonjourHostInfo]
    var discoveryPortsByIP: [String: [Int]]
    
    var isFresh: Bool {
        Date().timeIntervalSince(completedAt) < NetworkConstants.prefetchMaxAge
    }
}

// MARK: - NetworkScanner Class
@MainActor
class NetworkScanner: ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var devices: [DeviceInfo] = []
    @Published var currentNetwork: String = ""
    @Published var networkRange: String = ""
    @Published var subnetPrefixLength: Int = 24
    @Published var subnetScanNote: String = ""
    @Published var recentNetworks: [String] = []
    @Published var scanProgress: String = ""
    @Published var progressPercentage: Double = 0
    @Published var customPorts: Set<Int> = NetworkConstants.defaultPorts
    @Published var scanPhase: ScanPhase = .idle
    @Published var currentScanIP: String = ""
    @Published var debugMessage: String = ""
    /// Live step detail during scan (e.g. "dns 192.168.177.178 · 120ms").
    @Published var scanDebugDetail: String = ""
    @Published var isUpdatingOUI = false
    @Published var deviceAliases: [String: DeviceAlias] = [:]
    @Published var ouiDatabaseCount: Int = 0
    @Published var ouiDatabaseTimestamp: Date?
    @Published var isOUIDatabaseValid: Bool = false
    /// Shown in the OUI settings, e.g. "Letztes Update fehlgeschlagen: 404".
    @Published var ouiUpdateError: String?
    @Published var currentScanPort: Int = 0
    @Published var scanError: ScanError?
    /// IP of the device currently receiving a single-host port scan (nil when idle).
    @Published var devicePortScanIP: String?
    
    // MARK: - Internal Properties
    internal var previousDevices: Set<String> = []
    internal var currentSubnet: SubnetConfig?
    internal var ouiDatabase: [String: String] = [:]
    /// Current scan task - used for structured cancellation with async/await
    internal var currentScanTask: Task<Void, Never>?
    /// Single-device port scan task.
    internal var devicePortScanTask: Task<Void, Never>?
    /// MACs learned from Fritz!Box, gateway SNMP, or iCloud. ARP still wins.
    internal var routerMACOverlay: [String: String] = [:]
    /// Host names from Fritz!Box TR-064, keyed by IP.
    internal var routerNameOverlay: [String: String] = [:]
    /// Short result line for the router settings screen.
    @Published var routerMACStatus: String = ""
    /// Silent background warmup for the current LAN.
    internal var prefetchTask: Task<Void, Never>?
    internal var prefetchCache: LANPrefetchCache?
    /// DNS-Cache für Performance-Optimierung
    internal let dnsCache = DNSCache(validityDuration: 300, maxSize: 1000)
    internal let settings: SettingsManager
    internal let ouiDatabaseTimestampKey = "ouiDatabaseTimestamp"
    internal let ouiDatabaseValidityDuration: TimeInterval = 7 * 24 * 60 * 60
    
    @Published var preferredScanMode: ScanMode = .quickScan {
        didSet {
            settings.preferredScanMode = preferredScanMode
        }
    }
    @Published var preferredDiscoveryDepth: DiscoveryDepth = .normal {
        didSet {
            settings.preferredDiscoveryDepth = preferredDiscoveryDepth
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
    
    // MARK: - Initialization
    init(settings: SettingsManager = .shared) {
        self.settings = settings
        
        // Load settings from SettingsManager
        sortOption = settings.sortOption
        sortAscending = settings.sortAscending
        preferredScanMode = settings.preferredScanMode
        preferredDiscoveryDepth = settings.preferredDiscoveryDepth
        
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
