import SwiftUI
import Foundation

struct StatusIndicator: View {
    let status: DeviceStatus
    
    var body: some View {
        Image(systemName: statusIcon)
            .foregroundColor(statusColor)
    }
    
    private var statusIcon: String {
        switch status {
        case .current: return "circle.fill"
        case .new: return "plus.circle.fill"
        case .missing: return "minus.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .current: return .green
        case .new: return .blue
        case .missing: return .red
        }
    }
} 