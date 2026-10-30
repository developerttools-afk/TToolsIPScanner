import Foundation

/// Letters drawn on a device row: uppercase discovery marks, then lowercase port badges.
enum DeviceBadges {
    struct Mark: Equatable {
        var letter: String
        var name: String
        var help: String
    }
    
    static func discovery(for device: DeviceInfo) -> [Mark] {
        var list: [Mark] = []
        if device.category == .router || device.ipAddress.hasSuffix(".1") {
            list.append(Mark(letter: "G", name: "Gateway", help: "Gateway / Router"))
        }
        if device.openPorts.contains(where: { [80, 443, 8080, 8443].contains($0) }) {
            list.append(Mark(letter: "W", name: "Web-Dienst", help: "Web-Dienst (HTTP/HTTPS)"))
        }
        if !device.bonjourName.isEmpty || !device.mdnsName.isEmpty
            || device.advertisedServices.contains(where: { $0 != "upnp" && !$0.isEmpty }) {
            list.append(Mark(letter: "B", name: "Bonjour", help: "Bonjour / mDNS"))
        }
        if device.advertisedServices.contains("upnp") {
            list.append(Mark(letter: "U", name: "UPnP", help: "UPnP / SSDP"))
        }
        if !device.netbiosName.isEmpty {
            list.append(Mark(letter: "N", name: "NetBIOS", help: "NetBIOS / SMB"))
        }
        if !device.dnsName.isEmpty {
            list.append(Mark(letter: "D", name: "DNS", help: "DNS-Name"))
        }
        if device.status != .missing {
            list.append(Mark(letter: "P", name: "Erreichbar", help: "Erreichbar"))
        }
        return list
    }
    
    /// Every badge letter that the device list actually draws, discovery marks first.
    static func legend(for devices: [DeviceInfo]) -> [Mark] {
        let order = ["G", "W", "B", "U", "N", "D", "P"]
        var present: [String: Mark] = [:]
        for device in devices {
            for mark in discovery(for: device) {
                present[mark.letter] = mark
            }
        }
        var items = order.compactMap { present[$0] }
        let ports = devices.flatMap(\.openPorts)
        for entry in NetworkConstants.portLetterLegend(for: ports) {
            items.append(Mark(letter: entry.letter, name: entry.name, help: entry.name))
        }
        return items
    }
}
