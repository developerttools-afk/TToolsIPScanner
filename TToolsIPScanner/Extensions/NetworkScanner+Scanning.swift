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
        
        #if os(iOS) || os(visionOS)
        // Prompt for Local Network access before BSD TCP probes (TN3179).
        LocalNetworkAccess.requestIfNeeded()
        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        scanPhase = .scanningNetwork
        scanProgress = "Lokalen Netzwerkzugriff prüfen…"
        progressPercentage = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.isScanActive(generation) else { return }
            self.beginScanPipeline(ipToScan: ipToScan, mode: mode, generation: generation)
        }
        #else
        scanGeneration += 1
        beginScanPipeline(ipToScan: ipToScan, mode: mode, generation: scanGeneration)
        #endif
    }
    
    private func beginScanPipeline(ipToScan: String, mode: ScanMode, generation: Int) {
        guard isScanActive(generation) else { return }
        
        let components = ipToScan.split(separator: ".")
        if components.count >= 3 {
            let baseNetwork = components.dropLast().joined(separator: ".")
            let network = baseNetwork + ".0"
            if !recentNetworks.contains(network) {
                recentNetworks.insert(network, at: 0)
                if recentNetworks.count > 3 {
                    recentNetworks.removeLast()
                }
                saveSettings()
            }
        }
        
        let cachedDetails = Dictionary(
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
        
        isScanning = true
        scanPhase = .scanningNetwork
        previousDevices = Set(devices.filter { $0.status != .missing }.map { $0.ipAddress })
        devices = []
        progressPercentage = 0
        scanProgress = "Scan gestartet…"
        
        startIPScan(
            baseIP: ipToScan,
            mode: mode,
            generation: generation,
            cachedDetails: cachedDetails
        )
    }
    
    private func startIPScan(
        baseIP: String,
        mode: ScanMode,
        generation: Int,
        cachedDetails: [String: (hostName: String, macAddress: String, manufacturer: String, openPorts: [Int])]
    ) {
        let baseIP = baseIP.split(separator: ".").dropLast().joined(separator: ".")
        let group = DispatchGroup()
        let totalIPs = 254
        let progress = ProgressCounter()
        let discoveryHits = ResolutionStore<String, [Int]>()
        
        let workerQueue = OperationQueue()
        workerQueue.name = "com.ttools.ipscanner.ip-workers"
        workerQueue.qualityOfService = .utility
        workerQueue.maxConcurrentOperationCount = 12
        
        for i in 1...totalIPs {
            group.enter()
            workerQueue.addOperation {
                defer { group.leave() }
                guard self.isScanActive(generation) else { return }
                
                let ip = "\(baseIP).\(i)"
                DispatchQueue.main.async {
                    guard self.isScanActive(generation) else { return }
                    self.currentScanIP = ip
                }
                
                // Phase 1: lightweight discovery only (fixed ports).
                let foundPorts = self.probeOpenDiscoveryPorts(ip)
                if !foundPorts.isEmpty {
                    discoveryHits.set(foundPorts, for: ip)
                    let status = DeviceStatusResolver.status(for: ip, previousIPs: self.previousDevices)
                    let cached = cachedDetails[ip]
                    let remembered = self.rememberedHostName(ip: ip, mac: cached?.macAddress ?? "")
                    
                    DispatchQueue.main.async {
                        guard self.isScanActive(generation) else { return }
                        let newDevice = DeviceInfo(
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
                        self.devices = self.devices + [newDevice]
                        self.scanProgress = "IP gefunden: \(ip)"
                    }
                }
                
                let count = progress.increment()
                DispatchQueue.main.async {
                    guard self.isScanActive(generation) else { return }
                    self.progressPercentage = Double(count) * 100.0 / Double(totalIPs)
                }
            }
        }
        
        group.notify(queue: .main) {
            guard self.isScanActive(generation) else { return }
            self.scanProgress = "Hosts gefunden: \(self.devices.count) — starte Custom-Port-Scan…"
            self.progressPercentage = 0
            self.scanPhase = .scanningPorts
            self.resolveAndScanDevices(
                mode: mode,
                generation: generation,
                cachedDetails: cachedDetails,
                discoveryPorts: discoveryHits.snapshot()
            )
        }
    }
    
    /// Phase 2: custom/full port scan on found hosts, then hostname/MAC.
    private func resolveAndScanDevices(
        mode: ScanMode,
        generation: Int,
        cachedDetails: [String: (hostName: String, macAddress: String, manufacturer: String, openPorts: [Int])],
        discoveryPorts: [String: [Int]]
    ) {
        let snapshot = devices
        guard !snapshot.isEmpty else {
            finishScan(generation: generation, devices: devices)
            return
        }
        
        let totalDevices = snapshot.count
        let progress = ProgressCounter()
        let resolutions = ResolutionStore<UUID, DeviceResolution>()
        let group = DispatchGroup()
        let portsToProbe = portsForScan(mode)
        
        let workerQueue = OperationQueue()
        workerQueue.name = "com.ttools.ipscanner.device-workers"
        workerQueue.qualityOfService = .utility
        workerQueue.maxConcurrentOperationCount = 4
        
        for device in snapshot {
            group.enter()
            workerQueue.addOperation {
                defer {
                    let completed = progress.increment()
                    group.leave()
                    DispatchQueue.main.async {
                        guard self.isScanActive(generation) else { return }
                        self.progressPercentage = (Double(completed) / Double(totalDevices)) * 100
                        self.scanProgress = "Port-Scan: \(completed)/\(totalDevices)"
                        self.currentScanIP = device.ipAddress
                    }
                }
                
                guard self.isScanActive(generation) else { return }
                
                let probed = discoveryPorts[device.ipAddress] ?? device.openPorts
                let scanned = self.probeOpenPorts(
                    device.ipAddress,
                    ports: portsToProbe,
                    timeout: 0.5
                )
                let openPorts = Array(Set(probed + scanned)).sorted()
                
                DispatchQueue.main.async {
                    guard self.isScanActive(generation) else { return }
                    self.updateDevice(id: device.id) { item in
                        item.openPorts = openPorts
                    }
                }
                
                guard self.isScanActive(generation) else {
                    resolutions.set(
                        DeviceResolution(
                            hostName: device.hostName,
                            macAddress: device.macAddress,
                            manufacturer: device.manufacturer,
                            openPorts: openPorts
                        ),
                        for: device.id
                    )
                    return
                }
                
                let cached = cachedDetails[device.ipAddress]
                var (macAddress, manufacturer) = self.getMacAddress(
                    for: device.ipAddress,
                    openPorts: openPorts,
                    knownHostName: device.hostName
                )
                if macAddress.isEmpty {
                    macAddress = cached?.macAddress ?? device.macAddress
                }
                self.migrateAliasIfNeeded(ip: device.ipAddress, mac: macAddress)
                
                let resolvedDNS = self.getHostName(for: device.ipAddress, timeout: 0.6)
                let hostName = self.rememberedHostName(ip: device.ipAddress, mac: macAddress)
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
                
                resolutions.set(
                    DeviceResolution(
                        hostName: hostName,
                        macAddress: macAddress,
                        manufacturer: manufacturer,
                        openPorts: openPorts
                    ),
                    for: device.id
                )
            }
        }
        
        group.notify(queue: .main) {
            guard self.isScanActive(generation) else { return }
            
            let resolved = resolutions.snapshot()
            var updatedDevices = self.devices.map { device -> DeviceInfo in
                guard let resolution = resolved[device.id] else { return device }
                var copy = device
                copy.hostName = resolution.hostName
                copy.macAddress = resolution.macAddress
                copy.manufacturer = resolution.manufacturer
                copy.openPorts = resolution.openPorts.isEmpty ? device.openPorts : resolution.openPorts
                return copy
            }
            
            let foundIPs = Set(updatedDevices.map(\.ipAddress))
            let missingIPs = DeviceStatusResolver.missingIPs(
                previousIPs: self.previousDevices,
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
            
            self.finishScan(generation: generation, devices: updatedDevices)
        }
    }
    
    private func finishScan(generation: Int, devices updatedDevices: [DeviceInfo]) {
        guard isScanActive(generation) else { return }
        devices = updatedDevices
        sortDevices()
        scanProgress = "Scan abgeschlossen"
        progressPercentage = 100
        scanPhase = .finished
        isScanning = false
        saveSettings()
    }
    
    private func updateDevice(id: UUID, mutate: (inout DeviceInfo) -> Void) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        var copy = devices
        mutate(&copy[index])
        devices = copy
    }
    
    /// Ports for phase-2 custom/full scan on discovered hosts.
    private func portsForScan(_ mode: ScanMode) -> [Int] {
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
        scanGeneration += 1
        isScanning = false
        scanPhase = .idle
        progressPercentage = 0
        scanProgress = "Scan abgebrochen"
        currentScanIP = ""
        saveSettings()
    }
    
    private func isScanActive(_ generation: Int) -> Bool {
        generation == scanGeneration
    }
    
    private func usefulHostName(_ name: String?) -> String? {
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

/// Thread-safe counter used for scan progress.
private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

/// Thread-safe dictionary — avoids Swift `var` capture races across OperationQueue jobs.
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
