import Foundation
import Network

/// Triggers Local Network privacy prompt (TN3179) before LAN probes.
enum LocalNetworkAccess {
    private static var browser: NWBrowser?
    private static var triggered = false
    
    static func requestIfNeeded() {
        guard !triggered else { return }
        triggered = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = false
        let browser = NWBrowser(for: descriptor, using: params)
        Self.browser = browser
        browser.stateUpdateHandler = { _ in }
        browser.start(queue: .global(qos: .utility))
        
        triggerViaUDP()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            browser.cancel()
            if Self.browser === browser {
                Self.browser = nil
            }
        }
    }
    
    private static func triggerViaUDP() {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return }
        defer { Darwin.close(sock) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(9).bigEndian
        _ = inet_pton(AF_INET, "192.168.0.1", &addr.sin_addr)
        
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(sock, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}
