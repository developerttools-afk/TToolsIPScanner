import SwiftUI

struct ScanButton: View {
    @ObservedObject var scanner: NetworkScanner
    
    var body: some View {
        Button(action: {
            if scanner.isScanning {
                scanner.stopScan()
            } else {
                scanner.startScan(
                    baseIP: scanner.currentNetwork,
                    mode: scanner.preferredScanMode
                )
            }
        }) {
            HStack {
                Image(systemName: scanner.isScanning ? "stop.fill" : "play.fill")
                Text(scanner.isScanning ? "Stopp" : "Scan starten")
            }
            .foregroundColor(scanner.isScanning ? .red : .green)
        }
        .buttonStyle(.bordered)
    }
}
