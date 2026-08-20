import SwiftUI

struct DeviceAliasEditor: View {
    let device: DeviceInfo
    @ObservedObject var scanner: NetworkScanner
    @Environment(\.dismiss) private var dismiss
    
    @State private var customName: String
    @State private var notes: String
    
    init(device: DeviceInfo, scanner: NetworkScanner) {
        self.device = device
        self.scanner = scanner
        
        let alias = scanner.getDeviceAlias(for: device)
        _customName = State(initialValue: alias?.customName ?? device.hostName)
        _notes = State(initialValue: alias?.notes ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Geräteinformationen")) {
                LabeledContent("IP-Adresse", value: device.ipAddress)
                LabeledContent(
                    "MAC-Adresse",
                    value: device.macAddress.isEmpty ? "Nicht verfügbar" : device.macAddress
                )
                LabeledContent("Scan-Hostname", value: device.hostName)
                if !device.manufacturer.isEmpty {
                    LabeledContent("Hersteller", value: device.manufacturer)
                }
            }
            
            Section {
                TextField("Eigener Name", text: $customName)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                Text("Dieser Name überschreibt den Hostnamen und bleibt für den nächsten Scan gespeichert (an IP und MAC).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Hostname-Alias")
            }
            
            Section(header: Text("Notizen")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
            
            Section {
                Button(role: .destructive) {
                    scanner.removeDeviceAlias(for: device)
                    dismiss()
                } label: {
                    Label("Alias löschen", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Alias bearbeiten")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    scanner.setDeviceAlias(
                        for: device,
                        alias: DeviceAlias(customName: customName, notes: notes)
                    )
                    dismiss()
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
    }
}
