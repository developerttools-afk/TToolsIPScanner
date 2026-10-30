import SwiftUI

#if os(iOS)
struct MobileLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    @State private var showRouterMACSettings = false
    @State private var showDNSCacheSettings = false
    @State private var showUserGuide = false
    @State private var showAbout = false
    @State private var showScanSettings = false
    @State private var networkInfoExpanded = false
    @State private var detailDevice: DeviceInfo?
    @State private var serviceDevice: DeviceInfo?
    
    private var collapsedNetworkLabel: String {
        let address = scanner.currentNetwork.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty { return address }
        return scanner.networkRange
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
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var networkAndScan: some View {
        VStack(alignment: .leading, spacing: 8) {
            if networkInfoExpanded {
                NetworkInputView(scanner: scanner, showsCaption: false)
            }
            ScanButton(scanner: scanner)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                ScanPhaseStrip(phase: scanner.scanPhase)
                    .equatable()
                if scanner.isScanning || scanner.scanPhase == .finished {
                    ScanStatusView(scanner: scanner, includePhases: false)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ScannerGlassPlate(cornerRadius: 14)
                    .equatable()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    networkAndScan
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Button(action: { withAnimation { networkInfoExpanded.toggle() } }) {
                        HStack(spacing: 8) {
                            Text("Netzwerk")
                                .font(.headline)
                            if !networkInfoExpanded {
                                Text(collapsedNetworkLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: networkInfoExpanded ? "chevron.down" : "chevron.right")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    HStack(spacing: 8) {
                        sortHeaderButton(for: .ip, label: "IP")
                        Spacer()
                        sortHeaderButton(for: .hostname, label: "Host")
                        Spacer()
                        sortHeaderButton(for: .manufacturer, label: "Hersteller")
                    }
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 0, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
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
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(scanner.devices) { device in
                            DeviceServiceRow(
                                device: device,
                                displayName: scanner.displayName(for: device),
                                onOpenServices: { serviceDevice = device },
                                onShowDetail: { detailDevice = device }
                            )
                        }
                    }
                    let legend = DeviceBadges.legend(for: scanner.devices)
                    if !legend.isEmpty {
                        Text(legend.map { "\($0.letter) \($0.name)" }.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
            .scrollContentBackground(.hidden)
            .background(ScannerBackdrop())
            .navigationTitle("TToolsIPScanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $detailDevice) { device in
                DeviceDetailView(device: device, scanner: scanner)
            }
            .confirmationDialog(
                "Dienst öffnen",
                isPresented: serviceDialogPresented,
                titleVisibility: .visible,
                presenting: serviceDevice
            ) { device in
                let actions = openActions(for: device)
                ForEach(actions) { action in
                    Button(action.title) {
                        scanner.openService(action)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: { device in
                let actions = openActions(for: device)
                if actions.isEmpty {
                    Text("Für \(scanner.displayName(for: device)) gibt es keinen Dienst zum Öffnen.")
                } else {
                    Text(scanner.displayName(for: device))
                }
            }
            .onAppear {
                LocalNetworkAccess.requestIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showScanSettings = true }) {
                            Label("Scan", systemImage: "dot.radiowaves.left.and.right")
                        }
                        
                        Button(action: { showPortEditor = true }) {
                            Label("Port-Einstellungen", systemImage: "gearshape")
                        }
                        
                        Button(action: { showOUIDatabaseSettings = true }) {
                            Label("OUI-Datenbank", systemImage: "server.rack")
                        }
                        
                        Button(action: { showRouterMACSettings = true }) {
                            Label("Router & MAC", systemImage: "network")
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
            .sheet(isPresented: $showScanSettings) {
                NavigationStack {
                    ScanSettingsView(scanner: scanner)
                }
            }
            .sheet(isPresented: $showPortEditor) {
                NavigationStack {
                    PortEditorView(ports: scanner.customPorts) { newPorts in
                        scanner.updateCustomPorts(newPorts)
                    }
                }
            }
            .sheet(isPresented: $showRouterMACSettings) {
                NavigationStack {
                    RouterMACSettingsView(scanner: scanner)
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
        }
    }
    
    private var serviceDialogPresented: Binding<Bool> {
        Binding(
            get: { serviceDevice != nil },
            set: { if !$0 { serviceDevice = nil } }
        )
    }
    
    private func openActions(for device: DeviceInfo) -> [NetworkConstants.ServiceOpenAction] {
        NetworkConstants.openActions(
            ip: device.ipAddress,
            openPorts: device.openPorts,
            advertisedServices: device.advertisedServices
        )
    }
}

/// Kurz tippen oder nach links wischen: Dienst wählen. Lang drücken oder nach rechts wischen: Details.
private struct DeviceServiceRow: View {
    let device: DeviceInfo
    let displayName: String
    let onOpenServices: () -> Void
    let onShowDetail: () -> Void
    @State private var longPressOpenedDetail = false
    @State private var detailHaptic = 0
    
    var body: some View {
        Button(action: handleTap) {
            DeviceRowView(device: device, displayName: displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                longPressOpenedDetail = true
                detailHaptic += 1
                onShowDetail()
            }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: detailHaptic)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onOpenServices) {
                Label("Öffnen", systemImage: "arrow.up.forward.app")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onShowDetail) {
                Label("Details", systemImage: "info.circle")
            }
            .tint(.indigo)
        }
        .accessibilityHint("Tippen oder nach links wischen wählt einen Dienst. Lang drücken oder nach rechts wischen öffnet die Details.")
        .accessibilityAction(named: "Dienst öffnen", onOpenServices)
        .accessibilityAction(named: "Details", onShowDetail)
    }
    
    private func handleTap() {
        if longPressOpenedDetail {
            longPressOpenedDetail = false
            return
        }
        onOpenServices()
    }
}
#endif
