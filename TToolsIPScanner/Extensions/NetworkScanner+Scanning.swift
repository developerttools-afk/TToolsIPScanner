import Foundation

extension NetworkScanner {
    private struct DeviceResolution {
        var hostName: String
        var macAddress: String
        var manufacturer: String
        var openPorts: [Int]
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
        guard !isScanning else {
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
        updateNetworkRange()
        
        // Cancel any existing scan
        currentScanTask?.cancel()
        
        // Start new scan task
        currentScanTask = Task { [weak self] in
            guard let self else { return }
            
            #if os(iOS) || os(visionOS)
            // Prompt for Local Network access before BSD TCP probes (TN3179).
            LocalNetworkAccess.requestIfNeeded()
            await self.updateScanState(
                isScanning: true,
                phase: .scanningNetwork,
                progress: "Lokalen Netzwerkzugriff prüfen…",
                percentage: 0
            )
            try? await Task.sleep(for: .milliseconds(800))
            
            guard !Task.isCancelled else { return }
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
        
        await MainActor.run {
            let components = ipToScan.split(separator: ".")
            if components.count >= 3 {
                let baseNetwork = components.dropLast().joined(separator: ".")
                let network = baseNetwork + ".0"
                if !self.recentNetworks.contains(network) {
                    self.recentNetworks.insert(network, at: 0)
                    if self.recentNetworks.count > 3 {
                        self.recentNetworks.removeLast()
                    }
                    self.saveSettings()
                }
            }
        }
        
        let cachedDetails = await MainActor.run {
            Dictionary(
                uniqueKeysWithValues: devices
                    .filter { $0.status != .missing }
                    .map { device in
                        (device.ipAddress, (
                            hostName: usefulHostName(device.hostName) ?? "",
                            macAddress: device.macAddress,
                            manufacturer: device.manufacturer,
                            openPorts: device.openPorts
                        ))
                    }
            )
        }
        
        await updateScanState(
            isScanning: true,
            phase: .scanningNetwork,
            progress: "Scan gestartet…",
            percentage: 0
        )
        
        await MainActor.run {
            self.previousDevices = Set(self.devices.filter { $0.status != .missing }.map { $0.ipAddress })
            self.devices = []
        }
        
        await startIPScan(
            baseIP: ipToScan,
            mode: mode,
            cachedDetails: cachedDetails
        )
    }
    
    private func startIPScan(
        baseIP: String,
        mode: ScanMode,
        cachedDetails: [String: (hostName: String, macAddress: String, manufacturer: String, openPorts: [Int])]
    ) async {
        let baseIP = baseIP.split(separator: ".").dropLast().joined(separator: ".")
        let totalIPs = 254
        let previousDevices = await MainActor.run { self.previousDevices }
        let ouiDB = await MainActor.run { self.ouiDatabase }
        
        let discoveryHits = ResolutionStore<String, [Int]>()
        
        print("🚀 Starting scan on \(baseIP).0/24 (\(totalIPs) IPs)")
        
        #if os(iOS)
        // Request permission explicitly before scan
        LocalNetworkAccess.requestIfNeeded()
        // Give iOS time to process permission
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // DIRECT TEST: Try connecting to well-known public DNS
        print("🧪 DIRECT SOCKET TEST:")
        let testSock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        if testSock < 0 {
            print("❌ socket() FAILED: \(String(cString: strerror(errno)))")
        } else {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(53).bigEndian
            inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr)
            
            let flags = fcntl(testSock, F_GETFL, 0)
            fcntl(testSock, F_SETFL, flags | O_NONBLOCK)
            
            let result = withUnsafePointer(to: addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    Darwin.connect(testSock, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            print("✅ socket() OK, connect() = \(result), errno = \(errno) (\(String(cString: strerror(errno))))")
            Darwin.close(testSock)
        }
        
        // Test gateway directly
        print("🧪 TESTING GATEWAY \(baseIP).1 directly:")
        let (gw_alive, gw_open) = self.probeHost(ip: "\(baseIP).1", port: 80, timeout: 1.0)
        print("   → Port 80: alive=\(gw_alive), open=\(gw_open)")
        
        print("⚠️ iOS: Local Network Permission status: CHECK IN SETTINGS")
        print("⚠️ Settings → TTools IP Scanner → Local Network → Should be ON")
        #endif
        
        await updateScanState(
            progress: "Starte Scan von \(totalIPs) IPs auf \(baseIP).0/24…",
            percentage: 0
        )
        
        // Use TaskGroup with higher concurrency for faster scanning
        await withTaskGroup(of: (Int, String, [Int]?, DeviceInfo?).self) { group in
            for i in 1...totalIPs {
                // Let Swift's cooperative task pool handle concurrency
                // Typically runs 50-100 tasks in parallel on modern hardware
                group.addTask {
                    guard !Task.isCancelled else { return (i, "", nil, nil) }
                    
                    let ip = "\(baseIP).\(i)"
                    
                    // Phase 1: lightweight discovery only (fixed ports)
                    let (isAlive, foundPorts) = self.discoverHost(ip)
                    
                    var newDevice: DeviceInfo?
                    if isAlive {
                        let status = DeviceStatusResolver.status(for: ip, previousIPs: previousDevices)
                        let cached = cachedDetails[ip]
                        let remembered = await self.rememberedHostName(ip: ip, mac: cached?.macAddress ?? "")
                        
                        newDevice = DeviceInfo(
                            id: UUID(),
                            ipAddress: ip,
                            hostName: remembered
                                ?? cached.flatMap { self.usefulHostName($0.hostName) }
                                ?? "…",
                            macAddress: cached?.macAddress ?? "",
                            manufacturer: cached?.manufacturer ?? "",
                            openPorts: foundPorts,
                            status: status,
                            isExpanded: false
                        )
                    }
                    
                    return (i, ip, isAlive ? foundPorts : nil, newDevice)
                }
            }
            
            var completedCount = 0
            var foundCount = 0
            for await (_, ip, foundPorts, device) in group {
                guard !Task.isCancelled else { break }
                
                if let foundPorts = foundPorts {
                    discoveryHits.set(foundPorts, for: ip)
                }
                
                if let device = device {
                    foundCount += 1
                    // IMMEDIATE UI update - no batching for found devices
                    await MainActor.run {
                        self.devices.append(device)
                        self.currentScanIP = ip
                        self.scanProgress = "\(foundCount) Gerät(e) gefunden"
                    }
                }
                
                completedCount += 1
                
                // Update progress every 10 IPs (less UI thrashing)
                if completedCount % 10 == 0 || device != nil {
                    await MainActor.run {
                        self.currentScanIP = ip
                        if device == nil {
                            self.scanProgress = "Scanne \(completedCount)/\(totalIPs)... (\(foundCount) gefunden)"
                        }
                    }
                    await updateScanState(percentage: Double(completedCount) * 100.0 / Double(totalIPs))
                }
            }
        }
        
        guard !Task.isCancelled else { return }
        
        let deviceCount = await MainActor.run { self.devices.count }
        await updateScanState(
            phase: .scanningPorts,
            progress: "Hosts gefunden: \(deviceCount) — starte Custom-Port-Scan…",
            percentage: 0
        )
        
        await resolveAndScanDevices(
            mode: mode,
            cachedDetails: cachedDetails,
            discoveryPorts: discoveryHits.snapshot(),
            ouiDB: ouiDB
        )
    }
    
    /// Phase 2: custom/full port scan on found hosts, then hostname/MAC.
    private func resolveAndScanDevices(
        mode: ScanMode,
        cachedDetails: [String: (hostName: String, macAddress: String, manufacturer: String, openPorts: [Int])],
        discoveryPorts: [String: [Int]],
        ouiDB: [String: String]
    ) async {
        let snapshot = await MainActor.run { self.devices }
        guard !snapshot.isEmpty else {
            await finishScan(devices: snapshot)
            return
        }
        
        let totalDevices = snapshot.count
        let portsToProbe = portsForScan(mode)
        let resolutions = ResolutionStore<UUID, DeviceResolution>()
        
        // Use TaskGroup for parallel device resolution
        await withTaskGroup(of: (UUID, Int, DeviceResolution).self) { group in
            for (index, device) in snapshot.enumerated() {
                group.addTask {
                    guard !Task.isCancelled else {
                        return (device.id, index, DeviceResolution(
                            hostName: device.hostName,
                            macAddress: device.macAddress,
                            manufacturer: device.manufacturer,
                            openPorts: device.openPorts
                        ))
                    }
                    
                    let probed = discoveryPorts[device.ipAddress] ?? device.openPorts
                    let scanned = self.probeOpenPorts(
                        device.ipAddress,
                        ports: portsToProbe,
                        timeout: 0.5
                    )
                    let openPorts = Array(Set(probed + scanned)).sorted()
                    
                    // Update device with open ports on main thread
                    await MainActor.run {
                        self.updateDevice(id: device.id) { item in
                            item.openPorts = openPorts
                        }
                    }
                    
                    guard !Task.isCancelled else {
                        return (device.id, index, DeviceResolution(
                            hostName: device.hostName,
                            macAddress: device.macAddress,
                            manufacturer: device.manufacturer,
                            openPorts: openPorts
                        ))
                    }
                    
                    let cached = cachedDetails[device.ipAddress]
                    var (macAddress, manufacturer) = self.getMacAddress(
                        for: device.ipAddress,
                        openPorts: openPorts,
                        knownHostName: device.hostName,
                        ouiDB: ouiDB
                    )
                    if macAddress.isEmpty {
                        macAddress = cached?.macAddress ?? device.macAddress
                    }
                    await self.migrateAliasIfNeeded(ip: device.ipAddress, mac: macAddress)
                    
                    let resolvedDNS = await self.getHostName(for: device.ipAddress, timeout: 0.6)
                    let hostName = await self.rememberedHostName(ip: device.ipAddress, mac: macAddress)
                        ?? self.usefulHostName(resolvedDNS)
                        ?? self.usefulHostName(cached?.hostName)
                        ?? self.usefulHostName(device.hostName)
                        ?? "Unknown"
                    
                    if manufacturer.isEmpty || manufacturer == "Unbekannt" {
                        if let cachedManufacturer = cached?.manufacturer, !cachedManufacturer.isEmpty {
                            manufacturer = cachedManufacturer
                        } else if !device.manufacturer.isEmpty {
                            manufacturer = device.manufacturer
                        } else if let portBased = self.getManufacturerFromPortScan(openPorts: openPorts) {
                            manufacturer = portBased
                        }
                    }
                    
                    return (device.id, index, DeviceResolution(
                        hostName: hostName,
                        macAddress: macAddress,
                        manufacturer: manufacturer,
                        openPorts: openPorts
                    ))
                }
            }
            
            var completedCount = 0
            for await (deviceId, _, resolution) in group {
                guard !Task.isCancelled else { break }
                
                resolutions.set(resolution, for: deviceId)
                completedCount += 1
                
                await updateScanState(
                    progress: "Port-Scan: \(completedCount)/\(totalDevices)",
                    percentage: (Double(completedCount) / Double(totalDevices)) * 100
                )
            }
        }
        
        guard !Task.isCancelled else { return }
        
        let resolved = resolutions.snapshot()
        let previousDevices = await MainActor.run { self.previousDevices }
        
        var updatedDevices = await MainActor.run {
            self.devices.map { device -> DeviceInfo in
                guard let resolution = resolved[device.id] else { return device }
                var copy = device
                copy.hostName = resolution.hostName
                copy.macAddress = resolution.macAddress
                copy.manufacturer = resolution.manufacturer
                copy.openPorts = resolution.openPorts.isEmpty ? device.openPorts : resolution.openPorts
                return copy
            }
        }
        
        let foundIPs = Set(updatedDevices.map(\.ipAddress))
        let missingIPs = DeviceStatusResolver.missingIPs(
            previousIPs: previousDevices,
            foundIPs: foundIPs
        )
        for ip in missingIPs {
            updatedDevices.append(DeviceInfo(
                id: UUID(),
                ipAddress: ip,
                hostName: "Nicht mehr verfügbar",
                macAddress: cachedDetails[ip]?.macAddress ?? "",
                manufacturer: cachedDetails[ip]?.manufacturer ?? "",
                openPorts: [],
                status: .missing,
                isExpanded: false
            ))
        }
        
        await finishScan(devices: updatedDevices)
    }
    
    private func finishScan(devices updatedDevices: [DeviceInfo]) async {
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            self.devices = updatedDevices
            self.sortDevices()
            self.scanProgress = "Scan abgeschlossen"
            self.progressPercentage = 100
            self.scanPhase = .finished
            self.isScanning = false
            self.saveSettings()
        }
    }
    
    private func updateDevice(id: UUID, mutate: (inout DeviceInfo) -> Void) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        var copy = devices
        mutate(&copy[index])
        devices = copy
    }
    
    /// Ports for phase-2 custom/full scan on discovered hosts.
    private func portsForScan(_ mode: ScanMode) -> [Int] {
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
    
    func stopScan() {
        currentScanTask?.cancel()
        currentScanTask = nil
        isScanning = false
        scanPhase = .idle
        progressPercentage = 0
        scanProgress = "Scan abgebrochen"
        currentScanIP = ""
        saveSettings()
    }
    
    nonisolated private func usefulHostName(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              name != "…",
              name != "Resolving...",
              name != "Unknown",
              name != "Nicht mehr verfügbar" else {
            return nil
        }
        return name
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
