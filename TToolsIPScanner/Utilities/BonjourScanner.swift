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

            case .service:
                // NWBrowser yields `.service`, not an IP. Resolve via a short-lived connection.
                let endpoint = result.endpoint
                let task = Task { [weak self] in
                    if let ip = await Self.resolveIPv4(endpoint) {
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

    /// Connect to a Bonjour endpoint just long enough to read the remote IPv4.
    nonisolated private static func resolveIPv4(_ endpoint: NWEndpoint) async -> String? {
        await withCheckedContinuation { continuation in
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let connection = NWConnection(to: endpoint, using: params)
            let box = ProbeStateBox()

            let finish: @Sendable (String?) -> Void = { ip in
                guard box.consume() else { return }
                connection.cancel()
                continuation.resume(returning: ip)
            }

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                finish(nil)
            }

            connection.stateUpdateHandler = { state in
                let ip = ipv4String(from: connection.currentPath?.remoteEndpoint)
                    ?? ipv4String(from: endpoint)

                switch state {
                case .ready:
                    timeoutTask.cancel()
                    finish(ip)

                case .waiting, .failed:
                    if let ip {
                        timeoutTask.cancel()
                        finish(ip)
                    } else if case .failed = state {
                        timeoutTask.cancel()
                        finish(nil)
                    }

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))
        }
    }

    nonisolated private static func ipv4String(from endpoint: NWEndpoint?) -> String? {
        guard let endpoint else { return nil }
        if case .hostPort(let host, _) = endpoint, case .ipv4(let ipv4) = host {
            return "\(ipv4)"
        }
        return nil
    }
}
#endif
