import Foundation
import SystemConfiguration
import Darwin

extension NetworkScanner {
    struct CachedDeviceSnapshot {
        var id: UUID
        var hostName: String
        var macAddress: String
        var manufacturer: String
        var openPorts: [Int]
        var bonjourName: String
        var netbiosName: String
        var dnsName: String
        var mdnsName: String
        var detailHint: String
        var osHint: String
        var advertisedServices: [String]
        var firstSeen: Date?
        var lastSeen: Date?
        var category: DeviceCategory
    }
    
    private struct DeviceResolution {
        var hostName: String
        var macAddress: String
        var manufacturer: String
        var openPorts: [Int]
        var bonjourName: String
        var netbiosName: String
        var dnsName: String
        var mdnsName: String
        var detailHint: String
        var osHint: String
        var advertisedServices: [String]
        var category: DeviceCategory
    }
    
    func startScan(baseIP: String? = nil, mode: ScanMode = .quickScan) {
        let ipToScan = baseIP ?? currentNetwork
        scanError = nil
        
        // Validiere IP-Adresse
        guard IPAddressValidator.isValidIPv4(ipToScan) else {
            scanError = .invalidIPAddress(ipToScan)
            return
        }
        
        // Prüfe ob bereits ein Scan läuft
        guard !isScanning, devicePortScanIP == nil else {
            scanError = .scanAlreadyRunning
            return
        }
        
        // Prüfe ob Ports konfiguriert sind
        guard !customPorts.isEmpty || mode == .fullScan else {
            scanError = .noPortsSpecified
            return
        }
        
        preferredScanMode = mode
        currentNetwork = ipToScan
        refreshSubnet(from: ipToScan)
        
        // Cancel prefetch / prior scan
        cancelBackgroundPrefetch()
        currentScanTask?.cancel()
        
        // Start new scan task
        currentScanTask = Task { [weak self] in
            guard let self else { return }
            
            #if os(iOS) || os(visionOS)
            LocalNetworkAccess.requestIfNeeded()
            let hasWarmCache = prefetchCache?.networkPrefix == currentSubnet?.prefix
                && prefetchCache?.isFresh == true
            if !hasWarmCache {
                await self.updateScanState(
                    isScanning: true,
                    phase: .scanningNetwork,
                    progress: "Lokalen Netzwerkzugriff prüfen…",
                    percentage: 0
                )
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            #else
            LocalNetworkAccess.requestIfNeeded()
            #endif
            
            await self.beginScanPipeline(ipToScan: ipToScan, mode: mode)
        }
    }
    
    /// Helper to update scan state on MainActor
    private func updateScanState(
        isScanning: Bool? = nil,
        phase: ScanPhase? = nil,
        progress: String? = nil,
        percentage: Double? = nil,
        currentIP: String? = nil
    ) async {
        await MainActor.run {
            if let isScanning = isScanning { self.isScanning = isScanning }
            if let phase = phase { self.scanPhase = phase }
            if let progress = progress { self.scanProgress = progress }
            if let percentage = percentage { self.progressPercentage = percentage }
            if let currentIP = currentIP { self.currentScanIP = currentIP }
        }
    }
    
    private func beginScanPipeline(ipToScan: String, mode: ScanMode) async {
        guard !Task.isCancelled else { return }
        
        let subnet = await MainActor.run { () -> SubnetConfig in
            let components = ipToScan.split(separator: ".")
            if components.count >= 3 {
                let baseNetwork = components.dropLast().joined(separator: ".")
                let network = baseNetwork + ".0"
                if !self.recentNetworks.contains(network) {
                    self.recentNetworks.insert(network, at: 0)
                    if self.recentNetworks.count > 3 {
                        self.recentNetworks.removeLast()
                    }
                }
            }
            
            let subnet = self.currentSubnet
                ?? SubnetConfig.from(localIP: ipToScan, netmask: nil)
            self.currentSubnet = subnet
            
            // Drop results from other LANs — show only the network being scanned.
            self.devices = self.devices.filter { subnet.contains($0.ipAddress) }
            self.previousDevices = Set(
                self.devices.filter { $0.status != .missing }.map(\.ipAddress)
            )
            self.saveSettings()
            return subnet
        }
        
        let cachedDetails: [String: CachedDeviceSnapshot] = await MainActor.run {
            var map: [String: CachedDeviceSnapshot] = Dictionary(
                uniqueKeysWithValues: devices
                    .filter { $0.status != .missing }
                    .map { device in
                        (device.ipAddress, self.cachedSnapshot(from: device))
                    }
            )
            if let prefetch = self.prefetchSnapshot(for: subnet.prefix) {
                for device in prefetch.devices where subnet.contains(device.ipAddress) {
                    map[device.ipAddress] = self.cachedSnapshot(from: device)
                }
            }
            return map
        }
        
        await updateScanState(
            isScanning: true,
            phase: .scanningNetwork,
            progress: "Scan gestartet…",
            percentage: 0
        )
        
        await startIPScan(
            baseIP: ipToScan,
            mode: mode,
            cachedDetails: cachedDetails
        )
    }
    
    private func startIPScan(
        baseIP: String,
        mode: ScanMode,
        cachedDetails: [String: CachedDeviceSnapshot]
    ) async {
        let subnet = await MainActor.run {
            self.currentSubnet ?? SubnetConfig.from(localIP: baseIP, netmask: nil)
        }
        let basePrefix = subnet.prefix
        let hostNumbers = subnet.hostNumbers
        let totalIPs = subnet.totalHosts
        let previousDevices = await MainActor.run { self.previousDevices }
        let ouiDB = await MainActor.run { self.ouiDatabase }
        
        let discoveryHits = ResolutionStore<String, [Int]>()
        var alreadyListed = Set<String>()
        var bonjourByIP: [String: BonjourHostInfo] = [:]
        var ttlByIP: [String: UInt8] = [:]
        var arpMap = ARPTable.entries(matchingPrefix: basePrefix)
        let routerTask = Task { await self.fetchRouterMACOverlay(prefix: basePrefix) }
        
        let depth = await MainActor.run { self.preferredDiscoveryDepth }
        let warmPrefetch = prefetchSnapshot(for: basePrefix)
        
        if depth != .fast {
            if let warmPrefetch {
                await updateScanState(
                    progress: "Nutze Hintergrund-Scan (\(warmPrefetch.devices.count) Hosts)…",
                    percentage: 8
                )
                bonjourByIP = warmPrefetch.bonjourByIP
                for device in warmPrefetch.devices {
                    guard !Self.isBroadcastOrNetworkAddress(device.ipAddress) else { continue }
                    alreadyListed.insert(device.ipAddress)
                    let ports = warmPrefetch.discoveryPortsByIP[device.ipAddress] ?? device.openPorts
                    discoveryHits.set(ports, for: device.ipAddress)
                    upsertDevice(device)
                }
                scanProgress = "\(devices.count) Gerät(e) gefunden"
            } else {
                LocalNetworkAccess.requestIfNeeded()
                await updateScanState(
                    progress: "Suche Geräte (Ping + Bonjour + UPnP)…",
                    percentage: 2
                )
                
                let gatewayIP = GatewayProbe.defaultGatewayIP()
                    ?? (hostNumbers.contains(1) ? "\(basePrefix).1" : nil)
                
                let bonjourScanner = BonjourScanner()
                async let bonjourTask = bonjourScanner.scanNetwork(prefix: basePrefix)
                async let pingTask = ICMPPinger.sweep(prefix: basePrefix, hostNumbers: subnet.hostNumberSet)
                async let ssdpTask = SSDPDiscovery.scan(prefix: basePrefix, timeout: 3.0)
                async let gatewayTask: GatewayEnrichment? = {
                    guard let gatewayIP else { return nil }
                    return await GatewayProbe.enrich(gatewayIP: gatewayIP)
                }()
                
                let pingResult = await pingTask
                bonjourByIP = await bonjourTask
                let upnpByIP = await ssdpTask
                let gatewayInfo = await gatewayTask
                
                var preFound = pingResult.alive
                ttlByIP = pingResult.ttlByIP
                preFound.formUnion(bonjourByIP.keys)
                preFound.formUnion(upnpByIP.keys)
                if let gatewayIP { preFound.insert(gatewayIP) }
                
                let missingAfterPing = Set(subnet.allIPs).subtracting(preFound)
                if !missingAfterPing.isEmpty {
                    let retryNumbers = Set(missingAfterPing.compactMap { ip -> Int? in
                        guard ip.hasPrefix(basePrefix + "."),
                              let last = ip.split(separator: ".").last,
                              let n = Int(last) else { return nil }
                        return n
                    })
                    if !retryNumbers.isEmpty {
                        let retry = await ICMPPinger.sweep(
                            prefix: basePrefix,
                            hostNumbers: retryNumbers,
                            timeout: NetworkConstants.icmpRetryTimeout
                        )
                        preFound.formUnion(retry.alive)
                        for (ip, ttl) in retry.ttlByIP { ttlByIP[ip] = ttl }
                    }
                }
                
                await routerTask.value
                arpMap = self.mergedMACMap(prefix: basePrefix)
                preFound.formUnion(arpMap.keys)
                
                for ip in preFound.sorted(by: Self.ipSort) {
                    guard !Task.isCancelled else { return }
                    guard !Self.isBroadcastOrNetworkAddress(ip) else { continue }
                    alreadyListed.insert(ip)
                    discoveryHits.set([], for: ip)
                    let bj = bonjourByIP[ip]
                    var device = makeDiscoveredDevice(
                        ip: ip,
                        openPorts: [],
                        previousDevices: previousDevices,
                        cachedDetails: cachedDetails,
                        bonjour: bj,
                        osHint: ttlByIP[ip].map { ICMPPinger.osHintFromTTL($0) } ?? "",
                        ouiDB: ouiDB,
                        arpMap: arpMap
                    )
                    if let upnp = upnpByIP[ip] {
                        device = Self.enriched(device, with: upnp, ouiDB: ouiDB)
                    }
                    if let gatewayInfo, gatewayInfo.ip == ip {
                        device = Self.enriched(device, with: gatewayInfo, ouiDB: ouiDB)
                    }
                    upsertDevice(device)
                    scanProgress = "\(devices.count) Gerät(e) gefunden"
                }
                
                let needsPortProbe = preFound.filter { ip in
                    (cachedDetails[ip]?.openPorts ?? []).isEmpty
                }
                if !needsPortProbe.isEmpty {
                    await updateScanState(
                        progress: "Prüfe Ports auf \(needsPortProbe.count) Hosts…",
                        percentage: 12
                    )
                    await fillDiscoveredHostPorts(
                        ips: needsPortProbe.sorted(by: Self.ipSort),
                        ports: portsForScan(mode),
                        hits: discoveryHits
                    )
                }
            }
        }
        
        await routerTask.value
        arpMap = self.mergedMACMap(prefix: basePrefix)
        applyRouterOverlayToDevices()
        
        await updateScanState(
            progress: alreadyListed.isEmpty
                ? "Starte Scan von \(totalIPs) IPs auf \(basePrefix).0/\(subnet.prefixLength)…"
                : "\(alreadyListed.count) per Ping/Bonjour — prüfe restliche IPs…",
            percentage: alreadyListed.isEmpty ? 5 : 15
        )
        
        let maxConcurrentScans = depth == .fast
            ? NetworkConstants.phase1HostConcurrencyFast
            : NetworkConstants.phase1HostConcurrencyNormal
        
        await withTaskGroup(of: (Int, String, [Int]?, DeviceInfo?).self) { group in
            var hostIterator = hostNumbers.makeIterator()
            let skipIPs = alreadyListed
            
            func enqueue(_ host: Int) {
                group.addTask {
                    guard !Task.isCancelled else { return (host, "", nil, nil) }
                    let ip = subnet.ip(for: host)
                    if skipIPs.contains(ip) || Self.isBroadcastOrNetworkAddress(ip) {
                        return (host, ip, nil, nil)
                    }
                    // BSD connect (same on iOS/macOS) — NWConnection floods iOS NECP and is much slower.
                    let (isAlive, foundPorts) = await Task.detached(priority: .userInitiated) {
                        self.discoverHost(ip, depth: depth)
                    }.value
                    guard isAlive else { return (host, ip, nil, nil) }
                    let device = await self.makeDiscoveredDevice(
                        ip: ip,
                        openPorts: foundPorts,
                        previousDevices: previousDevices,
                        cachedDetails: cachedDetails,
                        bonjour: bonjourByIP[ip],
                        osHint: ttlByIP[ip].map { ICMPPinger.osHintFromTTL($0) } ?? "",
                        ouiDB: ouiDB,
                        arpMap: arpMap
                    )
                    return (host, ip, foundPorts, device)
                }
            }
            
            var inFlight = 0
            while inFlight < maxConcurrentScans, let host = hostIterator.next() {
                enqueue(host)
                inFlight += 1
            }
            
            var completedCount = 0
            var foundCount = alreadyListed.count
            for await (_, ip, foundPorts, device) in group {
                guard !Task.isCancelled else { break }
                
                if let nextHost = hostIterator.next() {
                    enqueue(nextHost)
                }
                
                if let foundPorts {
                    discoveryHits.set(foundPorts, for: ip)
                }
                
                if let device, alreadyListed.insert(ip).inserted {
                    foundCount += 1
                    upsertDevice(device)
                    currentScanIP = ip
                    scanProgress = "\(foundCount) Gerät(e) gefunden"
                }
                
                completedCount += 1
                inFlight -= 1
                if completedCount % 10 == 0 || device != nil {
                    currentScanIP = ip
                    if device == nil {
                        scanProgress = "Scanne \(completedCount)/\(totalIPs)… (\(foundCount) gefunden)"
                    }
                    await updateScanState(percentage: min(50, Double(completedCount) * 50.0 / Double(totalIPs)))
                }
            }
        }
        
        await supplementDiscovery(
            subnet: subnet,
            basePrefix: basePrefix,
            alreadyListed: &alreadyListed,
            cachedDetails: cachedDetails,
            previousDevices: previousDevices,
            bonjourByIP: bonjourByIP,
            ttlByIP: &ttlByIP,
            ouiDB: ouiDB,
            arpMap: &arpMap,
            depth: depth
        )
        
        guard !Task.isCancelled else { return }
        
        await resolveAndScanDevices(
            mode: mode,
            cachedDetails: cachedDetails,
            discoveryPorts: discoveryHits.snapshot(),
            ouiDB: ouiDB,
            usedPrefetch: warmPrefetch != nil
        )
    }
    
    /// Phase 2: OUI + names first (fast UI), then custom/full port scan.
    private func resolveAndScanDevices(
        mode: ScanMode,
        cachedDetails: [String: CachedDeviceSnapshot],
        discoveryPorts: [String: [Int]],
        ouiDB: [String: String],
        usedPrefetch: Bool = false
    ) async {
        let snapshot = await MainActor.run { self.devices }
        guard !snapshot.isEmpty else {
            await finishScan(devices: snapshot)
            return
        }
        
        let totalDevices = snapshot.count
        let portsToProbe = portsForScan(mode)
        let resolutions = ResolutionStore<UUID, DeviceResolution>()
        let prefix = await MainActor.run { self.currentSubnet?.prefix }
            ?? snapshot.first.map { $0.ipAddress.split(separator: ".").dropLast().joined(separator: ".") }
            ?? ""
        let arpMap = mergedMACMap(prefix: prefix)
        
        await updateScanState(
            phase: .scanningPorts,
            progress: "Hosts: \(totalDevices) — Namen auflösen…",
            percentage: 55,
            currentIP: ""
        )
        
        // Second Bonjour pass — skip when prefetch already delivered names.
        if !prefix.isEmpty, !usedPrefetch {
            await updateScanState(progress: "Bonjour-Namen…", percentage: 52)
            let lateBonjour = await BonjourScanner().scanNetwork(
                prefix: prefix,
                timeout: NetworkConstants.bonjourBrowseTimeout * 0.55
            )
            if !lateBonjour.isEmpty {
                await MainActor.run {
                    for (ip, info) in lateBonjour {
                        guard let idx = self.devices.firstIndex(where: { $0.ipAddress == ip }) else { continue }
                        self.mergeBonjour(info, into: &self.devices[idx])
                    }
                }
            }
        }
        
        let snapshotForNames = await MainActor.run { self.devices }
        
        // Instant manufacturer fill from known MAC / ARP + OUI, or from the host name when iOS has no MAC.
        await MainActor.run {
            for device in snapshotForNames {
                let mac = arpMap[device.ipAddress]
                    ?? (device.macAddress.isEmpty ? nil : device.macAddress)
                    ?? ""
                let proposed = self.resolveManufacturer(
                    mac: mac,
                    names: [
                        device.hostName,
                        device.bonjourName,
                        device.mdnsName,
                        device.dnsName,
                        device.netbiosName,
                        device.detailHint
                    ],
                    bonjour: nil,
                    ouiDB: ouiDB
                )
                self.updateDevice(id: device.id) { item in
                    if !mac.isEmpty, item.macAddress.isEmpty { item.macAddress = mac }
                    if self.shouldUpgradeManufacturer(current: item.manufacturer, proposed: proposed) {
                        item.manufacturer = proposed
                    }
                }
            }
        }
        
        // Name pass — resolve missing names; always try DNS even when Bonjour already named the host.
        let nameTargets = snapshotForNames.filter { device in
            guard !Self.isBroadcastOrNetworkAddress(device.ipAddress) else { return false }
            if device.macAddress.isEmpty { return true }
            let cached = cachedDetails[device.ipAddress]
            if needsDNSResolution(device: device, cached: cached) { return true }
            return !isWellIdentified(device)
                && !isWellIdentified(
                    hostName: cached?.hostName,
                    bonjour: cached?.bonjourName ?? device.bonjourName,
                    mdns: cached?.mdnsName ?? device.mdnsName,
                    netbios: cached?.netbiosName ?? device.netbiosName,
                    dns: cached?.dnsName ?? device.dnsName
                )
        }
        if !nameTargets.isEmpty {
            await withTaskGroup(of: (UUID, NameResolution, String).self) { group in
                var iterator = nameTargets.makeIterator()
                let nameTotal = nameTargets.count
                let maxConcurrent = NetworkConstants.nameResolveConcurrency
                
                func enqueue(_ device: DeviceInfo) {
                    group.addTask {
                        let result = await self.resolveHostNamesFast(
                            device: device,
                            cached: cachedDetails[device.ipAddress]
                        )
                        return (device.id, result, device.ipAddress)
                    }
                }
                
                for _ in 0..<min(maxConcurrent, nameTotal) {
                    if let device = iterator.next() {
                        await updateScanState(
                            progress: "Name: \(device.ipAddress) (0/\(nameTotal))",
                            percentage: 55,
                            currentIP: device.ipAddress
                        )
                        enqueue(device)
                    }
                }
                
                var done = 0
                for await (id, resolution, ip) in group {
                    done += 1
                    await MainActor.run {
                        self.updateDevice(id: id) { item in
                            item.hostName = resolution.hostName
                            item.dnsName = resolution.dnsName
                            item.mdnsName = resolution.mdnsName
                            if !resolution.netbios.isEmpty { item.netbiosName = resolution.netbios }
                            self.applyLearnedMAC(resolution.macAddress, to: &item)
                        }
                        self.currentScanIP = ip
                    }
                    let nameProgress = 55 + (Double(done) / Double(nameTotal)) * 15
                    if let next = iterator.next() {
                        await updateScanState(
                            progress: "Name: \(next.ipAddress) (\(done)/\(nameTotal))",
                            percentage: nameProgress,
                            currentIP: next.ipAddress
                        )
                        enqueue(next)
                    } else {
                        await updateScanState(
                            progress: "Namen fertig (\(done)/\(nameTotal))",
                            percentage: nameProgress,
                            currentIP: ip
                        )
                    }
                }
            }
        }
        
        guard !Task.isCancelled else { return }
        
        let freshSnapshot = await MainActor.run { self.devices }
        await MainActor.run {
            self.scanDebugDetail = "Name→Ports Übergang · \(freshSnapshot.count) Hosts"
            self.debugMessage = self.scanDebugDetail
        }
        
        let firstPortIP = freshSnapshot.first?.ipAddress ?? ""
        await updateScanState(
            progress: firstPortIP.isEmpty
                ? "Ports & Details…"
                : "Ports: \(firstPortIP) (0/\(freshSnapshot.count))",
            percentage: 70,
            currentIP: firstPortIP
        )
        
        await withTaskGroup(of: (UUID, Int, DeviceResolution).self) { group in
            var iterator = freshSnapshot.makeIterator()
            let maxConcurrent = 16
            
            func enqueue(_ device: DeviceInfo, index: Int) {
                group.addTask {
                    guard !Task.isCancelled else {
                        return (device.id, index, DeviceResolution(
                            hostName: device.hostName,
                            macAddress: device.macAddress,
                            manufacturer: device.manufacturer,
                            openPorts: device.openPorts,
                            bonjourName: device.bonjourName,
                            netbiosName: device.netbiosName,
                            dnsName: device.dnsName,
                            mdnsName: device.mdnsName,
                            detailHint: device.detailHint,
                            osHint: device.osHint,
                            advertisedServices: device.advertisedServices,
                            category: device.category
                        ))
                    }
                    
                    let probed = discoveryPorts[device.ipAddress] ?? device.openPorts
                    let remainingPorts = portsToProbe.filter { !probed.contains($0) }
                    let cached = cachedDetails[device.ipAddress]
                    let identified = self.isWellIdentified(device)
                        || self.isWellIdentified(
                            hostName: cached?.hostName,
                            bonjour: cached?.bonjourName ?? device.bonjourName,
                            mdns: cached?.mdnsName ?? device.mdnsName,
                            netbios: cached?.netbiosName ?? device.netbiosName,
                            dns: cached?.dnsName ?? device.dnsName
                        )
                    // Quick scan + already known → skip heavy enrichment.
                    if mode == .quickScan, identified, remainingPorts.isEmpty {
                        return (device.id, index, DeviceResolution(
                            hostName: device.hostName,
                            macAddress: device.macAddress.isEmpty ? (cached?.macAddress ?? "") : device.macAddress,
                            manufacturer: device.manufacturer.isEmpty ? (cached?.manufacturer ?? device.manufacturer) : device.manufacturer,
                            openPorts: probed,
                            bonjourName: device.bonjourName,
                            netbiosName: device.netbiosName,
                            dnsName: device.dnsName,
                            mdnsName: device.mdnsName,
                            detailHint: device.detailHint,
                            osHint: device.osHint,
                            advertisedServices: device.advertisedServices,
                            category: device.category
                        ))
                    }
                    
                    await MainActor.run {
                        self.currentScanIP = device.ipAddress
                        self.scanDebugDetail = remainingPorts.isEmpty
                            ? "ports skip \(device.ipAddress) (bereits bekannt)"
                            : "ports… \(device.ipAddress) · \(remainingPorts.count) Ports"
                    }
                    
                    let scanned: [Int]
                    if remainingPorts.isEmpty {
                        scanned = []
                    } else {
                        let ip = device.ipAddress
                        let portTimeout = NetworkConstants.phase2PortTimeout
                        scanned = await Task.detached(priority: .userInitiated) {
                            self.probeOpenPorts(ip, ports: remainingPorts, timeout: portTimeout)
                        }.value
                    }
                    let openPorts = Array(Set(probed + scanned)).sorted()
                    
                    await MainActor.run {
                        self.updateDevice(id: device.id) { item in
                            item.openPorts = openPorts
                        }
                        self.currentScanIP = device.ipAddress
                        self.scanDebugDetail = "ports done \(device.ipAddress) · open=\(openPorts)"
                    }
                    
                    var (macAddress, manufacturer, portOsHint) = self.getMacAddress(
                        for: device.ipAddress,
                        openPorts: openPorts,
                        knownHostName: device.bonjourName.isEmpty ? device.hostName : device.bonjourName,
                        knownMac: device.macAddress,
                        arpMap: arpMap,
                        ouiDB: ouiDB
                    )
                    if macAddress.isEmpty {
                        macAddress = cached?.macAddress ?? device.macAddress
                    }
                    if !macAddress.isEmpty {
                        let ouiVendor = self.lookupManufacturer(mac: macAddress, ouiDB: ouiDB)
                        if ouiVendor != OUIParser.unknownManufacturer && ouiVendor != OUIParser.privateMACLabel {
                            manufacturer = ouiVendor
                        } else if self.shouldUpgradeManufacturer(current: manufacturer, proposed: ouiVendor) {
                            manufacturer = ouiVendor
                        }
                    }
                    if OUIParser.placeholderManufacturers.contains(manufacturer) {
                        if let cachedManufacturer = cached?.manufacturer,
                           self.shouldUpgradeManufacturer(current: manufacturer, proposed: cachedManufacturer) {
                            manufacturer = cachedManufacturer
                        } else if self.shouldUpgradeManufacturer(current: manufacturer, proposed: device.manufacturer) {
                            manufacturer = device.manufacturer
                        }
                    }
                    await self.migrateAliasIfNeeded(ip: device.ipAddress, mac: macAddress)
                    
                    // Banners only for hosts with relevant ports — keep phase 2 snappy.
                    let bannerResult: BannerGrabber.Result
                    if openPorts.contains(where: { [22, 80, 443, 8080, 6053, 8123].contains($0) }) {
                        await MainActor.run { self.scanDebugDetail = "banner… \(device.ipAddress)" }
                        bannerResult = await BannerGrabber.probe(ip: device.ipAddress, openPorts: openPorts)
                    } else {
                        bannerResult = BannerGrabber.Result()
                    }
                    
                    var snmpHint: String?
                    if openPorts.contains(161) {
                        await MainActor.run { self.scanDebugDetail = "snmp… \(device.ipAddress)" }
                        snmpHint = await SNMPProbe.sysDescr(ip: device.ipAddress, timeout: 0.6)
                    }
                    
                    await MainActor.run {
                        self.scanDebugDetail = "enrich done \(device.ipAddress)"
                    }
                    
                    if !bannerResult.manufacturer.isEmpty,
                       self.shouldUpgradeManufacturer(current: manufacturer, proposed: bannerResult.manufacturer)
                        || DeviceFingerprint.replaces(current: manufacturer, with: bannerResult.manufacturer) {
                        manufacturer = bannerResult.manufacturer
                    }
                    
                    var osHint = device.osHint
                    if osHint.isEmpty, let portOsHint, !portOsHint.isEmpty { osHint = portOsHint }
                    if bannerResult.osHint == "Raspberry Pi OS" {
                        osHint = bannerResult.osHint
                    } else if (osHint.isEmpty || osHint == "Unix/Linux?"), !bannerResult.osHint.isEmpty {
                        osHint = bannerResult.osHint
                    }
                    
                    var detailHint = bannerResult.detailHint.isEmpty ? device.detailHint : bannerResult.detailHint
                    if detailHint.isEmpty, let snmpHint, !snmpHint.isEmpty {
                        detailHint = snmpHint
                    }
                    
                    let category = DeviceCategoryResolver.categorize(
                        ipAddress: device.ipAddress,
                        openPorts: openPorts,
                        manufacturer: manufacturer,
                        advertisedServices: device.advertisedServices,
                        hostName: device.hostName,
                        osHint: osHint
                    )
                    
                    return (device.id, index, DeviceResolution(
                        hostName: device.hostName,
                        macAddress: macAddress,
                        manufacturer: manufacturer,
                        openPorts: openPorts,
                        bonjourName: device.bonjourName,
                        netbiosName: device.netbiosName,
                        dnsName: device.dnsName,
                        mdnsName: device.mdnsName,
                        detailHint: detailHint,
                        osHint: osHint,
                        advertisedServices: device.advertisedServices,
                        category: category
                    ))
                }
            }
            
            for _ in 0..<min(maxConcurrent, freshSnapshot.count) {
                if let device = iterator.next() {
                    enqueue(device, index: freshSnapshot.firstIndex(where: { $0.id == device.id }) ?? 0)
                }
            }
            
            var completedCount = 0
            for await (deviceId, _, resolution) in group {
                guard !Task.isCancelled else { break }
                
                resolutions.set(resolution, for: deviceId)
                completedCount += 1
                
                let deviceIP = await MainActor.run {
                    self.devices.first(where: { $0.id == deviceId })?.ipAddress ?? ""
                }
                
                if let next = iterator.next() {
                    await MainActor.run { self.currentScanIP = next.ipAddress }
                    enqueue(next, index: freshSnapshot.firstIndex(where: { $0.id == next.id }) ?? 0)
                    await updateScanState(
                        progress: "Ports: \(next.ipAddress) (\(completedCount)/\(totalDevices))",
                        percentage: 70 + (Double(completedCount) / Double(totalDevices)) * 30,
                        currentIP: next.ipAddress
                    )
                } else {
                    await updateScanState(
                        progress: "Ports: \(deviceIP) (\(completedCount)/\(totalDevices))",
                        percentage: 70 + (Double(completedCount) / Double(totalDevices)) * 30,
                        currentIP: deviceIP
                    )
                }
            }
        }
        
        guard !Task.isCancelled else { return }
        
        let resolved = resolutions.snapshot()
        let previousDevices = await MainActor.run { self.previousDevices }
        let subnet = await MainActor.run {
            self.currentSubnet
        }
        
        var updatedDevices = await MainActor.run {
            self.devices
                .filter { subnet?.contains($0.ipAddress) ?? true }
                .map { device -> DeviceInfo in
                guard let resolution = resolved[device.id] else { return device }
                var copy = device
                copy.hostName = resolution.hostName
                copy.macAddress = resolution.macAddress.isEmpty ? device.macAddress : resolution.macAddress
                copy.manufacturer = resolution.manufacturer
                copy.openPorts = resolution.openPorts.isEmpty ? device.openPorts : resolution.openPorts
                copy.bonjourName = resolution.bonjourName
                copy.netbiosName = resolution.netbiosName
                copy.dnsName = resolution.dnsName.isEmpty ? device.dnsName : resolution.dnsName
                copy.mdnsName = resolution.mdnsName.isEmpty ? device.mdnsName : resolution.mdnsName
                copy.detailHint = resolution.detailHint
                copy.osHint = resolution.osHint
                copy.advertisedServices = resolution.advertisedServices
                copy.category = resolution.category
                copy.lastSeen = Date()
                if copy.firstSeen == nil { copy.firstSeen = copy.lastSeen }
                return copy
            }
        }
        
        let foundIPs = Set(updatedDevices.map(\.ipAddress))
        let missingIPs = DeviceStatusResolver.missingIPs(
            previousIPs: previousDevices,
            foundIPs: foundIPs
        ).filter { subnet?.contains($0) ?? true }
        for ip in missingIPs {
            let cached = cachedDetails[ip]
            updatedDevices.append(DeviceInfo(
                id: cached?.id ?? UUID(),
                ipAddress: ip,
                hostName: "Nicht mehr verfügbar",
                macAddress: cached?.macAddress ?? "",
                manufacturer: cached?.manufacturer ?? "",
                openPorts: [],
                status: .missing,
                isExpanded: false,
                bonjourName: cached?.bonjourName ?? "",
                netbiosName: cached?.netbiosName ?? "",
                dnsName: cached?.dnsName ?? "",
                mdnsName: cached?.mdnsName ?? "",
                detailHint: cached?.detailHint ?? "",
                osHint: cached?.osHint ?? "",
                advertisedServices: cached?.advertisedServices ?? [],
                firstSeen: cached?.firstSeen,
                lastSeen: cached?.lastSeen,
                category: cached?.category ?? .unknown
            ))
        }
        
        await finishScan(devices: updatedDevices)
    }
    
    private struct NameResolution {
        var hostName: String
        var dnsName: String
        var mdnsName: String
        var netbios: String
        var macAddress: String = ""
    }
    
    /// Resolve DNS + mDNS separately. Skips network / broadcast addresses.
    private func resolveHostNamesFast(
        device: DeviceInfo,
        cached: CachedDeviceSnapshot?
    ) async -> NameResolution {
        let ip = device.ipAddress
        if Self.isBroadcastOrNetworkAddress(ip) {
            return NameResolution(
                hostName: device.hostName,
                dnsName: "",
                mdnsName: "",
                netbios: "",
                macAddress: device.macAddress
            )
        }
        
        let started = Date()
        await MainActor.run {
            self.currentScanIP = ip
            self.scanDebugDetail = "name start \(ip)"
        }
        
        let alias = rememberedHostName(ip: ip, mac: device.macAddress)
        let existingDNS = usefulHostName(device.dnsName) ?? usefulHostName(cached?.dnsName) ?? ""
        let existingMDNS = usefulHostName(device.mdnsName)
            ?? usefulHostName(device.bonjourName)
            ?? usefulHostName(cached?.mdnsName)
            ?? ""
        let existingNB = usefulHostName(device.netbiosName) ?? ""
        
        let hasDisplayName = isWellIdentified(device) || isWellIdentified(
            hostName: cached?.hostName ?? device.hostName,
            bonjour: cached?.bonjourName ?? device.bonjourName,
            mdns: cached?.mdnsName ?? device.mdnsName,
            netbios: cached?.netbiosName ?? device.netbiosName,
            dns: cached?.dnsName ?? device.dnsName
        )
        
        let needsDNS = existingDNS.isEmpty
        let needsMDNS = existingMDNS.isEmpty && !hasDisplayName
        let needsMAC = device.macAddress.isEmpty
        // NetBIOS also carries the Unit ID (MAC), so ask even when the name is already known.
        let needsNetBIOS = needsMAC
            || (existingNB.isEmpty && !hasDisplayName && usefulHostName(alias) == nil)
        
        if hasDisplayName && !needsDNS && !needsMAC {
            let hostName = bestHostName(
                ip: ip,
                alias: alias,
                bonjour: device.bonjourName,
                netbios: device.netbiosName,
                mdns: device.mdnsName,
                dns: device.dnsName,
                cached: cached?.hostName,
                current: device.hostName
            )
            return NameResolution(
                hostName: hostName,
                dnsName: device.dnsName,
                mdnsName: device.mdnsName,
                netbios: device.netbiosName,
                macAddress: device.macAddress
            )
        }
        
        await MainActor.run {
            self.scanDebugDetail = "name… \(ip) dns=\(needsDNS) mdns=\(needsMDNS) nb=\(needsNetBIOS)"
        }
        
        async let dnsLookup: String? = needsDNS
            ? getHostName(for: ip, timeout: NetworkConstants.dnsLookupTimeout)
            : nil
        async let mdnsLookup: String? = needsMDNS
            ? MDNSReverseLookup.lookup(ip: ip, timeout: NetworkConstants.mdnsLookupTimeout)
            : nil
        async let netbiosLookup: NetBIOSNodeStatus = needsNetBIOS
            ? NetBIOSQuery.lookup(for: ip, timeout: NetworkConstants.netbiosLookupTimeout)
            : NetBIOSNodeStatus()
        let euiHost = usefulHostName(device.mdnsName) ?? usefulHostName(device.bonjourName)
        let queryEUI = needsMAC && euiHost != nil && shouldQueryEUI64(device, host: euiHost ?? "")
        async let euiLookup: String? = queryEUI
            ? MDNSAddressMAC.eui64MAC(forHost: euiHost ?? "", timeout: 0.6)
            : nil
        
        var dns = existingDNS
        var mdns = existingMDNS
        var netbios = existingNB
        
        let dnsRaw = await dnsLookup
        let mdnsRaw = await mdnsLookup
        let nbStatus = await netbiosLookup
        let euiMAC = await euiLookup
        
        if needsDNS, let raw = dnsRaw {
            let classified = Self.classifyResolvedName(raw)
            if dns.isEmpty, let d = classified.dns { dns = d }
            if mdns.isEmpty, let m = classified.mdns { mdns = m }
        }
        if needsMDNS, let raw = mdnsRaw {
            let classified = Self.classifyResolvedName(raw)
            if mdns.isEmpty, let m = classified.mdns ?? classified.dns { mdns = m }
            if dns.isEmpty, let d = classified.dns { dns = d }
        }
        if needsNetBIOS, existingNB.isEmpty, let nb = usefulHostName(nbStatus.name) {
            netbios = nb
        }
        var learnedMAC = device.macAddress
        if learnedMAC.isEmpty, let mac = nbStatus.macAddress {
            learnedMAC = mac
        }
        if learnedMAC.isEmpty, let mac = euiMAC {
            learnedMAC = mac
        }
        
        if mdns.isEmpty, let bj = usefulHostName(device.bonjourName) {
            mdns = bj
        }
        
        dns = usefulHostName(dns) ?? ""
        mdns = usefulHostName(mdns) ?? ""
        
        let hostName: String
        if hasDisplayName {
            hostName = bestHostName(
                ip: ip,
                alias: alias,
                bonjour: device.bonjourName,
                netbios: netbios.isEmpty ? device.netbiosName : netbios,
                mdns: mdns.isEmpty ? device.mdnsName : mdns,
                dns: dns,
                cached: cached?.hostName,
                current: device.hostName
            )
        } else {
            hostName = bestHostName(
                ip: ip,
                alias: alias,
                bonjour: device.bonjourName,
                netbios: netbios,
                mdns: mdns,
                dns: dns,
                cached: cached?.hostName,
                current: device.hostName
            )
        }
        
        let dnsMs = Int(Date().timeIntervalSince(started) * 1000)
        await MainActor.run {
            self.scanDebugDetail = "name fertig \(ip) · \(dnsMs)ms · dns=\(dns.isEmpty ? "—" : dns) mdns=\(mdns.isEmpty ? "—" : mdns) nb=\(netbios.isEmpty ? "—" : netbios)"
        }
        
        let totalMs = Int(Date().timeIntervalSince(started) * 1000)
        await MainActor.run {
            self.scanDebugDetail = "name done \(ip) · \(totalMs)ms → \(hostName)"
            self.debugMessage = self.scanDebugDetail
        }
        
        return NameResolution(
            hostName: hostName,
            dnsName: dns,
            mdnsName: mdns.isEmpty ? device.mdnsName : mdns,
            netbios: netbios.isEmpty ? device.netbiosName : netbios,
            macAddress: learnedMAC
        )
    }
    
    /// Privacy addresses on phones are not EUI-64. Skip the extra AAAA query for those names.
    private func shouldQueryEUI64(_ device: DeviceInfo, host: String) -> Bool {
        let services = device.advertisedServices.joined(separator: " ").lowercased()
        if services.contains("_apple-mobdev") { return false }
        let lower = host.lowercased()
        if lower.contains("iphone") || lower.contains("ipad") || lower.contains("android") {
            return false
        }
        return true
    }
    
    private func needsDNSResolution(device: DeviceInfo, cached: CachedDeviceSnapshot?) -> Bool {
        usefulHostName(device.dnsName) == nil && usefulHostName(cached?.dnsName) == nil
    }
    
    nonisolated private static func isBroadcastOrNetworkAddress(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4, let last = Int(parts[3]) else { return false }
        return last == 0 || last == 255
    }
    
    /// Split a raw reverse-lookup string into DNS vs mDNS buckets.
    nonisolated private static func classifyResolvedName(_ raw: String) -> (dns: String?, mdns: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }
        let lower = trimmed.lowercased()
        if lower.hasSuffix(".local") {
            let short = String(trimmed.dropLast(6))
            return (nil, short.isEmpty ? nil : short)
        }
        // Single label without dots → treat as local/mDNS-style.
        if !trimmed.contains(".") {
            return (nil, trimmed)
        }
        return (trimmed, nil)
    }
    
