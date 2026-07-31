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
                if !device.manufacturer.isEmpty {
                    LabeledContent("Hersteller", value: device.manufacturer)
                }
            }
            
            Section(header: Text("Alias")) {
                TextField("Name", text: $customName)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
            
            Section(header: Text("Notizen")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
            
            Section {
                Button(role: .destructive) {
                    scanner.removeDeviceAlias(for: device.aliasKey)
                    dismiss()
                } label: {
                    Label("Alias löschen", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Alias bearbeiten")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    let alias = DeviceAlias(
                        customName: customName,
                        notes: notes
                    )
                    scanner.setDeviceAlias(for: device.aliasKey, alias: alias)
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
    }
}
