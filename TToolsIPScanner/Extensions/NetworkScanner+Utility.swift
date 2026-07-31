import SwiftUI

extension NetworkScanner {
    func getPortDescription(_ port: Int) -> String {
        return NetworkConstants.portDescriptions[port] ?? "Unbekannt"
    }
    
    func getPortSymbol(_ port: Int) -> (symbol: String, color: Color)? {
        return NetworkConstants.portSymbols[port]
    }
    
    func getDeviceAlias(for key: String) -> DeviceAlias? {
        guard !key.isEmpty else { return nil }
        return deviceAliases[key]
    }
    
    func getDeviceAlias(for device: DeviceInfo) -> DeviceAlias? {
        getDeviceAlias(for: device.aliasKey)
    }
    
    func log(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.debugMessage = message
        }
    }
}
