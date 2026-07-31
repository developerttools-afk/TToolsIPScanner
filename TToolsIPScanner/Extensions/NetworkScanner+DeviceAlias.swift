import Foundation

extension NetworkScanner {
    public func setDeviceAlias(for key: String, alias: DeviceAlias) {
        guard !key.isEmpty else { return }
        deviceAliases[key] = alias
        saveDeviceAliases()
    }
    
    public func removeDeviceAlias(for key: String) {
        guard !key.isEmpty else { return }
        deviceAliases.removeValue(forKey: key)
        saveDeviceAliases()
    }
    
    private func saveDeviceAliases() {
        if let encodedData = try? JSONEncoder().encode(deviceAliases) {
            UserDefaults.standard.set(encodedData, forKey: deviceAliasesKey)
        }
    }
}
