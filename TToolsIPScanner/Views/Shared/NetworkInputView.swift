import SwiftUI

struct NetworkInputView: View {
    @ObservedObject var scanner: NetworkScanner
    var showsCaption: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if showsCaption {
                    Text("Aktuelles Netzwerk:")
                }
                TextField("IP-Adresse", text: $scanner.currentNetwork)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: showsCaption ? 200 : .infinity)
                    .onChange(of: scanner.currentNetwork) { _, _ in
                        scanner.updateNetworkRange()
                        scanner.scanError = nil
                    }
                    .onSubmit {
                        if !scanner.currentNetwork.isEmpty {
                            scanner.startScan(baseIP: scanner.currentNetwork, mode: scanner.preferredScanMode)
                        }
                    }
            }
            
            if !scanner.networkRange.isEmpty {
                Text(scanner.networkRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !scanner.subnetScanNote.isEmpty {
                Text(scanner.subnetScanNote)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if let error = scanner.scanError {
                ErrorMessageView(error: error)
            }
            
            if !scanner.recentNetworks.isEmpty {
                HStack {
                    Text("Zuletzt gescannt:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        ForEach(scanner.recentNetworks, id: \.self) { network in
                            Button(action: {
                                scanner.currentNetwork = network
                                scanner.updateNetworkRange()
                                scanner.startScan(baseIP: network, mode: scanner.preferredScanMode)
                            }) {
                                Text(network)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.thinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
