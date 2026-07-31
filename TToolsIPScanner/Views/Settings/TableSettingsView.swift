import SwiftUI

struct TableSettingsView: View {
    @Binding var settings: TableSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Sichtbare Spalten") {
                ForEach(TableSettings.ColumnType.allCases, id: \.self) { column in
                    Toggle(isOn: Binding(
                        get: { settings.visibleColumns.contains(column) },
                        set: { isVisible in
                            if isVisible {
                                settings.visibleColumns.insert(column)
                            } else {
                                settings.visibleColumns.remove(column)
                            }
                        }
                    )) {
                        Label(column.rawValue, systemImage: column.icon)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 300)
        .navigationTitle("Spalten-Einstellungen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    dismiss()
                }
            }
        }
    }
} 