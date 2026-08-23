import Foundation
import Network

#if os(iOS) || os(visionOS)
/// Bonjour/mDNS discovery. Only browses service types declared in Info.plist
/// (`NSBonjourServices`); anything else fails with NoAuth(-65555).
actor BonjourScanner {
    /// Must match `NSBonjourServices` in iOS-Info.plist.
    static let declaredServiceTypes = [
        "_http._tcp",
        "_https._tcp",
        "_ssh._tcp",
        "_smb._tcp",
        "_afpovertcp._tcp",
        "_airplay._tcp",
        "_raop._tcp",
        "_printer._tcp",
        "_ipp._tcp",
        "_scanner._tcp",
        "_homekit._tcp"
    ]

    private var browsers: [NWBrowser] = []
    private var foundHosts: Set<String> = []
    private var resolveTasks: [Task<Void, Never>] = []

    func scanNetwork(timeout: TimeInterval = 2.5) async -> Set<String> {
        foundHosts.removeAll()
        resolveTasks.forEach { $0.cancel() }
        resolveTasks.removeAll()

        for serviceType in Self.declaredServiceTypes {
            browseService(serviceType)
        }

        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

        stopAll()
        return foundHosts
    }

    private func browseService(_ serviceType: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: params)
        browsers.append(browser)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { await self?.processResults(results) }
        }

        browser.start(queue: .global(qos: .utility))
    }

    private func processResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .hostPort(let host, _):
                if case .ipv4(let ipv4) = host {
                    foundHosts.insert("\(ipv4)")
                }

            case .service(let name, _, let domain, _):
                let task = Task { [weak self] in
                    if let ip = Self.ipv4(forService: name, domain: domain) {
                        await self?.record(ip)
                    }
                }
                resolveTasks.append(task)

            default:
                break
            }
        }
    }

    private func record(_ ip: String) {
        foundHosts.insert(ip)
    }

    private func stopAll() {
        resolveTasks.forEach { $0.cancel() }
        resolveTasks.removeAll()
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
    }

    /// Resolve `Name.local` via DNS — no NWConnection, so no unconnected-metadata logs.
    nonisolated private static func ipv4(forService name: String, domain: String) -> String? {
        let trimmedDomain = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let host = trimmedDomain.isEmpty ? "\(name).local" : "\(name).\(trimmedDomain)"
        return ipv4(forHost: host)
    }

    nonisolated private static func ipv4(forHost host: String) -> String? {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0, let first = info else { return nil }
        defer { freeaddrinfo(first) }

        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(
            first.pointee.ai_addr,
            first.pointee.ai_addrlen,
            &buffer,
            socklen_t(NI_MAXHOST),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 else { return nil }

        let ip = String(cString: buffer)
        return ip.contains(".") ? ip : nil
    }
}
#endif
