import Foundation
import Network
import dnssd

struct BonjourHostInfo: Sendable {
    var displayNames: [String] = []
    var serviceTypes: [String] = []
    /// Lowercased TXT keys (`md`, `ty`, `model`, …).
    var txt: [String: String] = [:]
    /// Hardware address from RAOP, AirPlay `deviceid`, Avahi, Shelly, or ESPHome.
    var macAddress: String?
    
    var bestName: String? {
        displayNames.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    /// Printer type / model from TXT (`ty`, `model`, `usb_mdl`, `product`).
    var modelLabel: String? {
        for key in ["ty", "model", "usb_mdl", "product"] {
            if let value = Self.cleanTXTValue(txt[key]) { return value }
        }
        return nil
    }
    
    /// Make from TXT (`md`, `usb_mfg`, `manufacturer`).
    var manufacturerLabel: String? {
        for key in ["md", "usb_mfg", "manufacturer", "mfg"] {
            if let value = Self.cleanTXTValue(txt[key]) { return value }
        }
        return nil
    }
    
    static func cleanTXTValue(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("("), value.hasSuffix(")"), value.count >= 2 {
            value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }
}

/// Bonjour/mDNS discovery. Only browsed types declared in Info.plist (`NSBonjourServices`).
actor BonjourScanner {
    /// Must match `NSBonjourServices` in iOS/macOS Info.plist.
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
        "_ipps._tcp",
        "_scanner._tcp",
        "_hap._tcp",
        "_workstation._tcp",
        "_shelly._tcp",
        "_esphomelib._tcp",
        "_home-assistant._tcp",
        "_arduino._tcp",
        "_tasmota._tcp",
        "_wled._tcp",
        "_device-info._tcp",
        "_googlecast._tcp",
        "_companion-link._tcp",
        "_spotify-connect._tcp",
        "_sonos._tcp",
        "_pdl-datastream._tcp",
        "_uscan._tcp",
        "_apple-mobdev2._tcp",
        "_apple-pairable._tcp",
        "_airport._tcp",
        "_sleep-proxy._udp",
        "_homekit._tcp",
        "_mediaremotetv._tcp",
        "_rdlink._tcp",
        "_airdrop._tcp",
        "_nfs._tcp",
        "_ftp._tcp",
        "_sftp-ssh._tcp",
        "_rfb._tcp",
        "_adisk._tcp",
        "_presence._tcp",
        "_meshcop._udp",
        "_thread._udp"
    ]
    
    private var browsers: [NWBrowser] = []
    private var activeResolves: [OpaquePointer] = []
    private var hosts: [String: BonjourHostInfo] = [:]
    
    func scanNetwork(prefix: String, timeout: TimeInterval? = nil) async -> [String: BonjourHostInfo] {
        hosts.removeAll()
        stopAll()
        
        let browseTimeout = timeout ?? NetworkConstants.bonjourBrowseTimeout
        
        for serviceType in Self.declaredServiceTypes {
            browseService(serviceType, prefix: prefix)
        }
        
        try? await Task.sleep(nanoseconds: UInt64(browseTimeout * 1_000_000_000))
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        
        stopAll()
        return hosts.filter { $0.key.hasPrefix(prefix + ".") }
    }
    
    private func browseService(_ serviceType: String, prefix: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        let params = NWParameters()
        // Peer-to-peer browse needs the multicast entitlement and otherwise logs NoAuth.
        params.includePeerToPeer = false
        
        let browser = NWBrowser(for: descriptor, using: params)
        browsers.append(browser)
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { await self?.processResults(results, serviceType: serviceType, prefix: prefix) }
        }
        
        browser.start(queue: .global(qos: .userInitiated))
    }
    
    private func processResults(_ results: Set<NWBrowser.Result>, serviceType: String, prefix: String) {
        for result in results {
            switch result.endpoint {
            case .hostPort(let host, _):
                if case .ipv4(let ipv4) = host {
                    let ip = "\(ipv4)"
                    guard ip.hasPrefix(prefix + ".") else { continue }
                    record(ip: ip, name: nil, serviceType: serviceType)
                }
                
            case .service(let name, let type, let domain, _):
                let resolvedType = type.isEmpty ? serviceType : type
                let resolvedDomain = domain.isEmpty ? "local." : domain
                startResolve(
                    instanceName: name,
                    type: resolvedType,
                    domain: resolvedDomain,
                    prefix: prefix,
                    serviceType: serviceType
                )
                
            default:
                break
            }
        }
    }
    
