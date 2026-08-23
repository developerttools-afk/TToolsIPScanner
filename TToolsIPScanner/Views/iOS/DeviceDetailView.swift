import SwiftUI

#if os(iOS)
struct DeviceDetailView: View {
    let device: DeviceInfo
    @ObservedObject var scanner: NetworkScanner
    @State private var showEditAlias = false
    
    /// NavigationLink captures a snapshot; always read the live scan result.
    private var live: DeviceInfo {
        scanner.devices.first { $0.ipAddress == device.ipAddress } ?? device
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    StatusIndicator(status: live.status)
                    Text(live.status == .missing ? "Nicht erreichbar" : "Aktiv")
                        .foregroundColor(live.status == .missing ? .red : .green)
                }
                
                LabeledContent("IP-Adresse", value: live.ipAddress)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = live.ipAddress
                        }) {
                            Label("IP kopieren", systemImage: "doc.on.doc")
                        }
                    }
                
                if !live.macAddress.isEmpty {
                    LabeledContent("MAC-Adresse", value: live.macAddress)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = live.macAddress
                            }) {
                                Label("MAC kopieren", systemImage: "doc.on.doc")
                            }
                        }
                } else {
                    LabeledContent("MAC-Adresse", value: "Nicht verfügbar")
                }
                
                if !live.manufacturer.isEmpty {
                    LabeledContent("Hersteller", value: live.manufacturer)
                }
                
                if let alias = scanner.getDeviceAlias(for: live) {
                    LabeledContent("Alias", value: alias.customName)
                }
            }
            
            Section("Offene Ports") {
                if live.openPorts.isEmpty {
                    Text(scanner.isScanning ? "Ports werden geprüft…" : "Keine offenen Ports gefunden")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(live.openPorts.sorted(), id: \.self) { port in
                        HStack {
                            Text(NetworkConstants.portLetter(for: port))
                                .font(.body.monospaced().weight(.semibold))
                                .foregroundStyle(scanner.getPortSymbol(port)?.color ?? .blue)
                                .frame(minWidth: 16, alignment: .center)
                            if let symbolInfo = scanner.getPortSymbol(port) {
                                Image(systemName: symbolInfo.symbol)
                                    .foregroundColor(symbolInfo.color)
                            }
                            Text("\(port)")
                                .font(.system(.body, design: .monospaced))
                            Text(scanner.getPortDescription(port))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section {
                if live.openPorts.contains(80) || live.openPorts.contains(443) {
                    Button(action: {
                        if let url = URL(string: "http://\(live.ipAddress)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Im Browser öffnen", systemImage: "safari")
                    }
                }
                
                if live.openPorts.contains(22) {
                    Button(action: {
                        if let url = URL(string: "ssh://\(live.ipAddress)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("SSH Verbindung", systemImage: "terminal")
                    }
                }
                
                Button(action: { showEditAlias = true }) {
                    Label("Hostname-Alias bearbeiten", systemImage: "pencil")
                }
            }
            
            if let alias = scanner.getDeviceAlias(for: live),
               !alias.notes.isEmpty {
                Section("Notizen") {
                    Text(alias.notes)
                }
            }
        }
        .navigationTitle(scanner.displayName(for: live))
        .sheet(isPresented: $showEditAlias) {
            NavigationStack {
                DeviceAliasEditor(device: live, scanner: scanner)
            }
        }
    }
}
#endif
