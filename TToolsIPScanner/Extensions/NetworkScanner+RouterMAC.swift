import Foundation

extension NetworkScanner {
    /// ARP table plus Fritz, gateway SNMP, and iCloud. Existing ARP entries stay.
    /// Waits for in-flight ARP replies, then reads the kernel table once.
    func mergedMACMapAfterProbe(prefix: String) async -> [String: String] {
        try? await Task.sleep(for: .seconds(NetworkConstants.neighborSettleDelay))
        guard !Task.isCancelled else { return mergedMACMap(prefix: prefix) }
        return mergedMACMap(prefix: prefix)
    }
    
    /// Fills MACs that were still empty when the host was first listed.
    func applyARPToListedDevices(_ arpMap: [String: String]) {
        for index in devices.indices {
            guard devices[index].macAddress.isEmpty, let mac = arpMap[devices[index].ipAddress] else { continue }
            applyLearnedMAC(mac, to: &devices[index])
        }
    }
    
    func mergedMACMap(prefix: String) -> [String: String] {
        var map = ARPTable.entries(matchingPrefix: prefix)
        for (ip, mac) in routerMACOverlay where (map[ip] ?? "").isEmpty {
            map[ip] = mac
        }
        return map
    }
    
    func fetchRouterMACOverlay(prefix: String) async {
        let gateway = GatewayProbe.defaultGatewayIP()
            ?? (prefix.isEmpty ? nil : "\(prefix).1")
        let configuredHost = settings.fritzHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let fritzTarget = configuredHost.isEmpty ? (gateway ?? "fritz.box") : configuredHost
        let fritzEnabled = settings.fritzTR064Enabled
        let username = settings.fritzUsername
        let password = RouterCredentialStore.password() ?? ""
        let snmpEnabled = settings.snmpARPEnabled
        let community = settings.snmpCommunity
        let cloud = LANMACCloudStore.hosts(prefix: prefix)
        
        async let fritzEntries: [FritzHostEntry] = fritzEnabled
            ? FritzBoxHosts.fetch(host: fritzTarget, username: username, password: password)
            : []
        async let snmpEntries: [String: String] = {
            guard snmpEnabled, let gateway else { return [:] }
            return await SNMPProbe.arpTable(gateway: gateway, community: community)
        }()
        
        let fritz = await fritzEntries
        let snmp = await snmpEntries
        
        var macs: [String: String] = [:]
        var names: [String: String] = [:]
        func consider(ip: String, mac: String, name: String?) {
            guard !prefix.isEmpty, ip.hasPrefix(prefix + ".") else { return }
            if macs[ip] == nil, let normalized = MACAddress.normalize(mac) {
                macs[ip] = normalized
            }
            if let name, names[ip] == nil, let useful = usefulHostName(name), useful != "*" {
                names[ip] = useful
            }
        }
        for entry in fritz {
            consider(ip: entry.ip, mac: entry.mac, name: entry.hostName)
        }
        for (ip, mac) in snmp {
            consider(ip: ip, mac: mac, name: nil)
        }
        for (ip, mac) in cloud {
            consider(ip: ip, mac: mac, name: nil)
        }
        
        let status = "Fritz \(fritz.count) · SNMP \(snmp.count) · iCloud \(cloud.count)"
        routerMACOverlay = macs
        routerNameOverlay = names
        routerMACStatus = status
    }
    
    func applyRouterOverlayToDevices() {
        var copy = devices
        var changed = false
        for index in copy.indices {
            let ip = copy[index].ipAddress
            if copy[index].macAddress.isEmpty, let mac = routerMACOverlay[ip] {
                applyLearnedMAC(mac, to: &copy[index])
                changed = true
            }
            if usefulHostName(copy[index].hostName) == nil,
               let name = routerNameOverlay[ip] {
                copy[index].hostName = name
                changed = true
            }
        }
        if changed { devices = copy }
    }
    
    func publishMACsToiCloud(prefix: String) {
        #if os(macOS)
        guard !prefix.isEmpty else { return }
        var hosts: [String: String] = [:]
        for device in devices where !device.macAddress.isEmpty {
            hosts[device.ipAddress] = device.macAddress
        }
        LANMACCloudStore.publish(prefix: prefix, hosts: hosts)
        #endif
    }
}
