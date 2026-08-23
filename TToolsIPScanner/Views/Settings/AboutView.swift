import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Info
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("TTools IP Scanner")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        Text("Version \(version) (\(build))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                
                Divider()
                
                // Hobby Project Disclaimer
                disclaimerSection(
                    icon: "info.circle",
                    title: "Hobbyprojekt",
                    content: """
                    Dies ist ein privates Hobbyprojekt, das in meiner Freizeit entwickelt wurde. \
                    Ich stelle es gerne kostenlos zur Verfügung, kann jedoch keine Gewährleistung \
                    oder Garantie für die Funktionalität übernehmen.
                    """
                )
                
                // Legal Disclaimer
                disclaimerSection(
                    icon: "exclamationmark.triangle",
                    title: "Nutzung auf eigene Gefahr",
                    content: """
                    Die Nutzung dieser App erfolgt vollständig auf eigene Gefahr. \
                    Der Entwickler übernimmt keine Haftung für Schäden, Datenverluste oder \
                    andere Probleme, die durch die Verwendung der App entstehen könnten.
                    """
                )
                
                // Feedback Section
                disclaimerSection(
                    icon: "bubble.left.and.bubble.right",
                    title: "Feedback & Verbesserungen",
                    content: """
                    Ich freue mich über Feedback und Verbesserungsvorschläge! \
                    Allerdings kann ich keine Garantie geben, dass Vorschläge umgesetzt werden. \
                    Die App wurde für meinen persönlichen Gebrauch entwickelt.
                    """
                )
                
                Divider()
                
                // License & Copyright
                VStack(alignment: .leading, spacing: 8) {
                    Text("© 2024 Thorsten Albers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("MIT License")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Diese App verwendet ausschließlich Apple-Frameworks und hat keine externen Abhängigkeiten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Über diese App")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }
        }
    }
    
    private func disclaimerSection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
