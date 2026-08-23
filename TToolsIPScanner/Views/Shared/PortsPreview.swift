import SwiftUI

struct PortsPreview: View {
    let ports: [Int]
    
    var body: some View {
        HStack(spacing: 4) {
            if ports.isEmpty {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Keine offenen Ports")
            } else {
                ForEach(ports.prefix(10).sorted(), id: \.self) { port in
                    Text(NetworkConstants.portLetter(for: port))
                        .font(.caption.monospaced().weight(.semibold))
                        .textCase(.lowercase)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeColor(for: port).opacity(0.16))
                        .foregroundStyle(badgeColor(for: port))
                        .cornerRadius(4)
                        .help(NetworkConstants.portBadgeHelp(for: port))
                        .accessibilityLabel(NetworkConstants.portBadgeHelp(for: port))
                }
                if ports.count > 10 {
                    Text("+\(ports.count - 10)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func badgeColor(for port: Int) -> Color {
        NetworkConstants.portSymbols[port]?.color ?? .blue
    }
}
