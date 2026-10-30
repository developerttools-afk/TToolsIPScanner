import SwiftUI

struct RouterMACSettingsView: View {
    @ObservedObject var scanner: NetworkScanner
    @Environment(\.dismiss) private var dismiss
    @State private var fritzEnabled = false
    @State private var fritzHost = ""
    @State private var fritzUsername = ""
    @State private var fritzPassword = ""
    @State private var hasStoredPassword = false
    @State private var snmpEnabled = true
    @State private var snmpCommunity = "public"
    @State private var shareiCloud = true
    
    var body: some View {
        Form {
            Section {
                Toggle("Fritz!Box abfragen", isOn: $fritzEnabled)
                TextField("Host (leer = Gateway)", text: $fritzHost)
                    .autocorrectionDisabled()
                TextField("Benutzer", text: $fritzUsername)
                    .autocorrectionDisabled()
                SecureField(hasStoredPassword ? "Passwort (gespeichert)" : "Passwort", text: $fritzPassword)
                HStack {
                    Button("Passwort sichern") {
                        RouterCredentialStore.savePassword(fritzPassword)
                        fritzPassword = ""
                        hasStoredPassword = RouterCredentialStore.password() != nil
                    }
                    .disabled(fritzPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Passwort löschen", role: .destructive) {
                        RouterCredentialStore.deletePassword()
                        fritzPassword = ""
                        hasStoredPassword = false
                    }
                    .disabled(!hasStoredPassword)
                }
            } header: {
                Text("Fritz!Box TR-064")
            } footer: {
                Text("Liest MAC und Name über Hosts:GetGenericHostEntry. Das Passwort liegt im Schlüsselbund, nicht in iCloud.")
            }
            
            Section {
                Toggle("Gateway-ARP per SNMP", isOn: $snmpEnabled)
                TextField("Community", text: $snmpCommunity)
                    .autocorrectionDisabled()
            } footer: {
                Text("Walk auf ipNetToMediaPhysAddress nur am Gateway. Community public reicht bei manchen Business-Routern, bei den meisten Fritz!Boxen nicht.")
            }
            
            Section {
                Toggle("MAC-Adressen über iCloud teilen", isOn: $shareiCloud)
            } footer: {
                Text("Die macOS-App schreibt gefundene MAC-Adressen in den iCloud-Schlüsselwertspeicher. Die iPhone-App übernimmt sie für dasselbe Subnetz. Dafür muss iCloud Key-Value für die App-ID aktiv sein.")
            }
            
            if !scanner.routerMACStatus.isEmpty {
                Section("Letzte Abfrage") {
                    Text(scanner.routerMACStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Router & MAC")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .onAppear(perform: load)
        .onChange(of: fritzEnabled) { _, value in
            SettingsManager.shared.fritzTR064Enabled = value
        }
        .onChange(of: fritzHost) { _, value in
            SettingsManager.shared.fritzHost = value
        }
        .onChange(of: fritzUsername) { _, value in
            SettingsManager.shared.fritzUsername = value
        }
        .onChange(of: snmpEnabled) { _, value in
            SettingsManager.shared.snmpARPEnabled = value
        }
        .onChange(of: snmpCommunity) { _, value in
            SettingsManager.shared.snmpCommunity = value
        }
        .onChange(of: shareiCloud) { _, value in
            SettingsManager.shared.shareMACOveriCloud = value
        }
    }
    
    private func load() {
        let settings = SettingsManager.shared
        fritzEnabled = settings.fritzTR064Enabled
        fritzHost = settings.fritzHost
        fritzUsername = settings.fritzUsername
        snmpEnabled = settings.snmpARPEnabled
        snmpCommunity = settings.snmpCommunity
        shareiCloud = settings.shareMACOveriCloud
        hasStoredPassword = RouterCredentialStore.password() != nil
    }
}
