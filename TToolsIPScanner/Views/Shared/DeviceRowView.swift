import SwiftUI

struct DeviceRowView: View {
    let device: DeviceInfo
    var displayName: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                StatusIndicator(status: device.status)
                
                Text(device.ipAddress)
                    .fontWeight(.medium)
                
                PortsPreview(ports: device.openPorts)
                
                Spacer(minLength: 8)
                
                Text(displayName ?? device.hostName)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            
            if !device.manufacturer.isEmpty {
                Text(device.manufacturer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
