import Foundation

/// Hardware and product names learned without a MAC.
/// A real OUI still wins. These strings only replace placeholders,
/// and a chip or board vendor may replace a softer product name.
enum DeviceFingerprint {
    static let raspberryPi = "Raspberry Pi Foundation"
    static let espressif = "Espressif Inc."
    static let homeAssistant = "Home Assistant"
    static let piHole = "Pi-hole"
    static let octoPrint = "OctoPrint"
    
    private static let productNames: Set<String> = [homeAssistant, piHole, octoPrint]
    private static let boardVendors: Set<String> = [raspberryPi, espressif]
    
    /// SSH banner, HTTP server/title, mDNS service type, or a well-known port.
    static func manufacturer(
        text: String = "",
        services: [String] = [],
        ports: [Int] = [],
        txt: [String: String] = [:]
    ) -> String? {
        let blob = text.lowercased()
        if blob.contains("raspbian") || blob.contains("raspberry pi") || blob.contains("raspberrypi") {
            return raspberryPi
        }
        
        let types = services.map { $0.lowercased() }
        let board = (txt["board"] ?? "").lowercased()
        if types.contains(where: { $0.contains("_arduino") }), board.contains("esp") {
            return espressif
        }
        if types.contains(where: { $0.contains("_esphome") || $0.contains("_tasmota") || $0.contains("_wled") }) {
            return espressif
        }
        if blob.contains("tasmota") || blob.contains("wled") || blob.contains("esphome")
            || blob.contains("esp32") || blob.contains("esp8266") {
            return espressif
        }
        if ports.contains(6053) {
            return espressif
        }
        if blob.contains("pi-hole") || blob.contains("pihole") {
            return piHole
        }
        if blob.contains("octoprint") {
            return octoPrint
        }
        if types.contains(where: { $0.contains("_home-assistant") || $0.contains("_hassio") })
            || ports.contains(8123)
            || blob.contains("home assistant") {
            return homeAssistant
        }
        return nil
    }
    
    static func osHint(fromSSH banner: String) -> String? {
        if manufacturer(text: banner) == raspberryPi {
            return "Raspberry Pi OS"
        }
        if banner.lowercased().contains("openssh") {
            return "OpenSSH"
        }
        return nil
    }
    
    /// A Raspberry Pi or Espressif hit may replace Home Assistant, Pi-hole, or OctoPrint.
    static func replaces(current: String, with proposed: String) -> Bool {
        boardVendors.contains(proposed) && productNames.contains(current)
    }
    
    /// A product title is more useful than a generic Server header such as lighttpd.
    static func httpDetail(server: String?, title: String?) -> String? {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedServer = server?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty, manufacturer(text: trimmedTitle) != nil {
            return trimmedTitle
        }
        if !trimmedServer.isEmpty { return trimmedServer }
        return trimmedTitle.isEmpty ? nil : trimmedTitle
    }
}
