import Foundation

enum OUIParser {
    /// Parses Wireshark manuf / tab-separated OUI lines into OUI → vendor map.
    /// Also accepts IEEE-style lines with hex OUI and vendor name.
    static func parse(content: String) -> [String: String] {
        var database: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("#") && !$0.isEmpty }
        
        for line in lines {
            if let entry = parseLine(line) {
                database[entry.oui] = entry.vendor
            }
        }
        return database
    }
    
    static func parseLine(_ line: String) -> (oui: String, vendor: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        
        // Wireshark manuf: OUI\tshort\tlong  or OUI\tname
        let tabComponents = trimmed.components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if tabComponents.count >= 2 {
            let oui = normalizeOUI(tabComponents[0])
            guard oui.count >= 6 else { return nil }
            let vendor = tabComponents.count >= 3 ? tabComponents[2] : tabComponents[1]
            return (String(oui.prefix(6)), vendor)
        }
        
        // IEEE oui.txt style: "XX-XX-XX   (hex)\t\tVendor"
        if let hexRange = trimmed.range(of: "(hex)", options: .caseInsensitive) {
            let before = trimmed[..<hexRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            let after = trimmed[hexRange.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            let oui = normalizeOUI(before)
            guard oui.count >= 6, !after.isEmpty else { return nil }
            return (String(oui.prefix(6)), after)
        }
        
        return nil
    }
    
    static func normalizeOUI(_ raw: String) -> String {
        raw
            .uppercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .filter { $0.isHexDigit }
    }
}
