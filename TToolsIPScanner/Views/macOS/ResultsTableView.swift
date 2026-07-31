import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ResultsTableView: View {
    @ObservedObject var scanner: NetworkScanner
    @Binding var sortOrder: [KeyPathComparator<DeviceInfo>]
    @AppStorage("tableSettings") private var tableSettings = TableSettings.default
    @State private var deviceToEdit: DeviceInfo?
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
    
    var body: some View {
        Table(scanner.devices, sortOrder: $sortOrder) {
            if tableSettings.visibleColumns.contains(.status) {
                TableColumn("Status") { device in
                    HStack {
                        StatusIndicator(status: device.status)
                        Button(action: {
                            if let index = scanner.devices.firstIndex(where: { $0.id == device.id }) {
                                var copy = scanner.devices
                                copy[index].isExpanded.toggle()
                                scanner.devices = copy
                            }
                        }) {
                            Image(systemName: device.isExpanded ? "chevron.down" : "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .width(50)
            }
            
            if tableSettings.visibleColumns.contains(.ip) {
                TableColumn("IP", value: \.ipAddress) { device in
                    Text(device.ipAddress)
                        .contextMenu {
                            Button(action: {
                                copyToClipboard(device.ipAddress)
                            }) {
                                Label("IP kopieren", systemImage: "doc.on.doc")
                            }
                            
                            if device.openPorts.contains(80) || device.openPorts.contains(443) {
                                Button(action: {
                                    #if os(macOS)
                                    scanner.openInBrowser(ip: device.ipAddress)
                                    #else
                                    if let url = URL(string: "http://\(device.ipAddress)") {
                                        UIApplication.shared.open(url)
                                    }
                                    #endif
                                }) {
                                    Label("Im Browser öffnen", systemImage: "safari")
                                }
                            }
                        }
                }
            }
            
            if tableSettings.visibleColumns.contains(.hostname) {
                TableColumn("Gerätename", value: \.hostName) { device in
                    let aliasName = scanner.getDeviceAlias(for: device)?.customName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayName = (aliasName?.isEmpty == false) ? aliasName! : device.hostName
                    HStack {
                        Text(displayName)
                        if aliasName?.isEmpty == false {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        deviceToEdit = device
                    }
                }
            }
            
            if tableSettings.visibleColumns.contains(.mac) {
                TableColumn("MAC-Adresse", value: \.macAddress) { device in
                    Text(device.macAddress)
                        .contextMenu {
                            Button(action: {
                                copyToClipboard(device.macAddress)
                            }) {
                                Label("MAC kopieren", systemImage: "doc.on.doc")
                            }
                            
                            if !device.manufacturer.isEmpty {
                                Text(device.manufacturer)
                                    .foregroundColor(.secondary)
                            }
                        }
                }
            }
            
            if tableSettings.visibleColumns.contains(.manufacturer) {
                TableColumn("Hersteller", value: \.manufacturer)
            }
            
            if tableSettings.visibleColumns.contains(.portSymbols) || tableSettings.visibleColumns.contains(.ports) {
                TableColumn("Ports") { device in
                    PortsPreview(ports: device.openPorts)
                }
                .width(180)
            }
        }
        .onChange(of: sortOrder) { _, newValue in
            var sorted = scanner.devices
            sorted.sort(using: newValue)
            scanner.devices = sorted
        }
        .sheet(item: $deviceToEdit) { device in
            NavigationStack {
                DeviceAliasEditor(device: device, scanner: scanner)
            }
        }
    }
} 