    private func finishScan(devices updatedDevices: [DeviceInfo]) async {
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            let subnet = self.currentSubnet
            // Never keep hosts from other subnets in the result list.
            self.devices = updatedDevices.filter { device in
                subnet?.contains(device.ipAddress) ?? true
            }
            self.sortDevices()
            self.scanProgress = "Scan abgeschlossen"
            self.progressPercentage = 100
            self.scanPhase = .finished
            self.isScanning = false
            self.saveSettings()
            self.publishMACsToiCloud(prefix: subnet?.prefix ?? "")
        }
    }
    
    private func updateDevice(id: UUID, mutate: (inout DeviceInfo) -> Void) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        var copy = devices
        mutate(&copy[index])
        devices = copy
    }
    
    /// Probe open ports on already-listed hosts and update the UI immediately.
    private func fillDiscoveredHostPorts(
        ips: [String],
        ports: [Int],
        hits: ResolutionStore<String, [Int]>
    ) async {
        guard !ips.isEmpty, !ports.isEmpty else { return }
        
        await withTaskGroup(of: (String, [Int]).self) { group in
            var next = ips.makeIterator()
            #if os(iOS) || os(visionOS)
            let hostCap = 10
            #else
            let hostCap = 6
            #endif
            
            func enqueue(_ ip: String) {
                group.addTask {
                    let timeout = NetworkConstants.fillPortsTimeout
                    let found = await Task.detached(priority: .userInitiated) {
                        self.probeOpenPorts(ip, ports: ports, timeout: timeout)
                    }.value
                    return (ip, found)
                }
            }
            
            for _ in 0..<hostCap {
                if let ip = next.next() { enqueue(ip) }
            }
            
            for await (ip, found) in group {
                guard !Task.isCancelled else { break }
                hits.set(found, for: ip)
                if let index = devices.firstIndex(where: { $0.ipAddress == ip }) {
                    devices[index].openPorts = found
                }
                if let ip = next.next() {
                    enqueue(ip)
                }
            }
        }
    }
    
    /// Ports for phase-2 custom/full scan on discovered hosts.
    func portsForScan(_ mode: ScanMode) -> [Int] {
        let customPorts = self.customPorts
        switch mode {
        case .quickScan:
            let ports = customPorts.isEmpty ? NetworkConstants.defaultPorts : customPorts
            return Array(ports).sorted()
        case .fullScan:
            let ports = customPorts.isEmpty
                ? Set(NetworkConstants.fullScanPorts)
                : customPorts.union(Set(NetworkConstants.fullScanPorts))
            return Array(ports).sorted()
        }
    }
    
    /// Port-scan a single known device using the same port list as a network scan.
    func startDevicePortScan(for device: DeviceInfo, mode: ScanMode? = nil) {
        let ip = device.ipAddress
        guard IPAddressValidator.isValidIPv4(ip) else {
            scanError = .invalidIPAddress(ip)
            return
        }
        guard !isScanning else {
            scanError = .scanAlreadyRunning
            return
        }
        guard devicePortScanIP == nil else { return }
        
        let scanMode = mode ?? preferredScanMode
        let ports = portsForScan(scanMode)
        guard !ports.isEmpty else {
            scanError = .noPortsSpecified
            return
        }
        
        cancelBackgroundPrefetch()
        devicePortScanTask?.cancel()
        devicePortScanIP = ip
        scanProgress = "Port-Scan \(ip)…"
        scanDebugDetail = "ports… \(ip) · \(ports.count) Ports"
        currentScanIP = ip
        
        devicePortScanTask = Task { [weak self] in
            guard let self else { return }
            #if os(iOS) || os(visionOS)
            LocalNetworkAccess.requestIfNeeded()
            #endif
            
            let timeout = NetworkConstants.phase2PortTimeout
            let openPorts = await Task.detached(priority: .userInitiated) {
                self.probeOpenPorts(ip, ports: ports, timeout: timeout)
            }.value
            
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.finishDevicePortScan(cancelled: true)
                }
                return
            }
            
            await MainActor.run {
                if let index = self.devices.firstIndex(where: { $0.ipAddress == ip }) {
                    var copy = self.devices
                    copy[index].openPorts = openPorts
                    copy[index].lastSeen = Date()
                    if copy[index].status == .missing {
                        copy[index].status = .current
                    }
                    self.devices = copy
                }
                self.scanDebugDetail = "ports done \(ip) · open=\(openPorts)"
                self.finishDevicePortScan(cancelled: false)
                self.saveSettings()
            }
        }
    }
    
    func stopDevicePortScan() {
        devicePortScanTask?.cancel()
        devicePortScanTask = nil
        finishDevicePortScan(cancelled: true)
    }
    
    func isPortScanning(ip: String) -> Bool {
        devicePortScanIP == ip
    }
    
    private func finishDevicePortScan(cancelled: Bool) {
        devicePortScanIP = nil
        devicePortScanTask = nil
        currentScanIP = ""
        scanProgress = cancelled ? "Port-Scan abgebrochen" : "Port-Scan abgeschlossen"
        scanDebugDetail = cancelled ? "" : scanDebugDetail
    }
    
    func stopScan() {
        currentScanTask?.cancel()
        currentScanTask = nil
        stopDevicePortScan()
        isScanning = false
        scanPhase = .idle
        progressPercentage = 0
        scanProgress = "Scan abgebrochen"
        currentScanIP = ""
        saveSettings()
    }
    
    private func upsertDevice(_ device: DeviceInfo) {
        if let index = devices.firstIndex(where: { $0.ipAddress == device.ipAddress }) {
            let existing = devices[index]
            let merged = DeviceInfo(
                id: existing.id,
                ipAddress: device.ipAddress,
                hostName: device.hostName,
                macAddress: device.macAddress,
                manufacturer: device.manufacturer,
                openPorts: device.openPorts,
                status: device.status,
                isExpanded: existing.isExpanded,
                bonjourName: device.bonjourName.isEmpty ? existing.bonjourName : device.bonjourName,
                netbiosName: device.netbiosName.isEmpty ? existing.netbiosName : device.netbiosName,
                dnsName: device.dnsName.isEmpty ? existing.dnsName : device.dnsName,
                mdnsName: device.mdnsName.isEmpty ? existing.mdnsName : device.mdnsName,
                detailHint: device.detailHint,
                osHint: device.osHint,
                advertisedServices: device.advertisedServices,
                firstSeen: existing.firstSeen ?? device.firstSeen,
                lastSeen: device.lastSeen,
                category: device.category != .unknown ? device.category : existing.category
            )
            devices[index] = merged
        } else {
            devices.append(device)
        }
    }
    
    private func supplementDiscovery(
        subnet: SubnetConfig,
        basePrefix: String,
        alreadyListed: inout Set<String>,
        cachedDetails: [String: CachedDeviceSnapshot],
        previousDevices: Set<String>,
        bonjourByIP: [String: BonjourHostInfo],
        ttlByIP: inout [String: UInt8],
        ouiDB: [String: String],
        arpMap: inout [String: String],
        depth: DiscoveryDepth
    ) async {
        guard depth != .fast else { return }
        
        arpMap = mergedMACMap(prefix: basePrefix)
        for ip in arpMap.keys.sorted(by: Self.ipSort) where subnet.allIPs.contains(ip) {
            guard !alreadyListed.contains(ip) else { continue }
            guard !Self.isBroadcastOrNetworkAddress(ip) else { continue }
            alreadyListed.insert(ip)
            let device = makeDiscoveredDevice(
                ip: ip,
                openPorts: [],
                previousDevices: previousDevices,
                cachedDetails: cachedDetails,
                bonjour: bonjourByIP[ip],
                osHint: ttlByIP[ip].map { ICMPPinger.osHintFromTTL($0) } ?? "",
                ouiDB: ouiDB,
                arpMap: arpMap
            )
            upsertDevice(device)
        }
        
        let foundIPs = await MainActor.run { Set(self.devices.map(\.ipAddress)) }
        let missing = Set(subnet.allIPs).subtracting(foundIPs)
        guard !missing.isEmpty else { return }
        
        let hostNumbers = Set(missing.compactMap { ip -> Int? in
            guard ip.hasPrefix(basePrefix + "."),
                  let last = ip.split(separator: ".").last,
                  let n = Int(last) else { return nil }
            return n
        })
        guard !hostNumbers.isEmpty else { return }
        
        let latePing = await ICMPPinger.sweep(
            prefix: basePrefix,
            hostNumbers: hostNumbers,
            timeout: NetworkConstants.icmpRetryTimeout
        )
        for ip in latePing.alive.sorted(by: Self.ipSort) {
            guard !Self.isBroadcastOrNetworkAddress(ip) else { continue }
            guard alreadyListed.insert(ip).inserted else { continue }
            if let ttl = latePing.ttlByIP[ip] { ttlByIP[ip] = ttl }
            let device = makeDiscoveredDevice(
                ip: ip,
                openPorts: [],
                previousDevices: previousDevices,
                cachedDetails: cachedDetails,
                bonjour: bonjourByIP[ip],
                osHint: ttlByIP[ip].map { ICMPPinger.osHintFromTTL($0) } ?? "",
                ouiDB: ouiDB,
                arpMap: arpMap
            )
            upsertDevice(device)
        }
    }
    
    func makeDiscoveredDevice(
        ip: String,
        openPorts: [Int],
        previousDevices: Set<String>,
        cachedDetails: [String: CachedDeviceSnapshot],
        bonjour: BonjourHostInfo? = nil,
        osHint: String = "",
        ouiDB: [String: String] = [:],
        arpMap: [String: String] = [:]
    ) -> DeviceInfo {
        let cached = cachedDetails[ip]
        let remembered = rememberedHostName(ip: ip, mac: cached?.macAddress ?? "")
        let now = Date()
        let bonjourName = bonjour?.bestName ?? cached?.bonjourName ?? ""
        let seededMac = [cached?.macAddress, bonjour?.macAddress].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        let (macAddress, _, portOsHint) = getMacAddress(
            for: ip,
            openPorts: openPorts,
            knownHostName: bonjourName.isEmpty ? cached?.hostName : bonjourName,
            knownMac: seededMac,
            arpMap: arpMap,
            ouiDB: ouiDB
        )
        let resolvedMac = macAddress.isEmpty ? (cached?.macAddress ?? "") : macAddress
        var resolvedManufacturer = resolveManufacturer(
            mac: resolvedMac,
            names: [bonjourName, bonjour?.modelLabel, cached?.hostName, remembered],
            bonjour: bonjour,
            ouiDB: ouiDB
        )
        if let cachedManufacturer = cached?.manufacturer,
           shouldUpgradeManufacturer(current: resolvedManufacturer, proposed: cachedManufacturer) {
            resolvedManufacturer = cachedManufacturer
        }
        let resolvedOsHint: String = {
            if !osHint.isEmpty { return osHint }
            if let cachedOs = cached?.osHint, !cachedOs.isEmpty { return cachedOs }
            return portOsHint ?? ""
        }()
        var hostName = bestHostName(
            ip: ip,
            alias: remembered,
            bonjour: bonjourName,
            netbios: cached?.netbiosName,
            mdns: cached?.mdnsName ?? bonjourName,
            dns: cached?.dnsName,
            cached: cached?.hostName,
            current: bonjour?.modelLabel
        )
        if usefulHostName(hostName) == nil, let routerName = routerNameOverlay[ip] {
            hostName = routerName
        }
        var device = DeviceInfo(
            id: cached?.id ?? UUID(),
            ipAddress: ip,
            hostName: hostName,
            macAddress: resolvedMac,
            manufacturer: resolvedManufacturer,
            openPorts: openPorts.isEmpty ? (cached?.openPorts ?? []) : openPorts,
            status: DeviceStatusResolver.status(for: ip, previousIPs: previousDevices),
            isExpanded: false,
            bonjourName: bonjourName,
            netbiosName: cached?.netbiosName ?? "",
            dnsName: cached?.dnsName ?? "",
            mdnsName: cached?.mdnsName ?? (bonjourName.isEmpty ? "" : bonjourName),
            detailHint: cached?.detailHint ?? "",
            osHint: resolvedOsHint,
            advertisedServices: bonjour?.serviceTypes ?? cached?.advertisedServices ?? [],
            firstSeen: cached?.firstSeen ?? now,
            lastSeen: now,
            category: cached?.category ?? .unknown
        )
        if let bonjour {
            mergeBonjour(bonjour, into: &device)
        }
        return device
    }

    nonisolated static func enriched(
        _ device: DeviceInfo,
        with upnp: UPnPDeviceInfo,
        ouiDB: [String: String]
    ) -> DeviceInfo {
        var d = device
        if let name = upnp.bestName, !name.isEmpty {
            if d.hostName.hasPrefix("Gerät .") || d.hostName.isEmpty {
                d.hostName = name
            }
            if d.mdnsName.isEmpty { d.mdnsName = name }
        }
        if !d.macAddress.isEmpty || !upnp.macAddress.isEmpty {
            if d.macAddress.isEmpty { d.macAddress = upnp.macAddress }
            let vendor = OUIParser.lookup(mac: d.macAddress, database: ouiDB)
            if vendor != OUIParser.unknownManufacturer && vendor != OUIParser.privateMACLabel {
                d.manufacturer = vendor
            } else if OUIParser.shouldUpgradeManufacturer(current: d.manufacturer, proposed: vendor) {
                d.manufacturer = vendor
            }
        }
        if OUIParser.shouldUpgradeManufacturer(current: d.manufacturer, proposed: upnp.manufacturer) {
            d.manufacturer = upnp.manufacturer
        }
        if d.detailHint.isEmpty {
            let hint = [upnp.modelName, upnp.modelDescription]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            d.detailHint = hint
        }
        if upnp.isGatewayDevice { d.category = .router }
        if !d.advertisedServices.contains("upnp") {
            d.advertisedServices.append("upnp")
        }
        return d
    }
    
    nonisolated static func enriched(
        _ device: DeviceInfo,
        with gateway: GatewayEnrichment,
        ouiDB: [String: String]
    ) -> DeviceInfo {
        var d = device
        if !gateway.name.isEmpty,
           d.hostName.isEmpty || d.hostName.hasPrefix("Gerät .") || d.hostName == "Router" {
            d.hostName = gateway.name
        }
        if d.mdnsName.isEmpty, !gateway.name.isEmpty { d.mdnsName = gateway.name }
        if !d.macAddress.isEmpty || !gateway.macAddress.isEmpty {
            if d.macAddress.isEmpty { d.macAddress = gateway.macAddress }
            let vendor = OUIParser.lookup(mac: d.macAddress, database: ouiDB)
            if vendor != OUIParser.unknownManufacturer && vendor != OUIParser.privateMACLabel {
                d.manufacturer = vendor
            } else if OUIParser.shouldUpgradeManufacturer(current: d.manufacturer, proposed: vendor) {
                d.manufacturer = vendor
            }
        }
        if OUIParser.shouldUpgradeManufacturer(current: d.manufacturer, proposed: gateway.manufacturer) {
            d.manufacturer = gateway.manufacturer
        }
        if d.detailHint.isEmpty, !gateway.detailHint.isEmpty {
            d.detailHint = gateway.detailHint
        } else if d.detailHint.isEmpty, !gateway.model.isEmpty {
            d.detailHint = gateway.model
        }
        if d.osHint.isEmpty, !gateway.osHint.isEmpty {
            d.osHint = gateway.osHint
        }
        d.category = .router
        return d
    }

    // MARK: - Background prefetch
    
    func startBackgroundPrefetchIfNeeded() {
        guard !isScanning else { return }
        
        let prefix = currentSubnet?.prefix
            ?? currentNetwork.split(separator: ".").dropLast().joined(separator: ".")
        guard !prefix.isEmpty else { return }
        
        if let cache = prefetchCache, cache.networkPrefix == prefix, cache.isFresh {
            return
        }
        
        prefetchTask?.cancel()
        prefetchTask = Task { [weak self] in
            guard let self else { return }
            await self.runBackgroundPrefetch(prefix: prefix)
        }
    }
    
    func prefetchSnapshot(for prefix: String) -> LANPrefetchCache? {
        guard let cache = prefetchCache,
              cache.networkPrefix == prefix,
              cache.isFresh else { return nil }
        return cache
    }
    
    func cancelBackgroundPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }
    
    func cachedSnapshot(from device: DeviceInfo) -> CachedDeviceSnapshot {
        CachedDeviceSnapshot(
            id: device.id,
            hostName: usefulHostName(device.hostName) ?? "",
            macAddress: device.macAddress,
            manufacturer: device.manufacturer,
            openPorts: device.openPorts,
            bonjourName: device.bonjourName,
            netbiosName: device.netbiosName,
            dnsName: device.dnsName,
            mdnsName: device.mdnsName,
            detailHint: device.detailHint,
            osHint: device.osHint,
            advertisedServices: device.advertisedServices,
            firstSeen: device.firstSeen,
            lastSeen: device.lastSeen,
            category: device.category
        )
    }
    
    private func runBackgroundPrefetch(prefix: String) async {
        LocalNetworkAccess.requestIfNeeded()
        let routerTask = Task { await self.fetchRouterMACOverlay(prefix: prefix) }
        
        let subnet = SubnetConfig.from(
            localIP: await MainActor.run { self.currentNetwork },
            netmask: getInterfaceAddress()?.netmask
        )
        guard subnet.prefix == prefix else { return }
        
        let ouiDB = await MainActor.run { self.ouiDatabase }
        let gatewayIP = GatewayProbe.defaultGatewayIP()
            ?? (subnet.hostNumbers.contains(1) ? "\(prefix).1" : nil)
        
        async let pingTask = ICMPPinger.sweep(
            prefix: prefix,
            hostNumbers: subnet.hostNumberSet,
            timeout: NetworkConstants.prefetchPingTimeout
        )
        async let bonjourTask = BonjourScanner().scanNetwork(
            prefix: prefix,
            timeout: NetworkConstants.prefetchBonjourTimeout
        )
        async let ssdpTask = SSDPDiscovery.scan(
            prefix: prefix,
            timeout: NetworkConstants.prefetchSSDTimeout
        )
        async let gatewayTask: GatewayEnrichment? = {
            guard let gatewayIP else { return nil }
            return await GatewayProbe.enrich(
                gatewayIP: gatewayIP,
                timeout: NetworkConstants.prefetchGatewayTimeout
            )
        }()
        
        let pingResult = await pingTask
        let bonjourByIP = await bonjourTask
        let upnpByIP = await ssdpTask
        let gatewayInfo = await gatewayTask
        
        guard !Task.isCancelled else { return }
        
        var alive = pingResult.alive
        alive.formUnion(bonjourByIP.keys)
        alive.formUnion(upnpByIP.keys)
        if let gatewayIP { alive.insert(gatewayIP) }
        
        await routerTask.value
        let arpMap = self.mergedMACMap(prefix: prefix)
        alive.formUnion(arpMap.keys)
        
        let sortedAlive = alive.sorted { a, b in
            let octet: (String) -> Int = { Int($0.split(separator: ".").last ?? "0") ?? 0 }
            return octet(a) < octet(b)
        }
        
        var discoveryPortsByIP: [String: [Int]] = [:]
        
        await withTaskGroup(of: (String, [Int]).self) { group in
            var iterator = sortedAlive.makeIterator()
            let cap = NetworkConstants.prefetchHostConcurrency
            
            func enqueue(_ ip: String) {
                group.addTask {
                    let ports = await Task.detached(priority: .utility) {
                        self.probeOpenPorts(
                            ip,
                            ports: Array(NetworkConstants.defaultPorts),
                            timeout: NetworkConstants.prefetchPortTimeout
                        )
                    }.value
                    return (ip, ports)
                }
            }
            
            for _ in 0..<min(cap, sortedAlive.count) {
                if let ip = iterator.next() { enqueue(ip) }
            }
            
            for await (ip, ports) in group {
                guard !Task.isCancelled else { break }
                discoveryPortsByIP[ip] = ports
                if let ip = iterator.next() { enqueue(ip) }
            }
        }
        
        guard !Task.isCancelled else { return }
        
        var prefetchedDevices: [DeviceInfo] = []
        prefetchedDevices.reserveCapacity(sortedAlive.count)
        
        for ip in sortedAlive {
            guard !Task.isCancelled else { return }
            let ports = discoveryPortsByIP[ip] ?? []
            let bj = bonjourByIP[ip]
            var device = await MainActor.run {
                self.makeDiscoveredDevice(
                    ip: ip,
                    openPorts: ports,
                    previousDevices: [],
                    cachedDetails: [:],
                    bonjour: bj,
                    osHint: pingResult.ttlByIP[ip].map { ICMPPinger.osHintFromTTL($0) } ?? "",
                    ouiDB: ouiDB,
                    arpMap: arpMap
                )
            }
            if let upnp = upnpByIP[ip] {
                device = Self.enriched(device, with: upnp, ouiDB: ouiDB)
            }
            if let gatewayInfo, gatewayInfo.ip == ip {
                device = Self.enriched(device, with: gatewayInfo, ouiDB: ouiDB)
            }
            if device.macAddress.isEmpty || !isWellIdentified(device) {
                let status = await NetBIOSQuery.lookup(
                    for: ip,
                    timeout: NetworkConstants.prefetchNetbiosTimeout
                )
                if !isWellIdentified(device), let nb = usefulHostName(status.name) {
                    device.netbiosName = nb
                    device.hostName = bestHostName(
                        ip: ip,
                        alias: nil,
                        bonjour: device.bonjourName,
                        netbios: nb,
                        mdns: device.mdnsName,
                        dns: device.dnsName,
                        cached: nil,
                        current: device.hostName
                    )
                }
                applyLearnedMAC(status.macAddress, to: &device)
            }
            if device.macAddress.isEmpty,
               let host = usefulHostName(device.bonjourName) ?? usefulHostName(device.mdnsName),
               shouldQueryEUI64(device, host: host),
               let mac = await MDNSAddressMAC.eui64MAC(forHost: host, timeout: 0.5) {
                applyLearnedMAC(mac, to: &device)
            }
            prefetchedDevices.append(device)
        }
        
        await MainActor.run {
            self.prefetchCache = LANPrefetchCache(
                networkPrefix: prefix,
                completedAt: Date(),
                devices: prefetchedDevices,
                bonjourByIP: bonjourByIP,
                discoveryPortsByIP: discoveryPortsByIP
            )
            self.prefetchTask = nil
        }
    }

    nonisolated private static func ipSort(_ a: String, _ b: String) -> Bool {
        let octet: (String) -> Int = { Int($0.split(separator: ".").last ?? "0") ?? 0 }
        return octet(a) < octet(b)
    }
}

