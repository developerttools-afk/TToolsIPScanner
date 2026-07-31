import Foundation

extension NetworkScanner {
    func loadSettings() {
        if let savedPortsString = UserDefaults.standard.string(forKey: customPortsKey) {
            customPorts = Set(savedPortsString.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
        
        if let savedData = UserDefaults.standard.data(forKey: lastScanResultsKey),
           let savedDevices = try? JSONDecoder().decode([DeviceInfo].self, from: savedData) {
            devices = savedDevices
            previousDevices = Set(savedDevices.filter { $0.status != .missing }.map { $0.ipAddress })
        }
        
        if let savedNetworks = UserDefaults.standard.stringArray(forKey: recentNetworksKey) {
            recentNetworks = savedNetworks
        }
    }
    
    func saveSettings() {
        let portsString = customPorts.sorted().map(String.init).joined(separator: ",")
        UserDefaults.standard.set(portsString, forKey: customPortsKey)
        
        if let encodedData = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encodedData, forKey: lastScanResultsKey)
        }
        
        UserDefaults.standard.set(recentNetworks, forKey: recentNetworksKey)
    }
}
