import SwiftUI

struct ScanStatusView: View {
    @ObservedObject var scanner: NetworkScanner
    /// The iPhone screen draws the phases in `ScanPhaseStrip` beside the scan button.
    var includePhases: Bool = true
    
    private var phases: [(id: ScanPhaseStep, title: String)] {
        [
            (.hosts, "Hosts suchen"),
            (.ports, "Ports scannen"),
            (.done, "Abgeschlossen")
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if includePhases {
                HStack(spacing: 16) {
                    ForEach(phases, id: \.id) { phase in
                        PhaseIndicator(
                            title: phase.title,
                            state: state(for: phase.id)
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
            
            if scanner.scanPhase == .scanningNetwork || scanner.scanPhase == .scanningPorts {
                HStack(alignment: .firstTextBaseline) {
                    Text(statusLine)
                    Spacer()
                    if !scanner.currentScanIP.isEmpty {
                        HStack(spacing: 4) {
                            Text("IP")
                                .foregroundStyle(.tertiary)
                            Text(scanner.currentScanIP)
                                .font(.caption.monospaced().weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                if scanner.progressPercentage > 0 {
                    ProgressView(value: scanner.progressPercentage, total: 100)
                        .progressViewStyle(.linear)
                }
            }
            
            if scanner.scanPhase == .finished || !scanner.isScanning {
                HStack(spacing: 12) {
                    Text("Aktive Geräte: \(scanner.devices.filter { $0.status != .missing }.count)")
                        .foregroundStyle(.green)
                    Text("Nicht erreichbar: \(scanner.devices.filter { $0.status == .missing }.count)")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
            
            if !scanner.scanProgress.isEmpty && scanner.scanPhase != .idle {
                Text(scanner.scanProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            if scanner.isScanning, !scanner.scanDebugDetail.isEmpty {
                Text(scanner.scanDebugDetail)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }
    
    private var statusLine: String {
        switch scanner.scanPhase {
        case .scanningNetwork:
            return "Suche aktive Geräte…"
        case .scanningPorts:
            if scanner.scanProgress.hasPrefix("Name") {
                return "Namen auflösen…"
            }
            return "Scanne Ports & Details…"
        case .finished:
            return "Scan abgeschlossen"
        case .idle:
            return ""
        }
    }
    
    private func state(for step: ScanPhaseStep) -> PhaseIndicator.State {
        switch scanner.scanPhase {
        case .idle:
            return .pending
        case .scanningNetwork:
            switch step {
            case .hosts: return .active
            case .ports, .done: return .pending
            }
        case .scanningPorts:
            switch step {
            case .hosts: return .completed
            case .ports: return .active
            case .done: return .pending
            }
        case .finished:
            return .completed
        }
    }
}

/// The three scan phases beside the start button. Equality ignores progress ticks.
struct ScanPhaseStrip: View, Equatable {
    var phase: ScanPhase
    
    private var phases: [(id: ScanPhaseStep, title: String)] {
        [
            (.hosts, "Hosts suchen"),
            (.ports, "Ports scannen"),
            (.done, "Abgeschlossen")
        ]
    }
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(phases, id: \.id) { item in
                PhaseIndicator(title: item.title, state: state(for: item.id), compact: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .combine)
    }
    
    private func state(for step: ScanPhaseStep) -> PhaseIndicator.State {
        switch phase {
        case .idle:
            return .pending
        case .scanningNetwork:
            switch step {
            case .hosts: return .active
            case .ports, .done: return .pending
            }
        case .scanningPorts:
            switch step {
            case .hosts: return .completed
            case .ports: return .active
            case .done: return .pending
            }
        case .finished:
            return .completed
        }
    }
}

private enum ScanPhaseStep: Hashable {
    case hosts
    case ports
    case done
}

private struct PhaseIndicator: View {
    enum State {
        case pending
        case active
        case completed
    }
    
    let title: String
    let state: State
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                .overlay {
                    if state == .active {
                        Circle()
                            .stroke(Color.orange.opacity(0.45), lineWidth: 3)
                            .frame(width: 16, height: 16)
                    }
                }
            
            Text(title)
                .font((compact ? Font.caption : Font.subheadline).weight(state == .active ? .semibold : .regular))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, state == .active ? 8 : 0)
        .padding(.vertical, state == .active ? 4 : 0)
        .background {
            if state == .active {
                Capsule().fill(.thinMaterial)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(accessibilityState)")
    }
    
    private var dotColor: Color {
        switch state {
        case .pending: return Color.secondary.opacity(0.35)
        case .active: return Color.orange
        case .completed: return Color.green
        }
    }
    
    private var textColor: Color {
        switch state {
        case .pending: return .secondary
        case .active: return .primary
        case .completed: return .primary
        }
    }
    
    private var accessibilityState: String {
        switch state {
        case .pending: return "ausstehend"
        case .active: return "läuft"
        case .completed: return "fertig"
        }
    }
}
