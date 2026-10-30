import SwiftUI

/// List row: name / IP / manufacturer (left), ports / MAC (right) — iOS LAN-scanner style.
struct DeviceRowView: View {
    let device: DeviceInfo
    var displayName: String? = nil
    
    private var resolvedName: String {
        let name = displayName ?? device.hostName
        if name.hasPrefix("Gerät .") { return name }
        return name.isEmpty ? device.ipAddress : name
    }
    
    private var manufacturerLine: String {
        if !device.manufacturer.isEmpty, device.manufacturer != "Unbekannt" {
            return device.manufacturer
        }
        if device.category != .unknown {
            return device.category.displayName
        }
        #if os(iOS)
        if device.macAddress.isEmpty {
            return "Unbekannt (ohne MAC)"
        }
        #endif
        return "N/A"
    }
    
    private var macLine: String {
        if !device.macAddress.isEmpty { return device.macAddress }
        #if os(iOS)
        return "Keine MAC (iOS)"
        #else
        return "N/A"
        #endif
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusIndicator(status: device.status)
                .padding(.top, 3)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedName)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(device.status == .missing ? .secondary : .primary)
                
                Text(device.ipAddress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                
                if !device.ipv6Address.isEmpty, device.ipv6Address != device.ipAddress {
                    Text(device.ipv6Address)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(manufacturerLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    DiscoveryBadges(device: device)
                    if !device.openPorts.isEmpty {
                        PortsPreview(ports: device.openPorts)
                    }
                }
                
                Text(macLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(device.macAddress.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Compact discovery-source letters (similar to Network Analyzer).
struct DiscoveryBadges: View {
    let device: DeviceInfo
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(sources, id: \.letter) { source in
                Text(source.letter)
                    .font(.caption2.weight(.bold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(source.color)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(source.color.opacity(0.22))
                            }
                    }
                    .help(source.help)
            }
        }
    }
    
    private struct Source {
        let letter: String
        let color: Color
        let help: String
    }
    
    private var sources: [Source] {
        DeviceBadges.discovery(for: device).map { mark in
            Source(letter: mark.letter, color: color(for: mark.letter), help: mark.help)
        }
    }
    
    private func color(for letter: String) -> Color {
        switch letter {
        case "G": return .red
        case "W": return .blue
        case "B": return .orange
        case "U": return .cyan
        case "N": return .purple
        case "D": return .green
        case "P": return .mint
        default: return .secondary
        }
    }
}