    private func startResolve(
        instanceName: String,
        type: String,
        domain: String,
        prefix: String,
        serviceType: String
    ) {
        let context = Unmanaged.passRetained(
            ResolveContext(
                scanner: self,
                instanceName: instanceName,
                serviceType: serviceType,
                prefix: prefix
            )
        ).toOpaque()
        
        var serviceRef: DNSServiceRef?
        let err = DNSServiceResolve(
            &serviceRef,
            0,
            0,
            instanceName,
            type,
            domain,
            resolveReply,
            context
        )
        
        guard err == kDNSServiceErr_NoError, let serviceRef else {
            Unmanaged<ResolveContext>.fromOpaque(context).release()
            return
        }
        
        let ctx = Unmanaged<ResolveContext>.fromOpaque(context).takeUnretainedValue()
        ctx.serviceRef = serviceRef
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        guard DNSServiceSetDispatchQueue(serviceRef, queue) == kDNSServiceErr_NoError else {
            DNSServiceRefDeallocate(serviceRef)
            Unmanaged<ResolveContext>.fromOpaque(context).release()
            return
        }
        
        queue.asyncAfter(deadline: .now() + 3.5) {
            ctx.finish()
        }
    }
    
    fileprivate func record(ip: String, name: String?, serviceType: String, txt: [String: String] = [:]) {
        var info = hosts[ip] ?? BonjourHostInfo()
        let identity = MACAddress.bonjourIdentity(serviceType: serviceType, instanceName: name, txt: txt)
        if info.macAddress == nil {
            info.macAddress = identity.mac
        }
        if let name {
            let cleaned = Self.cleanBonjourName(identity.displayName ?? name)
            if !cleaned.isEmpty, !info.displayNames.contains(cleaned) {
                info.displayNames.append(cleaned)
            }
        }
        if !info.serviceTypes.contains(serviceType) {
            info.serviceTypes.append(serviceType)
        }
        for (key, value) in txt {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            if info.txt[key]?.isEmpty != false {
                info.txt[key] = cleaned
            }
        }
        hosts[ip] = info
    }
    
    /// DNS-SD TXT: a sequence of length-prefixed key=value strings.
    nonisolated static func parseTXT(_ data: Data) -> [String: String] {
        var result: [String: String] = [:]
        let bytes = [UInt8](data)
        var index = 0
        while index < bytes.count {
            let length = Int(bytes[index])
            index += 1
            guard length > 0, index + length <= bytes.count else { break }
            let slice = bytes[index..<(index + length)]
            index += length
            let pair = String(bytes: slice, encoding: .utf8)
                ?? String(bytes: slice, encoding: .isoLatin1)
                ?? ""
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(parts.first ?? "").lowercased()
            guard !key.isEmpty else { continue }
            let value = parts.count > 1 ? String(parts[1]) : ""
            if result[key] == nil {
                result[key] = value
            }
        }
        return result
    }
    
    nonisolated static func cleanBonjourName(_ name: String) -> String {
        var n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.lowercased().hasSuffix(".local") {
            n = String(n.dropLast(6))
        }
        // Strip DNS-SD instance escapes if any.
        n = n.replacingOccurrences(of: "\\032", with: " ")
        n = n.replacingOccurrences(of: "\\.", with: ".")
        return n.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func stopAll() {
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
    }
}

fileprivate final class ResolveContext: @unchecked Sendable {
    let scanner: BonjourScanner
    let instanceName: String
    let serviceType: String
    let prefix: String
    var serviceRef: DNSServiceRef?
    private let lock = NSLock()
    private var done = false
    
    init(scanner: BonjourScanner, instanceName: String, serviceType: String, prefix: String) {
        self.scanner = scanner
        self.instanceName = instanceName
        self.serviceType = serviceType
        self.prefix = prefix
    }
    
    func handle(hostTarget: String?, txt: [String: String] = [:]) {
        guard let hostTarget, !hostTarget.isEmpty else { return }
        
        // hosttarget is typically "Device-Name.local" — resolve to IPv4.
        let ip = Self.ipv4(forHost: hostTarget)
        let display = BonjourScanner.cleanBonjourName(hostTarget)
        let instance = BonjourScanner.cleanBonjourName(instanceName)
        let best = display.isEmpty ? instance : display
        
        guard let ip, ip.hasPrefix(prefix + ".") else { return }
        Task {
            await scanner.record(ip: ip, name: best.isEmpty ? nil : best, serviceType: serviceType, txt: txt)
            if !instance.isEmpty, instance != best {
                await scanner.record(ip: ip, name: instance, serviceType: serviceType, txt: txt)
            }
        }
        finish()
    }
    
    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        if let serviceRef {
            DNSServiceRefDeallocate(serviceRef)
            self.serviceRef = nil
        }
        Unmanaged.passUnretained(self).release()
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

private let resolveReply: DNSServiceResolveReply = { _, _, _, errorCode, _, hosttarget, _, txtLen, txtRecord, context in
    guard let context else { return }
    let ctx = Unmanaged<ResolveContext>.fromOpaque(context).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else { return }
    let host = hosttarget.map { String(cString: $0) }
    let txt = txtRecord.map { pointer in
        BonjourScanner.parseTXT(Data(bytes: pointer, count: Int(txtLen)))
    } ?? [:]
    ctx.handle(hostTarget: host, txt: txt)
}
