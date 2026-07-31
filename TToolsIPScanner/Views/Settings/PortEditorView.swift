import SwiftUI

struct PortEditorView: View {
    let ports: Set<Int>
    let onSave: (Set<Int>) -> Void
    @State private var portText: String
    @Environment(\.dismiss) private var dismiss
    
    let commonPresets: [(String, Set<Int>)] = [
        ("Web (HTTP, HTTPS)", [80, 443]),
        ("Remote (SSH, RDP)", [22, 3389]),
        ("File Sharing", [21, 445, 139]),
        ("Mail (SMTP, IMAP, POP3)", [25, 143, 110]),
        ("Datenbanken", [3306, 5432, 1433]),
        ("IoT/MQTT", [1883, 8883]),
        ("Monitoring", [161, 162])
    ]
    
    init(ports: Set<Int>, onSave: @escaping (Set<Int>) -> Void) {
        self.ports = ports
        self.onSave = onSave
        self._portText = State(initialValue: PortListParser.format(ports))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Standard-Ports")) {
                TextEditor(text: $portText)
                    .frame(height: 100)
                    .font(.system(.body, design: .monospaced))
            }
            
            Section(header: Text("Voreinstellungen")) {
                ForEach(commonPresets, id: \.0) { preset in
                    Button(action: {
                        let newPorts = PortListParser.parse(portText).union(preset.1)
                        portText = PortListParser.format(newPorts)
                    }) {
                        VStack(alignment: .leading) {
                            Text(preset.0)
                                .foregroundColor(.primary)
                            Text(PortListParser.format(preset.1))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .navigationTitle("Port-Editor")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    onSave(PortListParser.parse(portText))
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