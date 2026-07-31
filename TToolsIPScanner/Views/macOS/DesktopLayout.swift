import SwiftUI

#if os(macOS)
import AppKit

struct DesktopLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @AppStorage("tableSettings") private var tableSettings = TableSettings.default
    @State private var showTableSettings = false
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    @State private var sortOrder = [KeyPathComparator(\DeviceInfo.ipAddress)]
    
    private var fullScanBinding: Binding<Bool> {
        Binding(
            get: { scanner.preferredScanMode == .fullScan },
            set: { scanner.preferredScanMode = $0 ? .fullScan : .quickScan }
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                NetworkInputView(scanner: scanner)
                HStack {
                    ScanButton(scanner: scanner)
                    Spacer()
                    Toggle("Vollständiger Port-Scan", isOn: fullScanBinding)
                        .disabled(scanner.isScanning)
                }
                
                if scanner.isScanning || scanner.scanPhase == .finished {
                    ScanStatusView(scanner: scanner)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            ResultsTableView(scanner: scanner, sortOrder: $sortOrder)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button(action: { showTableSettings = true }) {
                        Label("Spalten anzeigen/ausblenden", systemImage: "table")
                    }
                    
                    Button(action: { showPortEditor = true }) {
                        Label("Port-Einstellungen", systemImage: "gearshape")
                    }
                    
                    Button(action: { showOUIDatabaseSettings = true }) {
                        Label("OUI-Datenbank", systemImage: "server.rack")
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showPortEditor) {
            NavigationStack {
                PortEditorView(ports: scanner.customPorts) { newPorts in
                    scanner.updateCustomPorts(newPorts)
                }
            }
        }
        .sheet(isPresented: $showTableSettings) {
            NavigationStack {
                TableSettingsView(settings: $tableSettings)
            }
        }
        .sheet(isPresented: $showOUIDatabaseSettings) {
            NavigationStack {
                OUIDatabaseSettingsView(scanner: scanner)
            }
        }
    }
}
#endif