/// Thread-safe dictionary for storing intermediate scan results
private final class ResolutionStore<Key: Hashable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Key: Value] = [:]
    
    func set(_ value: Value, for key: Key) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }
    
    func snapshot() -> [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

// MARK: - UPnP / Gateway discovery

struct GatewayEnrichment: Sendable {
    var ip: String
    var name: String = ""
    var manufacturer: String = ""
    var model: String = ""
    var macAddress: String = ""
    var detailHint: String = ""
    var osHint: String = ""
}

struct UPnPDeviceInfo: Sendable {
    var friendlyName: String = ""
    var manufacturer: String = ""
    var modelName: String = ""
    var modelDescription: String = ""
    var serialNumber: String = ""
    var macAddress: String = ""
    var deviceType: String = ""
    var locationURL: String = ""
    
    var bestName: String? {
        let candidates = [friendlyName, modelName, modelDescription]
        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
    
    var isGatewayDevice: Bool {
        let t = deviceType.lowercased()
        return t.contains("internetgatewaydevice")
            || t.contains("wanconnectiondevice")
            || t.contains("landevice")
            || modelName.lowercased().contains("router")
            || friendlyName.lowercased().contains("router")
            || friendlyName.lowercased().contains("gateway")
    }
}

enum GatewayProbe {
    static func defaultGatewayIP() -> String? {
        #if os(macOS)
        guard let store = SCDynamicStoreCreate(nil, "TToolsIPScanner" as CFString, nil, nil) else {
            return nil
        }
        guard let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let router = value["Router"] as? String,
              IPAddressValidator.isValidIPv4(router) else {
            return nil
        }
        return router
        #else
        return nil
        #endif
    }
    
    static func enrich(gatewayIP: String, timeout: TimeInterval = 2.0) async -> GatewayEnrichment {
        var result = GatewayEnrichment(ip: gatewayIP)
        
        async let upnpTask = SSDPDiscovery.probeHost(gatewayIP, timeout: min(timeout, 1.4))
        async let httpTask = fetchHTTPIdentity(ip: gatewayIP, timeout: min(timeout, 1.2))
        async let snmpName = SNMPProbe.sysName(ip: gatewayIP, timeout: min(timeout, 0.8))
        async let snmpDescr = SNMPProbe.sysDescr(ip: gatewayIP, timeout: min(timeout, 0.8))
        
        let upnp = await upnpTask
        let http = await httpTask
        let nameSNMP = await snmpName
        let descrSNMP = await snmpDescr
        
        if let upnp {
            result.name = upnp.bestName ?? ""
            result.manufacturer = upnp.manufacturer
            result.model = upnp.modelName
            result.macAddress = upnp.macAddress
            if !upnp.modelDescription.isEmpty {
                result.detailHint = upnp.modelDescription
            }
        }
        
        if result.name.isEmpty, let title = http.title, !title.isEmpty {
            result.name = cleanRouterTitle(title)
        }
        if result.detailHint.isEmpty, let server = http.server, !server.isEmpty {
            result.detailHint = server
            if result.manufacturer.isEmpty {
                result.manufacturer = manufacturerFromServer(server)
            }
        }
        
        if result.name.isEmpty, let nameSNMP, !nameSNMP.isEmpty {
            result.name = nameSNMP
        }
        if let descrSNMP, !descrSNMP.isEmpty {
            if result.detailHint.isEmpty { result.detailHint = descrSNMP }
            if result.osHint.isEmpty { result.osHint = String(descrSNMP.prefix(80)) }
            if result.manufacturer.isEmpty {
                result.manufacturer = manufacturerFromServer(descrSNMP)
            }
        }
        
        if result.name.isEmpty {
            result.name = "Router"
        }
        
        return result
    }
    
    private struct HTTPIdentity: Sendable {
        var title: String?
        var server: String?
    }
    
    private static func fetchHTTPIdentity(ip: String, timeout: TimeInterval) async -> HTTPIdentity {
        guard let url = URL(string: "http://\(ip)/") else { return HTTPIdentity() }
        return await oneHTTPIdentity(url: url, timeout: timeout) ?? HTTPIdentity()
    }
    
    private static func oneHTTPIdentity(url: URL, timeout: TimeInterval) async -> HTTPIdentity? {
        let page = await Task.detached(priority: .utility) {
            LANHTTP.get(url: url, timeout: timeout)
        }.value
        guard let page else { return nil }
        let server = page.headers["server"]
        let html = String(data: page.body, encoding: .utf8)
            ?? String(data: page.body, encoding: .isoLatin1)
            ?? ""
        let title = htmlTitle(html)
        if (title == nil || title?.isEmpty == true), server == nil {
            return nil
        }
        return HTTPIdentity(title: title, server: server)
    }
    
    private static func htmlTitle(_ html: String) -> String? {
        guard let open = html.range(of: "<title", options: .caseInsensitive),
              let gt = html[open.upperBound...].firstIndex(of: ">"),
              let close = html.range(of: "</title>", options: .caseInsensitive, range: gt..<html.endIndex) else {
            return nil
        }
        let start = html.index(after: gt)
        let raw = String(html[start..<close.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }
    
    private static func cleanRouterTitle(_ title: String) -> String {
        var t = title
        for junk in ["Login", "login", "Web Management", "Authorization", "Sign in"] {
            if t.caseInsensitiveCompare(junk) == .orderedSame { return "Router" }
        }
        if t.count > 60 { t = String(t.prefix(60)) }
        return t
    }
    
    private static func manufacturerFromServer(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("fritz") || lower.contains("avm") { return "AVM GmbH" }
        if lower.contains("asus") { return "ASUSTek COMPUTER INC." }
        if lower.contains("tp-link") || lower.contains("tplink") { return "TP-LINK TECHNOLOGIES" }
        if lower.contains("netgear") { return "NETGEAR" }
        if lower.contains("ubiquiti") || lower.contains("unifi") { return "Ubiquiti Inc." }
        if lower.contains("mikrotik") { return "MikroTik" }
        if lower.contains("cisco") { return "Cisco Systems, Inc" }
        if lower.contains("zyxel") { return "ZyXEL Communications" }
        if lower.contains("huawei") { return "Huawei Technologies" }
        if lower.contains("technicolor") || lower.contains("arris") {
            return "ARRIS Group, Inc."
        }
        return ""
    }
}

enum SSDPDiscovery {
    private static let multicastIP = "239.255.255.250"
    private static let ssdpPort: UInt16 = 1900
    
    static func scan(prefix: String, timeout: TimeInterval = 3.0) async -> [String: UPnPDeviceInfo] {
        await Task.detached(priority: .userInitiated) {
            await scanBlocking(prefix: prefix, timeout: timeout)
        }.value
    }
    
    private static func scanBlocking(prefix: String, timeout: TimeInterval) async -> [String: UPnPDeviceInfo] {
        async let multicastLocations = discoverLocations(timeout: timeout)
        let gateway = GatewayProbe.defaultGatewayIP()
        async let unicastLocations: [String] = {
            guard let gateway, gateway.hasPrefix(prefix + ".") else { return [] }
            return await unicastSearch(to: gateway, timeout: min(timeout, 1.5))
        }()
        
        var locations = Set(await multicastLocations)
        locations.formUnion(await unicastLocations)
        
        var byIP: [String: UPnPDeviceInfo] = [:]
        
        await withTaskGroup(of: (String, UPnPDeviceInfo)?.self) { group in
            var seen = Set<String>()
            for location in locations {
                guard let host = hostOfURL(location),
                      host.hasPrefix(prefix + "."),
                      seen.insert(location).inserted else { continue }
                group.addTask {
                    guard let info = await fetchDescription(location: location) else { return nil }
                    return (host, info)
                }
            }
            for await item in group {
                guard let (ip, info) = item else { continue }
                byIP[ip] = merge(byIP[ip], info)
            }
        }
        return byIP
    }
    
    static func probeHost(_ ip: String, timeout: TimeInterval = 1.2) async -> UPnPDeviceInfo? {
        let candidates = [
            "http://\(ip)/rootDesc.xml",
            "http://\(ip)/description.xml",
            "http://\(ip)/DeviceDescription.xml",
            "http://\(ip)/upnp/IGD.xml",
            "http://\(ip)/igd.xml",
            "http://\(ip):1900/rootDesc.xml",
            "http://\(ip):5000/rootDesc.xml",
            "http://\(ip):49152/rootDesc.xml",
            "http://\(ip):49153/description.xml",
            "http://\(ip)/IGDdevicedesc.xml",
            "http://\(ip)/etc/linuxigd/gatedesc.xml",
            "http://\(ip)/Public_UPNP_C3"
        ]
        
        for url in candidates {
            if let info = await fetchDescription(location: url, timeout: min(timeout, 0.8)) {
                return info
            }
        }
        return nil
    }
    
    static func unicastSearch(to ip: String, timeout: TimeInterval = 1.5) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: unicastMSearch(to: ip, timeout: timeout))
            }
        }
    }
    
    private static func unicastMSearch(to ip: String, timeout: TimeInterval) -> [String] {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { Darwin.close(sock) }
        
        var tv = SocketTimeout.makeTimeval(from: min(timeout, 0.35))
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = ssdpPort.bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return [] }
        
        let search = "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: upnp:rootdevice\r\n\r\n"
        let data = Array(search.utf8)
        _ = data.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.sendto(sock, raw.baseAddress, data.count, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        
        var locations = Set<String>()
        let deadline = Date().addingTimeInterval(timeout)
        var buf = [UInt8](repeating: 0, count: 2048)
        while Date() < deadline {
            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &fromLen)
                }
            }
            guard n > 0 else { continue }
            let text = String(bytes: buf[0..<n], encoding: .utf8) ?? ""
            if let location = headerValue("LOCATION", in: text) ?? headerValue("Location", in: text) {
                locations.insert(location.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return Array(locations)
    }
    
    private static func discoverLocations(timeout: TimeInterval) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: msearchLocations(timeout: timeout))
            }
        }
    }
    
    private static func msearchLocations(timeout: TimeInterval) -> [String] {
        let sock = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { Darwin.close(sock) }
        
        var reuse: Int32 = 1
        _ = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        
        var tv = SocketTimeout.makeTimeval(from: min(timeout, 0.4))
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = ssdpPort.bigEndian
        _ = inet_pton(AF_INET, multicastIP, &addr.sin_addr)
        
        let searches = [
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: ssdp:all\r\n\r\n",
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: upnp:rootdevice\r\n\r\n",
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n"
        ]
        
        for search in searches {
            let data = Array(search.utf8)
            _ = data.withUnsafeBytes { raw in
                withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                        Darwin.sendto(sock, raw.baseAddress, data.count, 0, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }
        
        var locations = Set<String>()
        let deadline = Date().addingTimeInterval(timeout)
        var buf = [UInt8](repeating: 0, count: 2048)
        
        while Date() < deadline {
            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.recvfrom(sock, &buf, buf.count, 0, sockAddr, &fromLen)
                }
            }
            guard n > 0 else { continue }
            let text = String(bytes: buf[0..<n], encoding: .utf8) ?? ""
            if let location = headerValue("LOCATION", in: text) ?? headerValue("Location", in: text) {
                locations.insert(location.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return Array(locations)
    }
    
    private static func headerValue(_ name: String, in response: String) -> String? {
        for line in response.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    private static func fetchDescription(location: String, timeout: TimeInterval = 1.5) async -> UPnPDeviceInfo? {
        guard let url = URL(string: location), url.scheme?.lowercased() == "http" else { return nil }
        let page = await Task.detached(priority: .utility) {
            LANHTTP.get(url: url, timeout: timeout, maxBytes: 131_072)
        }.value
        guard let page, (200...299).contains(page.status) else { return nil }
        guard let xml = String(data: page.body, encoding: .utf8)
                ?? String(data: page.body, encoding: .isoLatin1) else { return nil }
        var info = parseDeviceXML(xml)
        info.locationURL = location
        if info.bestName == nil && info.macAddress.isEmpty { return nil }
        return info
    }
    
    static func parseDeviceXML(_ xml: String) -> UPnPDeviceInfo {
        var info = UPnPDeviceInfo()
        info.friendlyName = xmlTag("friendlyName", in: xml) ?? ""
        info.manufacturer = xmlTag("manufacturer", in: xml) ?? ""
        info.modelName = xmlTag("modelName", in: xml) ?? ""
        info.modelDescription = xmlTag("modelDescription", in: xml) ?? ""
        info.serialNumber = xmlTag("serialNumber", in: xml) ?? ""
        info.deviceType = xmlTag("deviceType", in: xml) ?? ""
        
        let macCandidates = [
            xmlTag("macAddress", in: xml),
            xmlTag("MACAddress", in: xml),
            xmlTag("MacAddress", in: xml),
            xmlTag("mac", in: xml),
            xmlTag("WLANMACAddress", in: xml),
            xmlTag("X_MACAddress", in: xml),
            xmlTag("X_AVM-DE_MACAddress", in: xml)
        ].compactMap { $0 }
        
        for candidate in macCandidates {
            if let mac = normalizeMAC(candidate) {
                info.macAddress = mac
                break
            }
        }
        
        if info.macAddress.isEmpty, let mac = normalizeMAC(info.serialNumber) {
            info.macAddress = mac
        }
        
        return info
    }
    
    private static func xmlTag(_ name: String, in xml: String) -> String? {
        let open = "<\(name)"
        guard let startRange = xml.range(of: open, options: .caseInsensitive) else { return nil }
        guard let tagEnd = xml[startRange.upperBound...].firstIndex(of: ">") else { return nil }
        let contentStart = xml.index(after: tagEnd)
        let close = "</\(name)>"
        guard let endRange = xml.range(of: close, options: .caseInsensitive, range: contentStart..<xml.endIndex) else {
            return nil
        }
        let raw = String(xml[contentStart..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let unescaped = raw
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return unescaped.isEmpty ? nil : unescaped
    }
    
    static func normalizeMAC(_ value: String) -> String? {
        let hex = value.uppercased().filter(\.isHexDigit)
        guard hex.count == 12 else { return nil }
        if hex == String(repeating: "0", count: 12) || hex == String(repeating: "F", count: 12) {
            return nil
        }
        return stride(from: 0, to: 12, by: 2)
            .map { String(hex[hex.index(hex.startIndex, offsetBy: $0)..<hex.index(hex.startIndex, offsetBy: $0 + 2)]) }
            .joined(separator: ":")
    }
    
    private static func hostOfURL(_ string: String) -> String? {
        guard let url = URL(string: string), let host = url.host, host.contains(".") else { return nil }
        return host
    }
    
    private static func merge(_ existing: UPnPDeviceInfo?, _ incoming: UPnPDeviceInfo) -> UPnPDeviceInfo {
        guard var base = existing else { return incoming }
        if base.friendlyName.isEmpty { base.friendlyName = incoming.friendlyName }
        if base.manufacturer.isEmpty { base.manufacturer = incoming.manufacturer }
        if base.modelName.isEmpty { base.modelName = incoming.modelName }
        if base.modelDescription.isEmpty { base.modelDescription = incoming.modelDescription }
        if base.serialNumber.isEmpty { base.serialNumber = incoming.serialNumber }
        if base.macAddress.isEmpty { base.macAddress = incoming.macAddress }
        if base.deviceType.isEmpty { base.deviceType = incoming.deviceType }
        if base.locationURL.isEmpty { base.locationURL = incoming.locationURL }
        return base
    }
}
