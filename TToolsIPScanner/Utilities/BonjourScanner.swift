import Foundation
import Network

#if os(iOS) || os(visionOS)
/// Bonjour/mDNS network scanner for iOS
/// Finds devices that advertise services via Bonjour
actor BonjourScanner {
    private var browsers: [NWBrowser] = []
    private var foundHosts: Set<String> = []
    
    /// Scan for devices using Bonjour/mDNS
    /// Returns set of IP addresses found
    func scanNetwork(timeout: TimeInterval = 3.0) async -> Set<String> {
        foundHosts.removeAll()
        
        // Common Bonjour service types that many devices advertise
        let serviceTypes = [
            "_http._tcp",       // Web servers, routers
            "_https._tcp",      // Secure web
            "_ssh._tcp",        // SSH servers
            "_smb._tcp",        // Windows shares, NAS
            "_afpovertcp._tcp", // Apple File Protocol
            "_airplay._tcp",    // AirPlay devices
            "_raop._tcp",       // AirPlay audio
            "_printer._tcp",    // Network printers
            "_ipp._tcp",        // Internet Printing Protocol
            "_scanner._tcp",    // Network scanners
            "_homekit._tcp"     // HomeKit devices
        ]
        
        // Start all browsers
        for serviceType in serviceTypes {
            browseService(serviceType)
        }
        
        // Give services time to respond
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        
        // Clean up all browsers
        stopAll()
        
        return foundHosts
    }
    
    private func browseService(_ serviceType: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = true
        
        let browser = NWBrowser(for: descriptor, using: params)
        browsers.append(browser)
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task {
                await self?.processResults(results)
            }
        }
        
        browser.start(queue: .global(qos: .utility))
    }
    
    private func processResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                // Extract IP from service name if possible
                print("🔍 Bonjour found: \(name).\(type).\(domain)")
                
                // Try to resolve endpoint to get IP
                if case .hostPort(let host, _) = result.endpoint {
                    if case .ipv4(let ipv4) = host {
                        let ipString = "\(ipv4)"
                        foundHosts.insert(ipString)
                        print("✅ Bonjour IP: \(ipString)")
                    }
                }
                
            case .hostPort(let host, _):
                if case .ipv4(let ipv4) = host {
                    let ipString = "\(ipv4)"
                    foundHosts.insert(ipString)
                    print("✅ Bonjour IP: \(ipString)")
                }
                
            default:
                break
            }
        }
    }
    
    private func stopAll() {
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
    }
}
#endif
