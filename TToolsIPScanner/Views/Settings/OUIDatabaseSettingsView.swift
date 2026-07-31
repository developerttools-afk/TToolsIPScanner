import SwiftUI

struct OUIDatabaseSettingsView: View {
    @ObservedObject var scanner: NetworkScanner
    @Environment(\.dismiss) private var dismiss
    
    var cacheAge: String {
        if let timestamp = scanner.ouiDatabaseTimestamp {
            let days = Int(-timestamp.timeIntervalSinceNow / 86400)
            return "\(days) Tage alt"
        }
        return "Keine Cache-Daten"
    }
    
    var body: some View {
        Form {
            Section("OUI-Datenbank") {
                LabeledContent("Einträge", value: "\(scanner.ouiDatabaseCount)")
                LabeledContent("Cache-Alter", value: cacheAge)
                LabeledContent("Status") {
                    if scanner.isOUIDatabaseValid {
                        Text("Aktuell")
                            .foregroundColor(.green)
                    } else {
                        Text("Veraltet")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section {
                Button(action: {
                    scanner.updateOUIDatabase(useFullList: false)
                }) {
                    Label("Schnelles Update", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(scanner.isUpdatingOUI)
                
                Button(action: {
                    scanner.updateOUIDatabase(useFullList: true)
                }) {
                    Label("Vollständiges Update", systemImage: "arrow.down.circle")
                }
                .disabled(scanner.isUpdatingOUI)
                
                Button(role: .destructive, action: {
                    scanner.clearOUICache()
                }) {
                    Label("Cache löschen", systemImage: "trash")
                }
                .disabled(scanner.isUpdatingOUI)
            }
            
            if scanner.isUpdatingOUI {
                Section {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Aktualisiere Datenbank...")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .navigationTitle("OUI-Datenbank")
    }
} 