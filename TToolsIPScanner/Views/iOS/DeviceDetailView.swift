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
                
                if !live.ipv6Address.isEmpty, live.ipv6Address != live.ipAddress {
                    LabeledContent("IPv6-Adresse", value: live.ipv6Address)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = live.ipv6Address
                            }) {
                                Label("IPv6 kopieren", systemImage: "doc.on.doc")
                            }
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
                    Text("iOS kann die ARP-Tabelle nicht lesen. Eine MAC erscheint nur, wenn NetBIOS, Bonjour oder UPnP sie liefern. Sonst gibt es keinen OUI-Hersteller.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                if !live.manufacturer.isEmpty {
                    LabeledContent("Hersteller", value: live.manufacturer)
                }
                
                if live.category != .unknown {
                    LabeledContent("Kategorie", value: live.category.displayName)
                }
                
                if let firstSeen = live.firstSeen {
                    LabeledContent("Erstmals gesehen", value: firstSeen.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastSeen = live.lastSeen {
                    LabeledContent("Zuletzt gesehen", value: lastSeen.formatted(date: .abbreviated, time: .shortened))
                }
            }
            
            Section("Namen") {
                LabeledContent("DNS-Name", value: nameOrNA(live.dnsName))
                LabeledContent("mDNS-Name", value: nameOrNA(live.mdnsName.isEmpty ? live.bonjourName : live.mdnsName))
                if !live.netbiosName.isEmpty {
                    LabeledContent("NetBIOS-Name", value: live.netbiosName)
                }
            }
            
            Section("Details") {
                if !live.detailHint.isEmpty {
                    LabeledContent("Dienst/Protokoll", value: live.detailHint)
                }
                if !live.osHint.isEmpty {
                    LabeledContent("OS/Hinweis", value: live.osHint)
                }
                if live.detailHint.isEmpty && live.osHint.isEmpty {
                    Text("Keine weiteren Details")
                        .foregroundStyle(.secondary)
                }
                
                if !live.advertisedServices.isEmpty {
                    LabeledContent("Bonjour-Dienste", value: live.advertisedServices.joined(separator: ", "))
                }
                
                if let alias = scanner.getDeviceAlias(for: live) {
                    LabeledContent("Alias", value: alias.customName)
                }
            }
            
            Section("Offene Ports") {
                if scanner.isPortScanning(ip: live.ipAddress) {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Ports werden geprüft…")
                            .foregroundStyle(.secondary)
                    }
                } else if live.openPorts.isEmpty {
                    Text(scanner.isScanning ? "Ports werden geprüft…" : "Keine offenen Ports gefunden")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(live.openPorts.sorted(), id: \.self) { port in
                        if let action = NetworkConstants.openAction(ip: live.ipAddress, port: port) {
                            Button {
                                scanner.openService(action)
                            } label: {
                                portRow(port)
                            }
                            .contextMenu {
                                Button("URL kopieren") {
                                    UIPasteboard.general.string = action.urlString
                                }
                            }
                        } else {
                            portRow(port)
                        }
                    }
                }
                
                if scanner.isPortScanning(ip: live.ipAddress) {
                    Button(role: .destructive) {
                        scanner.stopDevicePortScan()
                    } label: {
                        Label("Port-Scan abbrechen", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        scanner.startDevicePortScan(for: live)
                    } label: {
                        Label(
                            scanner.preferredScanMode == .fullScan
                                ? "Ports erneut scannen (Vollscan)"
                                : "Ports erneut scannen",
                            systemImage: "network"
                        )
                    }
                    .disabled(scanner.isScanning || scanner.devicePortScanIP != nil)
                }
            }
            
            Section {
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
    
    private func portRow(_ port: Int) -> some View {
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
            Spacer(minLength: 8)
            if NetworkConstants.openAction(ip: live.ipAddress, port: port) != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private func nameOrNA(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nicht verfügbar" : name
    }
}
#endif
