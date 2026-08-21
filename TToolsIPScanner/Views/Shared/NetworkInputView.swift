import SwiftUI

struct NetworkInputView: View {
    @ObservedObject var scanner: NetworkScanner
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Aktuelles Netzwerk:")
                TextField("IP-Adresse", text: $scanner.currentNetwork)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
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
            
            if let error = scanner.scanError {
                ErrorMessageView(error: error)
            }
            
            if !scanner.recentNetworks.isEmpty {
                HStack {
                    Text("Zuletzt gescannt:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(scanner.recentNetworks, id: \.self) { network in
                        Button(action: {
                            scanner.currentNetwork = network
                            scanner.updateNetworkRange()
                            scanner.startScan(baseIP: network, mode: scanner.preferredScanMode)
                        }) {
                            Text(network)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
