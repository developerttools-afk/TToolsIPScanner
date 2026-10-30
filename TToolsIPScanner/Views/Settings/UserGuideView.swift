import SwiftUI

struct UserGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                guideSection(
                    title: "Scan starten",
                    points: [
                        "Netzwerk-IP eingeben oder einen Eintrag unter „Zuletzt gescannt“ wählen. Auf dem iPhone bleibt „Netzwerk“ eingeklappt und zeigt die aktuelle Adresse.",
                        "Auf dem iPhone stehen Schnell, Normal, Gründlich, „Vollständiger Port-Scan“ und „IPv6 scannen“ im Zahnrad unter „Scan“. Am Mac liegen sie neben dem Scan-Knopf.",
                        "„IPv6 scannen“ ist aus, bis du es einschaltest. Die App sucht dann Nachbarn im lokalen IPv6-Netz. Am Mac erscheint dafür eine IPv6-Spalte neben der IP. Auf dem iPhone steht die Adresse unter der IPv4-Adresse.",
                        "„Scan starten“ tippen. Mit „Stopp“ kannst du abbrechen."
                    ]
                )
                
                guideSection(
                    title: "Gerät öffnen (iOS)",
                    points: [
                        "Kurz tippen oder nach links wischen: Auswahl, welcher Dienst geöffnet wird.",
                        "Lang drücken oder nach rechts wischen: Detailseite mit Ports, Namen und Alias."
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
                        "Vollscan ergänzt zusätzliche Standard-Ports.",
                        "Einzelnes Gerät: in den Details (iOS) oder per Rechtsklick auf IP/Name/Ports (macOS) „Ports scannen“ — nutzt denselben Port-Modus wie der Netz-Scan.",
                        "Am Mac öffnet ein Klick auf ein Port-Symbol den Dienst, zum Beispiel w die Webseite und s SSH.",
                        "Unter der Geräteliste erklärt die Legende alle sichtbaren Buchstaben, groß für die Erkennung (W Web-Dienst, P Erreichbar) und klein für den Port (w Web, s SSH)."
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
                    title: "Erkennungs-Badges",
                    points: [
                        "Kleine Buchstaben neben den Ports zeigen, worüber ein Gerät erkannt oder angereichert wurde:",
                        "G — Gateway / Router",
                        "W — Web-Dienst (HTTP/HTTPS)",
                        "B — Bonjour / mDNS",
                        "U — UPnP / SSDP",
                        "N — NetBIOS / SMB",
                        "D — DNS-Name",
                        "P — Erreichbar (Gerät antwortet im aktuellen Scan)"
                    ]
                )
                
                guideSection(
                    title: "Weitere Funktionen",
                    points: [
                        "Spalten (macOS) über „Spalten anzeigen/ausblenden“ steuern.",
                        "OUI-Datenbank liefert Hersteller zu MAC-Adressen.",
                        "Ab iOS 27 liest die App dieselbe Nachbartabelle wie am Mac. Auf älteren iOS-Versionen kommt die MAC aus NetBIOS, AirPlay/RAOP, Linux-Workstation, Shelly/ESPHome oder einer IPv6-Adresse. Danach läuft dieselbe OUI-Suche.",
                        "Ohne MAC erkennt die App einen Pi am SSH-Banner (Raspbian) und einen ESP an Tasmota, WLED, Arduino board=esp32, ESPHome-Port 6053 oder der HTTP-Seite. Port 8123 ist Home Assistant, nicht automatisch ein Pi.",
                        "Router & MAC: optionale Fritz!Box (TR-064, Passwort im Schlüsselbund), SNMP-ARP nur am Gateway, und die MAC-Liste der macOS-App über iCloud.",
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
