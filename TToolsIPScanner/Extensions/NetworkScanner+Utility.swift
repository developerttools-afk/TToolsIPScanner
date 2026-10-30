import SwiftUI

extension NetworkScanner {
    nonisolated func usefulHostName(_ name: String?) -> String? {
        guard var name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              name != "…",
              name != "Resolving...",
              name != "Unknown",
              name != "Nicht mehr verfügbar" else {
            return nil
        }
        if name.hasPrefix("Gerät .") { return nil }
        if name.hasSuffix(".local") {
            name = String(name.dropLast(6))
        }
        if let first = name.split(separator: ".").first, !first.isEmpty {
            // Prefer short label over FQDN when it's a single local name.
            let short = String(first)
            if name.contains(".") && !name.contains(" ") { return short }
        }
        return name
    }

    func getPortDescription(_ port: Int) -> String {
        return NetworkConstants.portDescriptions[port] ?? "Unbekannt"
    }
    
    func getPortSymbol(_ port: Int) -> (symbol: String, color: Color)? {
        return NetworkConstants.portSymbols[port]
    }
    
    func getDeviceAlias(for key: String) -> DeviceAlias? {
        guard !key.isEmpty else { return nil }
        return deviceAliases[key]
    }
    
    func getDeviceAlias(for device: DeviceInfo) -> DeviceAlias? {
        rememberedAlias(ip: device.ipAddress, mac: device.macAddress)
    }
    
    func displayName(for device: DeviceInfo) -> String {
        rememberedHostName(ip: device.ipAddress, mac: device.macAddress)
            ?? usefulHostName(device.hostName)
            ?? usefulHostName(device.bonjourName)
            ?? usefulHostName(device.netbiosName)
            ?? fallbackHostLabel(ip: device.ipAddress)
    }
    
    /// Prefer any real discovery source over placeholders.
    /// Order: Alias → DNS → mDNS → SMB/NetBIOS → Bonjour → Cache → Fallback
    nonisolated func bestHostName(
        ip: String,
        alias: String?,
        bonjour: String?,
        netbios: String?,
        mdns: String?,
        dns: String?,
        cached: String?,
        current: String?
    ) -> String {
        alias.flatMap { usefulHostName($0) }
            ?? dns.flatMap { usefulHostName($0) }
            ?? mdns.flatMap { usefulHostName($0) }
            ?? netbios.flatMap { usefulHostName($0) }
            ?? bonjour.flatMap { usefulHostName($0) }
            ?? cached.flatMap { usefulHostName($0) }
            ?? current.flatMap { usefulHostName($0) }
            ?? fallbackHostLabel(ip: ip)
    }
    
    nonisolated func fallbackHostLabel(ip: String) -> String {
        if let last = ip.split(separator: ".").last {
            return "Gerät .\(last)"
        }
        return ip
    }
    
    /// True when we already have a human-readable name (not a placeholder).
    nonisolated func isWellIdentified(_ device: DeviceInfo) -> Bool {
        if usefulHostName(device.hostName) != nil { return true }
        if usefulHostName(device.bonjourName) != nil { return true }
        if usefulHostName(device.mdnsName) != nil { return true }
        if usefulHostName(device.netbiosName) != nil { return true }
        if usefulHostName(device.dnsName) != nil { return true }
        return false
    }
    
    nonisolated func isWellIdentified(
        hostName: String?,
        bonjour: String?,
        mdns: String?,
        netbios: String?,
        dns: String?
    ) -> Bool {
        if usefulHostName(hostName) != nil { return true }
        if usefulHostName(bonjour) != nil { return true }
        if usefulHostName(mdns) != nil { return true }
        if usefulHostName(netbios) != nil { return true }
        if usefulHostName(dns) != nil { return true }
        return false
    }
    
    /// Apply Bonjour instance name, TXT model/make, and service types onto a device.
    func mergeBonjour(_ info: BonjourHostInfo, into device: inout DeviceInfo) {
        if let name = info.bestName.flatMap({ usefulHostName($0) }) {
            if usefulHostName(device.bonjourName) == nil { device.bonjourName = name }
            if usefulHostName(device.mdnsName) == nil { device.mdnsName = name }
            if usefulHostName(device.hostName) == nil { device.hostName = name }
        }
        if usefulHostName(device.hostName) == nil,
           let model = info.modelLabel.flatMap({ usefulHostName($0) }) {
            device.hostName = model
            if device.bonjourName.isEmpty { device.bonjourName = model }
        }
        if device.detailHint.isEmpty, let model = info.modelLabel {
            device.detailHint = model
        }
        applyLearnedMAC(info.macAddress, to: &device)
        if let vendor = HostNameVendor.manufacturer(fromBonjour: info),
           shouldUpgradeManufacturer(current: device.manufacturer, proposed: vendor) {
            device.manufacturer = vendor
        }
        for service in info.serviceTypes where !device.advertisedServices.contains(service) {
            device.advertisedServices.append(service)
        }
    }
    
    func log(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.debugMessage = message
        }
    }
}
