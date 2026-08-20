import Foundation
import Network

#if os(iOS) || os(visionOS)
/// Triggers the iOS Local Network privacy prompt (TN3179) so subsequent
/// BSD TCP probes are not silently blocked.
enum LocalNetworkAccess {
    private static var browser: NWBrowser?
    private static var triggered = false
    
    /// Fire-and-forget Bonjour browse + local UDP connect to surface the permission alert.
    static func requestIfNeeded() {
        guard !triggered else { return }
        triggered = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: descriptor, using: params)
        Self.browser = browser
        browser.stateUpdateHandler = { _ in }
        browser.start(queue: .global(qos: .utility))
        
        // TN3179: connecting a UDP socket to a LAN address triggers the alert
        // without generating traffic.
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
        addr.sin_port = UInt16(9).bigEndian // discard
        _ = inet_pton(AF_INET, "192.168.0.1", &addr.sin_addr)
        
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(sock, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}
#endif
