import SwiftUI

struct DNSCacheSettingsView: View {
    @ObservedObject var scanner: NetworkScanner
    @State private var statistics: String = "Lade Statistiken..."
    @State private var memoryUsage: String = "0 Bytes"
    @State private var showClearConfirmation = false
    
    var body: some View {
        List {
            Section {
                Text("DNS-Cache")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Der DNS-Cache speichert Hostname-Lookups für 5 Minuten, um wiederholte Scans zu beschleunigen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Statistiken") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(statistics)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                    
                    HStack {
                        Text("Geschätzter Speicher:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(memoryUsage)
                            .foregroundStyle(.primary)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Aktionen") {
                Button(action: {
                    Task {
                        await refreshStatistics()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Statistiken aktualisieren")
                    }
                }
                
                Button(action: {
                    scanner.pruneExpiredDNSCache()
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        await refreshStatistics()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash.slash")
                        Text("Abgelaufene Einträge entfernen")
                    }
                }
                
                Button(role: .destructive, action: {
                    showClearConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Cache leeren")
                    }
                }
            }
            
            Section("Informationen") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "clock",
                        title: "Gültigkeitsdauer",
                        value: "5 Minuten"
                    )
                    
                    InfoRow(
                        icon: "square.stack.3d.up",
                        title: "Maximale Größe",
                        value: "1000 Einträge"
                    )
                    
                    InfoRow(
                        icon: "speedometer",
                        title: "Beschleunigung",
                        value: "Bis zu 80% schneller"
                    )
                }
            }
            
            Section("Was wird gecacht?") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("✓ Hostname-Lookups (reverse DNS)")
                    Text("✓ Erfolgreiche und fehlgeschlagene Lookups")
                    Text("✗ MAC-Adressen (werden nicht gecacht)")
                    Text("✗ Port-Scan-Ergebnisse")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("DNS-Cache")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            Task {
                await refreshStatistics()
            }
        }
        .confirmationDialog(
            "Cache wirklich leeren?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cache leeren", role: .destructive) {
                scanner.clearDNSCache()
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    await refreshStatistics()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle gespeicherten DNS-Einträge werden entfernt. Bei neuen Scans müssen Hostnamen neu aufgelöst werden.")
        }
    }
    
    private func refreshStatistics() async {
        statistics = await scanner.getDNSCacheStatistics()
        memoryUsage = await scanner.dnsCache.estimatedMemoryUsage()
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.primary)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        DNSCacheSettingsView(scanner: NetworkScanner())
    }
}
