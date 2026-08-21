import SwiftUI

/// View zur benutzerfreundlichen Anzeige von Scan-Fehlern
struct ErrorMessageView: View {
    let error: ScanError
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Haupt-Fehlermeldung
            HStack(spacing: 8) {
                Image(systemName: error.icon)
                    .foregroundStyle(colorForSeverity(error.severity))
                
                Text(error.errorDescription ?? "Unbekannter Fehler")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                if error.failureReason != nil || error.recoverySuggestion != nil {
                    Button(action: {
                        withAnimation {
                            showDetails.toggle()
                        }
                    }) {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(colorForSeverity(error.severity))
            
            // Details (ausklappbar)
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    if let reason = error.failureReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let suggestion = error.recoverySuggestion {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "lightbulb")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            
                            Text(suggestion)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColorForSeverity(error.severity))
        )
    }
    
    private func colorForSeverity(_ severity: ScanError.Severity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .red
        }
    }
    
    private func backgroundColorForSeverity(_ severity: ScanError.Severity) -> Color {
        switch severity {
        case .info:
            return .blue.opacity(0.1)
        case .warning:
            return .orange.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        case .critical:
            return .red.opacity(0.15)
        }
    }
}

#Preview("Invalid IP") {
    ErrorMessageView(error: .invalidIPAddress("999.999.999.999"))
        .padding()
}

#Preview("Network Unreachable") {
    ErrorMessageView(error: .networkUnreachable)
        .padding()
}

#Preview("Permission Denied") {
    ErrorMessageView(error: .localNetworkPermissionDenied)
        .padding()
}

#Preview("Scan Already Running") {
    ErrorMessageView(error: .scanAlreadyRunning)
        .padding()
}

#Preview("OUI Database Error") {
    ErrorMessageView(error: .ouiDatabaseDownloadFailed(statusCode: 404))
        .padding()
}
