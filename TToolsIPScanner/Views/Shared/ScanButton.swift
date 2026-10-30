import SwiftUI

struct ScanButton: View {
    @ObservedObject var scanner: NetworkScanner
    
    private var isBusy: Bool {
        scanner.isScanning || scanner.devicePortScanIP != nil
    }
    
    var body: some View {
        ScanButtonChrome(isBusy: isBusy) {
            if scanner.isScanning {
                scanner.stopScan()
            } else if scanner.devicePortScanIP != nil {
                scanner.stopDevicePortScan()
            } else {
                scanner.startScan(
                    baseIP: scanner.currentNetwork,
                    mode: scanner.preferredScanMode
                )
            }
        }
        .equatable()
    }
}

/// Glass is skipped while the scan publishes progress, so the effect is not sampled twice per frame.
private struct ScanButtonChrome: View, Equatable {
    let isBusy: Bool
    let action: () -> Void
    
    static func == (lhs: ScanButtonChrome, rhs: ScanButtonChrome) -> Bool {
        lhs.isBusy == rhs.isBusy
    }
    
    var body: some View {
        Button(action: action) {
            Label(isBusy ? "Stopp" : "Scan starten", systemImage: isBusy ? "stop.fill" : "play.fill")
        }
        .tint(isBusy ? .red : .green)
        .scannerGlassButton(prominent: true)
    }
}
