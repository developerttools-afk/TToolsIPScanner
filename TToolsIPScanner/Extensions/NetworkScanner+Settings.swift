import Foundation

extension NetworkScanner {
    func loadSettings() {
        // Load from SettingsManager
        customPorts = settings.customPorts
        
        // Load last scan results
        let savedDevices = settings.lastScanResults
        devices = savedDevices
        previousDevices = Set(savedDevices.filter { $0.status != .missing }.map { $0.ipAddress })
        
        // Load recent networks
        recentNetworks = settings.recentNetworks
    }
    
    func saveSettings() {
        // Save to SettingsManager
        settings.customPorts = customPorts
        settings.lastScanResults = devices
        settings.recentNetworks = recentNetworks
    }
}
