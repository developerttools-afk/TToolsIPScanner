import Foundation

/// Folds an IPv6-only row into the IPv4 row of the same host.
enum IPv6Pairing {
    static func pair(_ devices: [DeviceInfo]) -> [DeviceInfo] {
        let v4Indexes = devices.indices.filter { !IPv6Address.isIPv6(devices[$0].ipAddress) }
        let v6Indexes = devices.indices.filter { IPv6Address.isIPv6(devices[$0].ipAddress) }
        guard !v4Indexes.isEmpty, !v6Indexes.isEmpty else { return devices }
        
        var nameOwners: [String: Set<Int>] = [:]
        for index in v4Indexes {
            for name in identities(devices[index]) {
                nameOwners[name, default: []].insert(index)
            }
        }
        let uniqueNames = Set(nameOwners.filter { $0.value.count == 1 }.keys)
        
        var rows = devices
        var drop = Set<Int>()
        for v6 in v6Indexes {
            let hardwareMatches = v4Indexes.filter { sameHardware(rows[$0], rows[v6]) }
            let match: Int?
            if hardwareMatches.count == 1 {
                match = hardwareMatches[0]
            } else if hardwareMatches.isEmpty {
                let nameMatches = v4Indexes.filter { sharedName(rows[$0], rows[v6], allowed: uniqueNames) }
                match = nameMatches.count == 1 ? nameMatches[0] : nil
            } else {
                match = nil
            }
            guard let match else { continue }
            rows[match] = merged(rows[match], with: rows[v6])
            drop.insert(v6)
        }
        
        return rows.enumerated().compactMap { drop.contains($0.offset) ? nil : $0.element }
    }
    
    private static func sameHardware(_ ipv4: DeviceInfo, _ ipv6: DeviceInfo) -> Bool {
        let left = hardwareMACs(ipv4)
        let right = hardwareMACs(ipv6)
        return !left.isEmpty && !left.isDisjoint(with: right)
    }
    
    private static func hardwareMACs(_ device: DeviceInfo) -> Set<String> {
        var macs: Set<String> = []
        if let mac = MACAddress.normalize(device.macAddress) {
            macs.insert(mac)
        }
        if let mac = euiMAC(device.ipAddress) {
            macs.insert(mac)
        }
        if let mac = euiMAC(device.ipv6Address) {
            macs.insert(mac)
        }
        return macs
    }
    
    private static func euiMAC(_ address: String) -> String? {
        guard let raw = IPv6Address.bytes(of: address) else { return nil }
        return MACAddress.fromEUI64(interfaceID: Array(raw.suffix(8)))
    }
    
    private static func sharedName(_ ipv4: DeviceInfo, _ ipv6: DeviceInfo, allowed: Set<String>) -> Bool {
        let left = identities(ipv4).intersection(allowed)
        let right = identities(ipv6)
        return !left.isEmpty && !left.isDisjoint(with: right)
    }
    
    private static func identities(_ device: DeviceInfo) -> Set<String> {
        Set([device.hostName, device.bonjourName, device.mdnsName, device.dnsName, device.netbiosName].compactMap(identity))
    }
    
    private static func identity(_ raw: String) -> String? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if name.lowercased().hasSuffix(".local") {
            name = String(name.dropLast(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let lower = name.lowercased()
        if lower.hasPrefix("gerät") || lower == "unknown" || lower == "n/a" || lower == "nicht mehr verfügbar" {
            return nil
        }
        guard lower.count >= 2 else { return nil }
        return lower
    }
    
    private static func merged(_ ipv4: DeviceInfo, with ipv6: DeviceInfo) -> DeviceInfo {
        var host = ipv4
        let address = IPv6Address.isIPv6(ipv6.ipAddress) ? ipv6.ipAddress : ipv6.ipv6Address
        host.ipv6Address = IPv6Address.preferred(host.ipv6Address, address)
        if host.macAddress.isEmpty {
            host.macAddress = ipv6.macAddress
        }
        if identity(host.hostName) == nil, identity(ipv6.hostName) != nil {
            host.hostName = ipv6.hostName
        }
        if host.bonjourName.isEmpty { host.bonjourName = ipv6.bonjourName }
        if host.mdnsName.isEmpty { host.mdnsName = ipv6.mdnsName }
        if host.dnsName.isEmpty { host.dnsName = ipv6.dnsName }
        if host.netbiosName.isEmpty { host.netbiosName = ipv6.netbiosName }
        if host.manufacturer.isEmpty { host.manufacturer = ipv6.manufacturer }
        host.openPorts = Array(Set(host.openPorts + ipv6.openPorts)).sorted()
        return host
    }
}
