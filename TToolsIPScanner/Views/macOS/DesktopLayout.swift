import SwiftUI

#if os(macOS)
import AppKit

struct DesktopLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @AppStorage("tableSettings") private var tableSettings = TableSettings.default
    @State private var showTableSettings = false
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    @State private var showDNSCacheSettings = false
    @State private var showUserGuide = false
    @State private var showAbout = false
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
                    
                    Button(action: { showDNSCacheSettings = true }) {
                        Label("DNS-Cache", systemImage: "memorychip")
                    }
                    
                    Divider()
                    
                    Button(action: { showUserGuide = true }) {
                        Label("Bedienungsanleitung", systemImage: "questionmark.circle")
                    }
                    
                    Button(action: { showAbout = true }) {
                        Label("Über diese App", systemImage: "info.circle")
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
        .sheet(isPresented: $showDNSCacheSettings) {
            NavigationStack {
                DNSCacheSettingsView(scanner: scanner)
                    .frame(minWidth: 400, minHeight: 500)
            }
        }
        .sheet(isPresented: $showUserGuide) {
            NavigationStack {
                UserGuideView()
                    .frame(minWidth: 420, minHeight: 480)
            }
        }
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView()
                    .frame(minWidth: 500, minHeight: 600)
            }
        }
    }
}
#endif
