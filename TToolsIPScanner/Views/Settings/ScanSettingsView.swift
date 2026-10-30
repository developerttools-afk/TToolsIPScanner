import SwiftUI

/// Host-Suche und Port-Umfang. Auf iOS aus dem Hauptbildschirm ausgelagert.
struct ScanSettingsView: View {
    @ObservedObject var scanner: NetworkScanner
    @Environment(\.dismiss) private var dismiss
    
    private var fullScanBinding: Binding<Bool> {
        Binding(
            get: { scanner.preferredScanMode == .fullScan },
            set: { scanner.preferredScanMode = $0 ? .fullScan : .quickScan }
        )
    }
    
    var body: some View {
        Form {
            Section {
                Picker("Host-Suche", selection: $scanner.preferredDiscoveryDepth) {
                    ForEach(DiscoveryDepth.allCases) { depth in
                        Text(depth.displayName).tag(depth)
                    }
                }
                .disabled(scanner.isScanning)
            } footer: {
                Text("Schnell prüft wenige Ports, Normal die übliche Auswahl, Gründlich sucht länger nach stillen Hosts.")
            }
            
            Section {
                Toggle("Vollständiger Port-Scan", isOn: fullScanBinding)
                    .disabled(scanner.isScanning)
            } footer: {
                Text("Ergänzt weitere Standard-Ports. Sonst gelten die Ports aus den Port-Einstellungen, oder 21, 22, 80 und 443.")
            }
            
            Section {
                Toggle("IPv6 scannen", isOn: $scanner.scanIPv6)
                    .disabled(scanner.isScanning)
            } footer: {
                Text("Sucht IPv6-Nachbarn per Multicast-Ping und Nachbartabelle. Ein /64 wird nicht Adresse für Adresse geprüft. Aus, solange du es nicht einschaltest.")
            }
        }
        .navigationTitle("Scan")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }
}
