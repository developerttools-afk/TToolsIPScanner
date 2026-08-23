import SwiftUI

struct PortDetailRow: View {
    let port: Int
    @ObservedObject var scanner: NetworkScanner
    
    var body: some View {
        HStack {
            Text(NetworkConstants.portLetter(for: port))
                .font(.body.monospaced().weight(.semibold))
                .foregroundStyle(scanner.getPortSymbol(port)?.color ?? .blue)
                .frame(minWidth: 16, alignment: .center)
            if let symbolInfo = scanner.getPortSymbol(port) {
                Image(systemName: symbolInfo.symbol)
                    .foregroundColor(symbolInfo.color)
            }
            Text("\(port)")
                .font(.system(.body, design: .monospaced))
            Text(scanner.getPortDescription(port))
                .foregroundColor(.secondary)
        }
    }
} 