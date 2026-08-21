import SwiftUI

struct UserGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                guideSection(
                    title: "Scan starten",
                    points: [
                        "Netzwerk-IP eingeben oder einen Eintrag unter „Zuletzt gescannt“ wählen.",
                        "Optional „Vollständiger Port-Scan“ aktivieren.",
                        "„Scan starten“ tippen. Mit „Stopp“ kannst du abbrechen."
                    ]
                )
                
                guideSection(
                    title: "Phasen",
                    points: [
                        "Hosts suchen: schnelle Prüfung im Netz (Phase 1).",
                        "Ports scannen: detaillierter Port-Scan nur auf gefundenen Geräten (Phase 2).",
                        "Grüne Punkte zeigen abgeschlossene Phasen."
                    ]
                )
                
                guideSection(
                    title: "Ports",
                    points: [
                        "Unter Port-Einstellungen legst du die Ports für Phase 2 fest.",
                        "Quick-Scan nutzt deine Custom-Ports (sonst 21, 22, 80, 443).",
                        "Vollscan ergänzt zusätzliche Standard-Ports."
                    ]
                )
                
                guideSection(
                    title: "Hostname-Alias",
                    points: [
                        "Gerätenamen antippen (macOS) bzw. in den Details „Hostname-Alias bearbeiten“ (iOS).",
                        "Der Alias überschreibt den Scan-Hostnamen und bleibt für den nächsten Scan gespeichert.",
                        "Speicherung erfolgt an IP und MAC, damit der Name wiedergefunden wird."
                    ]
                )
                
                guideSection(
                    title: "Weitere Funktionen",
                    points: [
                        "Spalten (macOS) über „Spalten anzeigen/ausblenden“ steuern.",
                        "OUI-Datenbank liefert Hersteller zu MAC-Adressen.",
                        "Ergebnisse und Einstellungen werden lokal gespeichert."
                    ]
                )
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Wichtige Hinweise")
                            .font(.headline)
                    }
                    
                    Text("• Es wird nur das lokale Netzwerk gescannt. Scanne nur Netze, für die du berechtigt bist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("• Dies ist ein Hobbyprojekt ohne Gewährleistung. Nutzung auf eigene Gefahr.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("• Weitere Informationen findest du unter 'Über diese App' im Einstellungsmenü.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Bedienungsanleitung")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }
        }
    }
    
    private func guideSection(title: String, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(point)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
            }
        }
    }
}
