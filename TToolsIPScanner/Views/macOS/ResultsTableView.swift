import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ResultsTableView: View {
    @ObservedObject var scanner: NetworkScanner
    @Binding var sortOrder: [KeyPathComparator<DeviceInfo>]
    @Binding var columnCustomization: TableColumnCustomization<DeviceInfo>
    @State private var deviceToEdit: DeviceInfo?
    @State private var tableSelection = Set<DeviceInfo.ID>()
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
    
    private func device(for ids: Set<DeviceInfo.ID>) -> DeviceInfo? {
        scanner.devices.first { ids.contains($0.id) }
    }
    
    private func openPrimary(_ ids: Set<DeviceInfo.ID>) {
        guard let device = device(for: ids),
              let action = NetworkConstants.primaryOpenAction(
                ip: device.ipAddress,
                openPorts: device.openPorts,
                advertisedServices: device.advertisedServices
              ) else { return }
        scanner.openService(action)
    }
    
    var body: some View {
        Table(
            scanner.devices,
            selection: $tableSelection,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
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
            .width(min: 44, ideal: 52, max: 64)
            .customizationID(TableSettings.ColumnType.status.customizationID)
            
            TableColumn("IP", value: \.ipAddress) { device in
                HStack(spacing: 6) {
                    Text(device.ipAddress)
                    if scanner.isPortScanning(ip: device.ipAddress) {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .width(min: 110, ideal: 130, max: 180)
            .customizationID(TableSettings.ColumnType.ip.customizationID)
            
            TableColumn("Gerätename", value: \.hostName) { device in
                let displayName = scanner.displayName(for: device)
                let hasAlias = scanner.getDeviceAlias(for: device) != nil
                HStack {
                    Text(displayName)
                    if hasAlias {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .help("Gespeicherter Hostname-Alias")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { deviceToEdit = device }
            }
            .width(min: 100, ideal: 160, max: 320)
            .customizationID(TableSettings.ColumnType.hostname.customizationID)
            
            TableColumn("DNS-Name", value: \.dnsName) { device in
                Text(device.dnsName.isEmpty ? "—" : device.dnsName)
                    .foregroundStyle(device.dnsName.isEmpty ? .tertiary : .primary)
            }
            .width(min: 80, ideal: 140, max: 280)
            .customizationID(TableSettings.ColumnType.dnsName.customizationID)
            
            TableColumn("mDNS-Name", value: \.mdnsName) { device in
                let value = device.mdnsName.isEmpty ? device.bonjourName : device.mdnsName
                Text(value.isEmpty ? "—" : value)
                    .foregroundStyle(value.isEmpty ? .tertiary : .primary)
            }
            .width(min: 80, ideal: 140, max: 280)
            .customizationID(TableSettings.ColumnType.mdnsName.customizationID)
            
            TableColumn("MAC-Adresse", value: \.macAddress) { device in
                Text(device.macAddress.isEmpty ? "—" : device.macAddress)
                    .foregroundStyle(device.macAddress.isEmpty ? .tertiary : .primary)
            }
            .width(min: 120, ideal: 150, max: 200)
            .customizationID(TableSettings.ColumnType.mac.customizationID)
            
            TableColumn("Hersteller", value: \.manufacturer)
                .width(min: 100, ideal: 160, max: 320)
                .customizationID(TableSettings.ColumnType.manufacturer.customizationID)
            
            TableColumn("Ports") { device in
                HStack(spacing: 6) {
                    DiscoveryBadges(device: device)
                    PortsPreview(ports: device.openPorts, ipAddress: device.ipAddress) { action in
                        scanner.openService(action)
                    }
                    if scanner.isPortScanning(ip: device.ipAddress) {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .width(min: 100, ideal: 180, max: 360)
            .customizationID(TableSettings.ColumnType.ports.customizationID)
        }
        .contextMenu(forSelectionType: DeviceInfo.ID.self) { ids in
            selectionMenu(ids)
        } primaryAction: { ids in
            openPrimary(ids)
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
    
    @ViewBuilder
    private func selectionMenu(_ ids: Set<DeviceInfo.ID>) -> some View {
        if let device = device(for: ids) {
            let actions = NetworkConstants.openActions(
                ip: device.ipAddress,
                openPorts: device.openPorts,
                advertisedServices: device.advertisedServices
            )
            if !actions.isEmpty {
                Menu("Öffnen") {
                    ForEach(actions) { action in
                        Button {
                            scanner.openService(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                }
                Button("URL kopieren") {
                    if let primary = actions.first {
                        copyToClipboard(primary.urlString)
                    }
                }
            }
            Button("IP kopieren") {
                copyToClipboard(device.ipAddress)
            }
            if !device.macAddress.isEmpty {
                Button("MAC kopieren") {
                    copyToClipboard(device.macAddress)
                }
            }
            #if os(macOS)
            Button("Ping im Terminal") {
                scanner.pingInTerminal(ip: device.ipAddress)
            }
            #endif
            Divider()
            Button("Alias bearbeiten…") { deviceToEdit = device }
            if scanner.getDeviceAlias(for: device) != nil {
                Button("Alias löschen", role: .destructive) {
                    scanner.removeDeviceAlias(for: device)
                }
            }
            Divider()
            if scanner.isPortScanning(ip: device.ipAddress) {
                Button("Port-Scan abbrechen", role: .destructive) {
                    scanner.stopDevicePortScan()
                }
            } else {
                Button("Ports erneut scannen") {
                    scanner.startDevicePortScan(for: device)
                }
                .disabled(scanner.isScanning || scanner.devicePortScanIP != nil)
            }
        }
    }
}
