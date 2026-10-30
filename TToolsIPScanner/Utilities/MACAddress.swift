import Foundation

/// Normalizes MAC strings and recovers a hardware address from Bonjour or IPv6.
enum MACAddress {
    /// `AA:BB:CC:DD:EE:FF`. Rejects multicast, all-zero, and all-ones addresses.
    static func normalize(_ raw: String) -> String? {
        let hex = raw.uppercased().filter(\.isHexDigit)
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(6)
        var index = hex.startIndex
        for _ in 0..<6 {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return format(bytes)
    }
    
    static func format(_ bytes: some Sequence<UInt8>) -> String? {
        let raw = Array(bytes)
        guard raw.count == 6 else { return nil }
        if raw.allSatisfy({ $0 == 0 }) || raw.allSatisfy({ $0 == 0xFF }) { return nil }
        if raw[0] & 0x01 != 0 { return nil }
        return raw.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
    
    /// `_raop._tcp` instance `A1B2C3D4E5F6@Wohnzimmer`.
    static func raopInstance(_ name: String) -> (mac: String, friendly: String)? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@") else { return nil }
        let prefix = String(trimmed[..<at])
        guard prefix.count == 12, let mac = normalize(prefix) else { return nil }
        let friendly = String(trimmed[trimmed.index(after: at)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (mac, friendly)
    }
    
    /// Avahi `_workstation._tcp` instance `hostname [aa:bb:cc:dd:ee:ff]`.
    static func workstationName(_ name: String) -> (mac: String, friendly: String)? {
        guard let open = name.lastIndex(of: "["),
              let close = name.lastIndex(of: "]"),
              open < close else { return nil }
        let inside = name[name.index(after: open)..<close]
        guard let mac = normalize(String(inside)) else { return nil }
        let friendly = String(name[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (mac, friendly)
    }
    
    /// Modified EUI-64 interface identifier (last 8 bytes). Flips bit 7 (0x02) of the first byte.
    static func fromEUI64(interfaceID iid: [UInt8]) -> String? {
        guard iid.count == 8, iid[3] == 0xFF, iid[4] == 0xFE else { return nil }
        return format([iid[0] ^ 0x02, iid[1], iid[2], iid[5], iid[6], iid[7]])
    }
    
    /// MAC and a cleaned display name from one Bonjour resolve.
    static func bonjourIdentity(
        serviceType: String,
        instanceName: String?,
        txt: [String: String]
    ) -> (mac: String?, displayName: String?) {
        let type = serviceType.lowercased()
        var mac: String?
        var display: String?
        
        if let instanceName {
            if type.contains("_raop"), let parsed = raopInstance(instanceName) {
                mac = parsed.mac
                if !parsed.friendly.isEmpty { display = parsed.friendly }
            }
            if type.contains("_workstation"), let parsed = workstationName(instanceName) {
                mac = mac ?? parsed.mac
                if !parsed.friendly.isEmpty { display = parsed.friendly }
            }
        }
        
        if mac == nil, type.contains("_airplay") || type.contains("_raop"),
           let raw = txt["deviceid"] {
            mac = normalize(raw)
        }
        if mac == nil, type.contains("_esphomelib") || type.contains("_shelly"),
           let raw = txt["mac"] {
            mac = normalize(raw)
        }
        return (mac, display)
    }
}
