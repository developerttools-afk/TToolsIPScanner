import Foundation

/// Wireshark `manuf` / IEEE `oui.txt` parser.
///
/// Assignments are stored separately by IEEE block size so a longer prefix
/// cannot overwrite the 24-bit base vendor:
/// - MA-L: 24 bit, 6 hex digits
/// - MA-M: 28 bit, 7 hex digits
/// - MA-S: 36 bit, 9 hex digits
enum OUIParser {
    static let privateMACLabel = "Private MAC (zufällig)"
    static let unknownManufacturer = "Unbekannt"
    
    /// Placeholder labels that a real vendor may replace.
    static let placeholderManufacturers: Set<String> = [
        "",
        unknownManufacturer,
        "Unix/Linux Device",
        "IoT Device"
    ]
    
    struct Tables {
        var maL: [String: String] = [:]
        var maM: [String: String] = [:]
        var maS: [String: String] = [:]
        
        var count: Int { maL.count + maM.count + maS.count }
        
        func flattened() -> [String: String] {
            var all: [String: String] = [:]
            all.reserveCapacity(count)
            all.merge(maL) { _, new in new }
            all.merge(maM) { _, new in new }
            all.merge(maS) { _, new in new }
            return all
        }
    }
    
    struct Assignment {
        let key: String
        let bits: Int
        let vendor: String
    }
    
    static func parse(content: String) -> [String: String] {
        tables(content: content).flattened()
    }
    
    static func tables(content: String) -> Tables {
        var tables = Tables()
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            guard let assignment = parseAssignment(line) else { continue }
            switch assignment.bits {
            case 36:
                tables.maS[assignment.key] = assignment.vendor
            case 28:
                tables.maM[assignment.key] = assignment.vendor
            default:
                tables.maL[assignment.key] = assignment.vendor
            }
        }
        return tables
    }
    
    static func parseLine(_ line: String) -> (oui: String, vendor: String)? {
        guard let assignment = parseAssignment(line) else { return nil }
        return (assignment.key, assignment.vendor)
    }
    
    static func parseAssignment(_ line: String) -> Assignment? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        
        let tabComponents = trimmed.components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if tabComponents.count >= 2 {
            let vendor = tabComponents.count >= 3 ? tabComponents[2] : tabComponents[1]
            guard !vendor.isEmpty, let stored = storageKey(fromAddressField: tabComponents[0]) else { return nil }
            return Assignment(key: stored.key, bits: stored.bits, vendor: vendor)
        }
        
        if let hexRange = trimmed.range(of: "(hex)", options: .caseInsensitive) {
            let before = trimmed[..<hexRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            let after = trimmed[hexRange.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            guard !after.isEmpty, let stored = storageKey(fromAddressField: before) else { return nil }
            return Assignment(key: stored.key, bits: stored.bits, vendor: after)
        }
        
        return nil
    }
    
    /// MA-L / MA-M / MA-S key. Other mask lengths are ignored so they cannot collapse onto a 24-bit OUI.
    static func storageKey(fromAddressField raw: String) -> (key: String, bits: Int)? {
        let field = raw.trimmingCharacters(in: .whitespaces)
        let bits: Int?
        let addressPart: String
        if let slash = field.firstIndex(of: "/") {
            addressPart = String(field[..<slash])
            let mask = field[field.index(after: slash)...].filter(\.isNumber)
            bits = Int(mask)
        } else {
            addressPart = field
            bits = nil
        }
        
        let hex = normalizeOUI(addressPart)
        let bitCount = bits ?? 24
        let digits: Int
        switch bitCount {
        case 24: digits = 6
        case 28: digits = 7
        case 36: digits = 9
        default: return nil
        }
        guard hex.count >= digits else { return nil }
        return (String(hex.prefix(digits)), bitCount)
    }
    
    static func normalizeOUI(_ raw: String) -> String {
        raw
            .uppercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .filter { $0.isHexDigit }
    }
    
    /// Most specific assignment wins: 36 bit, then 28 bit, then 24 bit.
    /// Locally administered addresses with no hit become `privateMACLabel`.
    static func lookup(mac: String, database: [String: String]) -> String {
        let clean = normalizeOUI(mac)
        guard clean.count >= 6 else { return unknownManufacturer }
        
        if clean.count >= 9, let vendor = database[String(clean.prefix(9))] {
            return vendor
        }
        if clean.count >= 7, let vendor = database[String(clean.prefix(7))] {
            return vendor
        }
        let oui24 = String(clean.prefix(6))
        if let vendor = database[oui24] {
            return vendor
        }
        if let vendor = NetworkConstants.additionalOUIs[oui24] {
            return vendor
        }
        if isLocallyAdministered(clean) {
            return privateMACLabel
        }
        return unknownManufacturer
    }
    
    /// Bit 1 of the first octet (U/L). Set on iPhone/Android private Wi-Fi addresses.
    static func isLocallyAdministered(_ macOrHex: String) -> Bool {
        let clean = normalizeOUI(macOrHex)
        guard clean.count >= 2, let byte = UInt8(clean.prefix(2), radix: 16) else { return false }
        return byte & 0x02 != 0
    }
    
    static func shouldUpgradeManufacturer(current: String, proposed: String) -> Bool {
        guard !proposed.isEmpty, proposed != current, proposed != unknownManufacturer else { return false }
        guard isPlausibleVendor(proposed) else { return false }
        if proposed == privateMACLabel {
            return current.isEmpty || current == unknownManufacturer
                || current == "Unix/Linux Device" || current == "IoT Device"
        }
        return placeholderManufacturers.contains(current)
    }
    
    /// Rejects numeric TXT junk such as "0,1,2" while keeping real vendor names.
    static func isPlausibleVendor(_ value: String) -> Bool {
        if value == privateMACLabel { return true }
        return value.filter(\.isLetter).count >= 2
    }
}
