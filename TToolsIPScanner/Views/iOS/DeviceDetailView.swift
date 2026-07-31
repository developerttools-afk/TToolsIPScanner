import SwiftUI

#if os(iOS)
struct DeviceDetailView: View {
    let device: DeviceInfo
    @ObservedObject var scanner: NetworkScanner
    @State private var showEditAlias = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    StatusIndicator(status: device.status)
                    Text(device.status == .missing ? "Nicht erreichbar" : "Aktiv")
                        .foregroundColor(device.status == .missing ? .red : .green)
                }
                
                LabeledContent("IP-Adresse", value: device.ipAddress)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = device.ipAddress
                        }) {
                            Label("IP kopieren", systemImage: "doc.on.doc")
                        }
                    }
                
                if !device.macAddress.isEmpty {
                    LabeledContent("MAC-Adresse", value: device.macAddress)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = device.macAddress
                            }) {
                                Label("MAC kopieren", systemImage: "doc.on.doc")
                            }
                        }
                } else {
                    LabeledContent("MAC-Adresse", value: "Nicht verfügbar")
                }
                
                if !device.manufacturer.isEmpty {
                    LabeledContent("Hersteller", value: device.manufacturer)
                }
                
                if let alias = scanner.getDeviceAlias(for: device) {
                    LabeledContent("Alias", value: alias.customName)
                }
            }
            
            if !device.openPorts.isEmpty {
                Section("Offene Ports") {
                    ForEach(device.openPorts.sorted(), id: \.self) { port in
                        HStack {
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
                if device.openPorts.contains(80) || device.openPorts.contains(443) {
                    Button(action: {
                        if let url = URL(string: "http://\(device.ipAddress)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Im Browser öffnen", systemImage: "safari")
                    }
                }
                
                if device.openPorts.contains(22) {
                    Button(action: {
                        if let url = URL(string: "ssh://\(device.ipAddress)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("SSH Verbindung", systemImage: "terminal")
                    }
                }
                
                Button(action: { showEditAlias = true }) {
                    Label("Alias bearbeiten", systemImage: "pencil")
                }
            }
            
            if let alias = scanner.getDeviceAlias(for: device),
               !alias.notes.isEmpty {
                Section("Notizen") {
                    Text(alias.notes)
                }
            }
        }
        .navigationTitle(scanner.getDeviceAlias(for: device)?.customName ?? device.hostName)
        .sheet(isPresented: $showEditAlias) {
            NavigationStack {
                DeviceAliasEditor(device: device, scanner: scanner)
            }
        }
    }
}
#endif
