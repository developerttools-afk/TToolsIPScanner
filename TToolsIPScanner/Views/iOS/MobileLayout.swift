import SwiftUI

#if os(iOS)
struct MobileLayout: View {
    @ObservedObject var scanner: NetworkScanner
    @State private var showPortEditor = false
    @State private var showOUIDatabaseSettings = false
    
    private var fullScanBinding: Binding<Bool> {
        Binding(
            get: { scanner.preferredScanMode == .fullScan },
            set: { scanner.preferredScanMode = $0 ? .fullScan : .quickScan }
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        NetworkInputView(scanner: scanner)
                        Toggle("Vollständiger Port-Scan", isOn: fullScanBinding)
                            .disabled(scanner.isScanning)
                        ScanButton(scanner: scanner)
                    }
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
                        .frame(maxWidth: .infinity)
                        
                        Menu {
                            Button(action: { scanner.sortAscending = true }) {
                                Label("Aufsteigend", systemImage: "arrow.up")
                                    .foregroundColor(scanner.sortAscending ? .accentColor : .primary)
                            }
                            
                            Button(action: { scanner.sortAscending = false }) {
                                Label("Absteigend", systemImage: "arrow.down")
                                    .foregroundColor(!scanner.sortAscending ? .accentColor : .primary)
                            }
                        } label: {
                            Image(systemName: scanner.sortAscending ? "arrow.up" : "arrow.down")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                    
                    ForEach(scanner.devices) { device in
                        NavigationLink {
                            DeviceDetailView(device: device, scanner: scanner)
                        } label: {
                            DeviceRowView(device: device)
                        }
                    }
                } header: {
                    if !scanner.devices.isEmpty {
                        HStack {
                            Text("Gefundene Geräte")
                            Spacer()
                            Text("\(scanner.devices.filter { $0.status != .missing }.count) aktiv")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("IP Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showPortEditor = true }) {
                            Label("Port-Einstellungen", systemImage: "gearshape")
                        }
                        
                        Button(action: { showOUIDatabaseSettings = true }) {
                            Label("OUI-Datenbank", systemImage: "server.rack")
                        }
                        
                        Divider()
                        
                        Button(action: { scanner.updateOUIDatabase(useFullList: false) }) {
                            Label("OUI-Liste aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        Button(action: { scanner.updateOUIDatabase(useFullList: true) }) {
                            Label("Vollständige OUI-Liste laden", systemImage: "arrow.down.circle")
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
        }
    }
}
#endif
