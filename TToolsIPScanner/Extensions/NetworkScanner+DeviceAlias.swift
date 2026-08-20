import Foundation

extension NetworkScanner {
    /// Saves alias under IP and MAC (when known) so the next scan still finds it.
    public func setDeviceAlias(for device: DeviceInfo, alias: DeviceAlias) {
        let trimmed = DeviceAlias(
            customName: alias.customName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: alias.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !trimmed.customName.isEmpty else { return }
        
        deviceAliases[device.ipAddress] = trimmed
        if !device.macAddress.isEmpty {
            deviceAliases[device.macAddress] = trimmed
        }
        saveDeviceAliases()
        
        // Reflect immediately in the current result list.
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            var copy = devices
            copy[index].hostName = trimmed.customName
            devices = copy
        }
    }
    
    public func removeDeviceAlias(for device: DeviceInfo) {
        deviceAliases.removeValue(forKey: device.ipAddress)
        if !device.macAddress.isEmpty {
            deviceAliases.removeValue(forKey: device.macAddress)
        }
        deviceAliases.removeValue(forKey: device.aliasKey)
        saveDeviceAliases()
    }
    
    /// Legacy key-based API — prefer device-based methods.
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
    
    /// Looks up alias by MAC first, then IP (covers key changes between scans).
    func rememberedAlias(ip: String, mac: String = "") -> DeviceAlias? {
        if !mac.isEmpty, let alias = deviceAliases[mac], !alias.customName.isEmpty {
            return alias
        }
        if let alias = deviceAliases[ip], !alias.customName.isEmpty {
            return alias
        }
        return nil
    }
    
    /// Hostname shown / stored: user alias wins over DNS / cache.
    func rememberedHostName(ip: String, mac: String = "") -> String? {
        let name = rememberedAlias(ip: ip, mac: mac)?.customName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        return name
    }
    
    /// After MAC is discovered, copy IP-based alias onto the MAC key.
    func migrateAliasIfNeeded(ip: String, mac: String) {
        guard !mac.isEmpty else { return }
        if deviceAliases[mac] != nil { return }
        guard let alias = deviceAliases[ip] else { return }
        deviceAliases[mac] = alias
        saveDeviceAliases()
    }
    
    private func saveDeviceAliases() {
        settings.deviceAliases = deviceAliases
    }
}
