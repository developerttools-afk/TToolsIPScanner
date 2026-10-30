import SwiftUI

#if os(macOS)
struct DesktopLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @AppStorage("tableSettings") private var tableSettings = TableSettings.default
    @AppStorage("didMigrateTableColumnCustomization") private var didMigrateTableColumns = false
    @SceneStorage("ResultsTableColumnCustomization")
    private var columnCustomization = TableColumnCustomization<DeviceInfo>()
    @State private var showTableSettings = false
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    @State private var showRouterMACSettings = false
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
        ZStack {
            ScannerBackdrop()
            
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    NetworkInputView(scanner: scanner)
                    HStack(spacing: 12) {
                        ScanButton(scanner: scanner)
                        Spacer(minLength: 12)
                        Picker("Host-Suche", selection: $scanner.preferredDiscoveryDepth) {
                            ForEach(DiscoveryDepth.allCases) { depth in
                                Text(depth.displayName).tag(depth)
                            }
                        }
                        .frame(width: 180)
                        .disabled(scanner.isScanning)
                        Toggle("Vollständiger Port-Scan", isOn: fullScanBinding)
                            .disabled(scanner.isScanning)
                    }
                }
                .padding(16)
                .background {
                    ScannerGlassPlate()
                }
                
                if scanner.isScanning || scanner.scanPhase == .finished {
                    ScanStatusView(scanner: scanner)
                        .padding(.horizontal, 8)
                }
                
                VStack(spacing: 0) {
                    ResultsTableView(
                        scanner: scanner,
                        sortOrder: $sortOrder,
                        columnCustomization: $columnCustomization
                    )
                    .scrollContentBackground(.hidden)
                    
                    let legend = DeviceBadges.legend(for: scanner.devices)
                    if !legend.isEmpty {
                        Text(legend.map { "\($0.letter) \($0.name)" }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            }
            .padding(16)
        }
        .navigationTitle("TToolsIPScanner")
        .onAppear(perform: migrateLegacyColumnVisibilityIfNeeded)
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
                    
                    Button(action: { showRouterMACSettings = true }) {
                        Label("Router & MAC", systemImage: "network")
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
                TableSettingsView(
                    settings: $tableSettings,
                    columnCustomization: $columnCustomization
                )
            }
        }
        .sheet(isPresented: $showRouterMACSettings) {
            NavigationStack {
                RouterMACSettingsView(scanner: scanner)
                    .frame(minWidth: 460, minHeight: 520)
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
    
    private func migrateLegacyColumnVisibilityIfNeeded() {
        guard !didMigrateTableColumns else { return }
        didMigrateTableColumns = true
        
        for column in TableSettings.ColumnType.allCases where column != .portSymbols {
            let visible = tableSettings.visibleColumns.contains(column)
                || (column == .ports && tableSettings.visibleColumns.contains(.portSymbols))
            columnCustomization[visibility: column.customizationID] = visible ? .visible : .hidden
        }
    }
}
#endif
