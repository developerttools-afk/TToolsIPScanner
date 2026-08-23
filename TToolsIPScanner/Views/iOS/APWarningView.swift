import SwiftUI

#if os(iOS)
/// Warning view for AP-Isolation / Client Isolation scenarios
struct APWarningView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wenige Geräte gefunden?")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Mögliche Ursachen")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // AP-Isolation
                    WarningSection(
                        icon: "shield.lefthalf.filled",
                        title: "AP-Isolation / Client Isolation",
                        color: .orange,
                        description: "Dein Router verhindert, dass Geräte im WLAN sich gegenseitig sehen können."
                    ) {
                        Text("**Häufig in:**")
                        Text("• Gast-WLANs")
                        Text("• Firmen-Netzwerken")
                        Text("• Öffentlichen Hotspots")
                        Text("• Sicherheits-Einstellungen")
                        
                        Text("\n**Lösung:**")
                            .fontWeight(.semibold)
                        Text("Router-Einstellungen → WLAN → AP-Isolation **deaktivieren**")
                    }
                    
                    Divider()
                    
                    // iOS Limitation
                    WarningSection(
                        icon: "iphone",
                        title: "iOS Einschränkungen",
                        color: .blue,
                        description: "iOS erlaubt keine ARP/ICMP-Scans aus Datenschutzgründen."
                    ) {
                        Text("**Was iOS blockiert:**")
                        Text("• ARP-Scans (Layer 2)")
                        Text("• ICMP Ping")
                        Text("• Raw Sockets")
                        
                        Text("\n**Was funktioniert:**")
                            .fontWeight(.semibold)
                        Text("• TCP Port-Scans")
                        Text("• Bonjour/mDNS Discovery")
                        Text("• DNS Lookups")
                        
                        Text("\n**Tipp:** Auf macOS findet die App mehr Geräte!")
                            .font(.caption)
                            .italic()
                    }
                    
                    Divider()
                    
                    // Permission Check
                    WarningSection(
                        icon: "checkmark.shield",
                        title: "Lokales Netzwerk Permission",
                        color: .green,
                        description: "Stelle sicher, dass die Permission erteilt ist."
                    ) {
                        Text("Einstellungen → TTools IP Scanner")
                        Text("→ **Lokales Netzwerk** muss 🟢 AN sein")
                    }
                }
                .padding()
            }
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

private struct WarningSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let description: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .font(.subheadline)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
#endif
