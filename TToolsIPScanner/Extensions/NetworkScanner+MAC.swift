import Foundation

extension NetworkScanner {
    nonisolated internal func getMacAddress(
        for ip: String,
        openPorts: [Int] = [],
        knownHostName: String? = nil,
        knownMac: String = "",
        arpMap: [String: String]? = nil,
        ouiDB: [String: String]
    ) -> (mac: String, manufacturer: String, osHint: String?) {
        // A provided map is the one table read for this scan. Do not sysctl again per host.
        let mac = arpMap?[ip].flatMap { $0.isEmpty ? nil : $0 }
            ?? (arpMap == nil ? ARPTable.macAddress(for: ip) : nil)
            ?? (knownMac.isEmpty ? nil : knownMac)
            ?? ""
        let portOsHint = osHintFromOpenPorts(openPorts)
        
        let manufacturer = resolveManufacturer(
            mac: mac,
            names: [knownHostName],
            bonjour: nil,
            ouiDB: ouiDB
        )
        return (mac, manufacturer, portOsHint)
    }
    
    /// Store a MAC learned without ARP and replace the vendor when the OUI database hits.
    func applyLearnedMAC(_ raw: String?, to device: inout DeviceInfo) {
        guard device.macAddress.isEmpty, let raw, let mac = MACAddress.normalize(raw) else { return }
        device.macAddress = mac
        let vendor = lookupManufacturer(mac: mac, ouiDB: ouiDatabase)
        if vendor != OUIParser.unknownManufacturer && vendor != OUIParser.privateMACLabel {
            device.manufacturer = vendor
        } else if shouldUpgradeManufacturer(current: device.manufacturer, proposed: vendor) {
            device.manufacturer = vendor
        }
    }
    
    nonisolated internal func lookupManufacturer(mac: String, ouiDB: [String: String]) -> String {
        OUIParser.lookup(mac: mac, database: ouiDB)
    }
    
    /// OUI (36, then 28, then 24 bit) wins. Without a MAC, Bonjour TXT and host names fill the vendor.
    nonisolated internal func resolveManufacturer(
        mac: String,
        names: [String?],
        bonjour: BonjourHostInfo?,
        ouiDB: [String: String]
    ) -> String {
        let ouiHit = mac.isEmpty ? OUIParser.unknownManufacturer : lookupManufacturer(mac: mac, ouiDB: ouiDB)
        if ouiHit != OUIParser.unknownManufacturer && ouiHit != OUIParser.privateMACLabel {
            return ouiHit
        }
        if let bonjour, let txtVendor = HostNameVendor.manufacturer(fromBonjour: bonjour) {
            return txtVendor
        }
        for name in names {
            if let hostVendor = HostNameVendor.manufacturer(from: name) {
                return hostVendor
            }
        }
        if ouiHit == OUIParser.privateMACLabel {
            return ouiHit
        }
        return OUIParser.unknownManufacturer
    }
    
    nonisolated internal func shouldUpgradeManufacturer(current: String, proposed: String) -> Bool {
        OUIParser.shouldUpgradeManufacturer(current: current, proposed: proposed)
    }
    
    /// Port-based hints belong in osHint, not manufacturer.
    nonisolated internal func osHintFromOpenPorts(_ openPorts: [Int]) -> String? {
        if openPorts.contains(22) { return "Unix/Linux?" }
        if openPorts.contains(3389) || openPorts.contains(445) { return "Windows?" }
        if openPorts.contains(548) || openPorts.contains(62078) { return "macOS?" }
        return nil
    }
    
    nonisolated internal func manufacturerFromHostName(_ name: String?) -> String? {
        HostNameVendor.manufacturer(from: name)
    }
    
    nonisolated internal func isPortGuessManufacturer(_ value: String) -> Bool {
        value == "Unix/Linux Device"
            || value == "Microsoft Corporation"
            || value == "IoT Device"
            || value == "Unbekannt"
    }
}
