import SwiftUI

#if os(iOS)
struct MobileLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    @State private var showDNSCacheSettings = false
    @State private var showUserGuide = false
    
    private var fullScanBinding: Binding<Bool> {
        Binding(
            get: { scanner.preferredScanMode == .fullScan },
            set: { scanner.preferredScanMode = $0 ? .fullScan : .quickScan }
        )
    }
    
    private var activeDeviceCount: Int {
        scanner.devices.filter { $0.status != .missing }.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        NetworkInputView(scanner: scanner)
                        Toggle("Vollständiger Port-Scan", isOn: fullScanBinding)
                            .disabled(scanner.isScanning)
                        ScanButton(scanner: scanner)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                
                if scanner.isScanning || scanner.scanPhase == .finished {
                    Section {
                        ScanStatusView(scanner: scanner)
                    }
                }
                
                Section {
                    HStack(spacing: 12) {
                        Picker("Sortieren nach", selection: $scanner.sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        
                        Menu {
                            Button(action: { scanner.sortAscending = true }) {
                                Label("Aufsteigend", systemImage: "arrow.up")
                            }
                            Button(action: { scanner.sortAscending = false }) {
                                Label("Absteigend", systemImage: "arrow.down")
                            }
                        } label: {
                            Image(systemName: scanner.sortAscending ? "arrow.up" : "arrow.down")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Section {
                    if scanner.devices.isEmpty {
                        ContentUnavailableView {
                            Label(
                                scanner.isScanning ? "Suche läuft…" : "Keine Geräte",
                                systemImage: scanner.isScanning ? "antenna.radiowaves.left.and.right" : "wifi.slash"
                            )
                        } description: {
                            Text(
                                scanner.isScanning
                                    ? "Gefundene Hosts erscheinen hier."
                                    : "Scan starten. Bei der ersten Nutzung „Lokales Netzwerk“ erlauben."
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(scanner.devices) { device in
                            NavigationLink {
                                DeviceDetailView(device: device, scanner: scanner)
                            } label: {
                                DeviceRowView(
                                    device: device,
                                    displayName: scanner.displayName(for: device)
                                )
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Gefundene Geräte")
                        Spacer()
                        if !scanner.devices.isEmpty {
                            Text("\(activeDeviceCount) aktiv")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("IP Scanner")
            .onAppear {
                LocalNetworkAccess.requestIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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
                        
                        Button(action: { scanner.updateOUIDatabase(useFullList: false) }) {
                            Label("OUI-Liste aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        Button(action: { scanner.updateOUIDatabase(useFullList: true) }) {
                            Label("Vollständige OUI-Liste laden", systemImage: "arrow.down.circle")
                        }
                        
                        Divider()
                        
                        Button(action: { showUserGuide = true }) {
                            Label("Bedienungsanleitung", systemImage: "questionmark.circle")
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
            .sheet(isPresented: $showOUIDatabaseSettings) {
                NavigationStack {
                    OUIDatabaseSettingsView(scanner: scanner)
                }
            }
            .sheet(isPresented: $showDNSCacheSettings) {
                NavigationStack {
                    DNSCacheSettingsView(scanner: scanner)
                }
            }
            .sheet(isPresented: $showUserGuide) {
                NavigationStack {
                    UserGuideView()
                }
            }
        }
    }
}
#endif
