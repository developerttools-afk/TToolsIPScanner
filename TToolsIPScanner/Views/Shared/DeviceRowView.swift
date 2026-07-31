import SwiftUI

struct DeviceRowView: View {
    let device: DeviceInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StatusIndicator(status: device.status)
                
                Text(device.ipAddress)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(device.hostName)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            
            if !device.manufacturer.isEmpty {
                Text(device.manufacturer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !device.openPorts.isEmpty {
                PortsPreview(ports: device.openPorts)
            }
        }
    }
} 