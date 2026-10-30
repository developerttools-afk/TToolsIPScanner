import SwiftUI

struct PortsPreview: View {
    let ports: [Int]
    var ipAddress: String = ""
    var onOpen: ((NetworkConstants.ServiceOpenAction) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if ports.isEmpty {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Keine offenen Ports")
            } else {
                ForEach(ports.prefix(10).sorted(), id: \.self) { port in
                    badge(for: port)
                }
                if ports.count > 10 {
                    Text("+\(ports.count - 10)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func badge(for port: Int) -> some View {
        if let onOpen, let action = NetworkConstants.openAction(ip: ipAddress, port: port) {
            Button {
                onOpen(action)
            } label: {
                badgeLabel(for: port)
            }
            .buttonStyle(.borderless)
            .help("\(action.title) öffnen")
            .accessibilityLabel("\(action.title) öffnen")
            #if os(macOS)
            .pointerStyle(.link)
            #endif
        } else {
            badgeLabel(for: port)
                .help(NetworkConstants.portBadgeHelp(for: port))
                .accessibilityLabel(NetworkConstants.portBadgeHelp(for: port))
        }
    }
    
    private func badgeLabel(for port: Int) -> some View {
        Text(NetworkConstants.portLetter(for: port))
            .font(.caption.monospaced().weight(.semibold))
            .textCase(.lowercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(badgeColor(for: port))
            .background {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule().fill(badgeColor(for: port).opacity(0.22))
                    }
            }
    }
    
    private func badgeColor(for port: Int) -> Color {
        NetworkConstants.portSymbols[port]?.color ?? .blue
    }
}
