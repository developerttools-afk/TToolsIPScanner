import SwiftUI

#if os(iOS)
struct MobileLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    @State private var showDNSCacheSettings = false
    @State private var showUserGuide = false
    @State private var showAbout = false
    @State private var showAPWarning = false
    @State private var networkInfoExpanded = true
    @State private var scanSettingsExpanded = true
    
    private var fullScanBinding: Binding<Bool> {
        Binding(
            get: { scanner.preferredScanMode == .fullScan },
            set: { scanner.preferredScanMode = $0 ? .fullScan : .quickScan }
        )
    }
    
    private var activeDeviceCount: Int {
        scanner.devices.filter { $0.status != .missing }.count
    }
    
    private func sortHeaderButton(for option: SortOption, label: String) -> some View {
        Button(action: {
            if scanner.sortOption == option {
                scanner.sortAscending.toggle()
            } else {
                scanner.sortOption = option
                scanner.sortAscending = true
            }
        }) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(scanner.sortOption == option ? .semibold : .regular)
                if scanner.sortOption == option {
                    Image(systemName: scanner.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Collapsible: Aktuelles Netzwerk
                Section {
                    if networkInfoExpanded {
                        NetworkInputView(scanner: scanner)
                    }
                } header: {
                    Button(action: { withAnimation { networkInfoExpanded.toggle() } }) {
                        HStack {
                            Text("Aktuelles Netzwerk")
                                .font(.headline)
                            Spacer()
                            Image(systemName: networkInfoExpanded ? "chevron.down" : "chevron.right")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // Collapsible: Scan-Einstellungen
                Section {
                    if scanSettingsExpanded {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Vollständiger Port-Scan", isOn: fullScanBinding)
                                .disabled(scanner.isScanning)
                            ScanButton(scanner: scanner)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                } header: {
                    Button(action: { withAnimation { scanSettingsExpanded.toggle() } }) {
                        HStack {
                            Text("Scan-Einstellungen")
                                .font(.headline)
                            Spacer()
                            Image(systemName: scanSettingsExpanded ? "chevron.down" : "chevron.right")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                if scanner.isScanning || scanner.scanPhase == .finished {
                    Section {
                        ScanStatusView(scanner: scanner)
                    }
                }
                
                // Sortierung durch Tap auf Header
                Section {
                    HStack(spacing: 8) {
                        sortHeaderButton(for: .ip, label: "IP")
                        Spacer()
                        sortHeaderButton(for: .hostname, label: "Host")
                        Spacer()
                        sortHeaderButton(for: .manufacturer, label: "Hersteller")
                    }
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
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
            .sheet(isPresented: $showAbout) {
                NavigationStack {
                    AboutView()
                }
            }
            .sheet(isPresented: $showAPWarning) {
                APWarningView(isPresented: $showAPWarning)
            }
        }
    }
}
#endif
