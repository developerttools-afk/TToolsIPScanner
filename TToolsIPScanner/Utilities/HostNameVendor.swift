import Foundation

/// Manufacturer hints from host, Bonjour, and NetBIOS names.
/// Tokens are matched on word boundaries so "mac" does not hit "machine".
enum HostNameVendor {
    static func manufacturer(from name: String?) -> String? {
        guard let name else { return nil }
        let tokens = tokenize(name)
        guard !tokens.isEmpty else { return nil }
        var pairs = Set<String>()
        if tokens.count >= 2 {
            for index in 0..<(tokens.count - 1) {
                pairs.insert(tokens[index] + tokens[index + 1])
            }
        }
        for rule in rules {
            if rule.matches(tokens: tokens, pairs: pairs) {
                return rule.vendor
            }
        }
        return nil
    }
    
    static func manufacturer(fromBonjour info: BonjourHostInfo) -> String? {
        if let raw = info.manufacturerLabel {
            if let mapped = manufacturer(from: raw) { return mapped }
            if let cleaned = acceptableRawVendor(raw) { return cleaned }
        }
        if let fromService = DeviceFingerprint.manufacturer(services: info.serviceTypes, txt: info.txt) {
            return fromService
        }
        if let model = info.modelLabel {
            return manufacturer(from: model)
        }
        return nil
    }
    
    /// Raw TXT makes such as "HP" are kept. Numeric junk like "0,1,2" is not a vendor.
    private static func acceptableRawVendor(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = trimmed.filter(\.isLetter).count
        guard letters >= 2, trimmed.count <= 60, !trimmed.contains("://") else { return nil }
        let digits = trimmed.filter(\.isNumber).count
        guard digits * 2 < trimmed.count else { return nil }
        return trimmed
    }
    
    static func tokenize(_ name: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for scalar in name.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
    
    private struct Rule {
        let vendor: String
        var exact: Set<String> = []
        var prefixes: [String] = []
        var pairs: Set<String> = []
        var requiresDigitAfterPrefix: [String] = []
        
        func matches(tokens: [String], pairs joined: Set<String>) -> Bool {
            if tokens.contains(where: { exact.contains($0) }) { return true }
            if joined.contains(where: { pair in
                pairs.contains(where: { pair == $0 || pair.hasPrefix($0) })
            }) { return true }
            for token in tokens {
                if prefixes.contains(where: { token.hasPrefix($0) }) { return true }
                for prefix in requiresDigitAfterPrefix where token.hasPrefix(prefix) && token.count > prefix.count {
                    if token.dropFirst(prefix.count).contains(where: \.isNumber) { return true }
                }
            }
            return false
        }
    }
    
    /// First match wins. Brand-specific rules stay ahead of the generic "android" fallback.
    private static let rules: [Rule] = [
        Rule(vendor: "Apple, Inc.", exact: [
            "apple", "iphone", "ipad", "ipod", "mac", "macbook", "macbookpro", "macbookair",
            "imac", "macmini", "macstudio", "macpro", "macintosh", "macos", "appletv", "homepod"
        ], prefixes: ["macbook", "imac"]),
        Rule(vendor: "Samsung Electronics", exact: ["samsung", "galaxy"], prefixes: ["samsung", "galaxy"]),
        Rule(vendor: "AVM GmbH", exact: ["fritz", "fritzbox", "avm"], prefixes: ["fritz"]),
        Rule(vendor: "Sonos, Inc.", exact: ["sonos"], prefixes: ["sonos"]),
        Rule(vendor: "Allterco Robotics (Shelly)", exact: ["shelly"], prefixes: ["shelly"]),
        Rule(
            vendor: "Espressif Inc.",
            exact: ["esp", "espressif", "esphome", "espresense", "tasmota", "wled"],
            prefixes: ["espressif", "esphome"],
            requiresDigitAfterPrefix: ["esp"]
        ),
        Rule(
            vendor: "HP Inc.",
            exact: ["hp", "hewlett", "laserjet", "officejet", "deskjet"],
            prefixes: ["laserjet", "officejet", "deskjet"]
        ),
        Rule(vendor: "Brother Industries, Ltd.", exact: ["brother"], prefixes: ["brother"]),
        Rule(vendor: "Seiko Epson Corporation", exact: ["epson"], prefixes: ["epson"]),
        Rule(vendor: "Synology Incorporated", exact: ["synology", "diskstation"], prefixes: ["synology", "diskstation"]),
        Rule(vendor: "QNAP Systems, Inc.", exact: ["qnap"], prefixes: ["qnap"]),
        Rule(vendor: "Raspberry Pi Foundation", exact: ["raspberry", "raspberrypi", "homeassistant"], prefixes: ["raspberry"]),
        Rule(vendor: "Pi-hole", exact: ["pihole"], pairs: ["pihole"]),
        Rule(vendor: "OctoPrint", exact: ["octoprint"]),
        Rule(vendor: "ASUSTek COMPUTER INC.", exact: ["asus", "asustek"], prefixes: ["asus"], pairs: ["gtax"]),
        Rule(vendor: "Ubiquiti Inc.", exact: ["ubiquiti", "unifi", "ubnt"], prefixes: ["unifi", "ubiquiti"]),
        Rule(vendor: "TP-Link Technologies", exact: ["tplink"], pairs: ["tplink"]),
        Rule(vendor: "NETGEAR", exact: ["netgear", "orbi"], prefixes: ["netgear"]),
        Rule(vendor: "Google, Inc.", exact: ["google", "nest", "chromecast", "androidtv"], prefixes: ["chromecast"]),
        Rule(vendor: "Amazon Technologies Inc.", exact: ["amazon", "kindle", "echo", "firetv", "alexa"], prefixes: ["firetv"]),
        Rule(vendor: "Xiaomi Communications", exact: ["xiaomi", "redmi"], prefixes: ["xiaomi", "redmi"]),
        Rule(vendor: "Huawei Technologies", exact: ["huawei"], prefixes: ["huawei"]),
        Rule(vendor: "Philips", exact: ["philips", "hue"], prefixes: ["philips"]),
        Rule(vendor: "IKEA of Sweden AB", exact: ["ikea"], prefixes: ["ikea"]),
        Rule(vendor: "Canon Inc.", exact: ["canon"]),
        Rule(vendor: "Microsoft Corporation", exact: ["microsoft", "xbox"], prefixes: ["xbox"]),
        Rule(vendor: "Dell Inc.", exact: ["dell"], prefixes: ["dell"]),
        Rule(vendor: "Lenovo", exact: ["lenovo", "thinkpad"], prefixes: ["lenovo", "thinkpad"]),
        Rule(vendor: "Reolink", exact: ["reolink"], prefixes: ["reolink"]),
        Rule(vendor: "Bosch", exact: ["bosch"], prefixes: ["bosch"]),
        Rule(vendor: "Sony Corporation", exact: ["sony", "bravia"], prefixes: ["sony", "bravia"]),
        Rule(vendor: "Android", exact: ["android"])
    ]
}
