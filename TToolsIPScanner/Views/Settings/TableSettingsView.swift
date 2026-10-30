import SwiftUI

struct TableSettingsView: View {
    @Binding var settings: TableSettings
    @Binding var columnCustomization: TableColumnCustomization<DeviceInfo>
    @Environment(\.dismiss) private var dismiss
    
    private var configurableColumns: [TableSettings.ColumnType] {
        TableSettings.ColumnType.allCases.filter { $0 != .portSymbols }
    }
    
    var body: some View {
        Form {
            Section {
                Text("Spalten per Drag & Drop in der Tabellenkopfzeile verschieben und am Trenner in der Breite ziehen. Die Anordnung wird beim nächsten Start wiederhergestellt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Sichtbare Spalten") {
                ForEach(configurableColumns) { column in
                    Toggle(isOn: visibilityBinding(for: column)) {
                        Label(column.rawValue, systemImage: column.icon)
                    }
                }
            }
            
            Section {
                Button("Spaltenreihenfolge zurücksetzen") {
                    columnCustomization = TableColumnCustomization()
                    for column in configurableColumns {
                        columnCustomization[visibility: column.customizationID] = .visible
                        settings.visibleColumns.insert(column)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 340, minHeight: 420)
        .navigationTitle("Spalten-Einstellungen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }
    
    private func visibilityBinding(for column: TableSettings.ColumnType) -> Binding<Bool> {
        Binding(
            get: {
                columnCustomization[visibility: column.customizationID] != .hidden
            },
            set: { isVisible in
                columnCustomization[visibility: column.customizationID] = isVisible ? .visible : .hidden
                if isVisible {
                    settings.visibleColumns.insert(column)
                } else {
                    settings.visibleColumns.remove(column)
                }
            }
        )
    }
}
