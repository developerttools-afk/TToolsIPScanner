import SwiftUI

struct PortsPreview: View {
    let ports: [Int]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ports.prefix(8).sorted(), id: \.self) { port in
                Text("\(port)")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(4)
                    .help(NetworkConstants.portDescriptions[port] ?? "Port \(port)")
            }
            if ports.count > 8 {
                Text("+\(ports.count - 8)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
