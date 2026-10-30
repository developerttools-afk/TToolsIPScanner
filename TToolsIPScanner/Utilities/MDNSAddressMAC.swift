import Foundation
import Darwin
import dnssd

/// mDNS AAAA lookup. A modified EUI-64 address (`ff:fe` in the interface id) becomes a MAC.
enum MDNSAddressMAC {
    static func eui64MAC(forHost host: String, timeout: TimeInterval = 0.6) async -> String? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let qualified: String
        if trimmed.contains(".") {
            qualified = trimmed
        } else {
            qualified = trimmed + ".local"
        }
        
        return await withCheckedContinuation { continuation in
            let box = OnceBox<String?>(continuation)
            let context = Unmanaged.passRetained(AddrQueryContext(box: box)).toOpaque()
            
            var serviceRef: DNSServiceRef?
            let err = DNSServiceGetAddrInfo(
                &serviceRef,
                0,
                0,
                DNSServiceProtocol(kDNSServiceProtocol_IPv6),
                qualified,
                addrCallback,
                context
            )
            
            guard err == kDNSServiceErr_NoError, let serviceRef else {
                Unmanaged<AddrQueryContext>.fromOpaque(context).release()
                box.finish(nil)
                return
            }
            
            let ctx = Unmanaged<AddrQueryContext>.fromOpaque(context).takeUnretainedValue()
            ctx.serviceRef = serviceRef
            
            let queue = DispatchQueue.global(qos: .userInitiated)
            if DNSServiceSetDispatchQueue(serviceRef, queue) != kDNSServiceErr_NoError {
                DNSServiceRefDeallocate(serviceRef)
                Unmanaged<AddrQueryContext>.fromOpaque(context).release()
                box.finish(nil)
                return
            }
            
            queue.asyncAfter(deadline: .now() + timeout) {
                ctx.finish(nil)
            }
        }
    }
}

private final class AddrQueryContext: @unchecked Sendable {
    let box: OnceBox<String?>
    var serviceRef: DNSServiceRef?
    private let lock = NSLock()
    private var done = false
    
    init(box: OnceBox<String?>) {
        self.box = box
    }
    
    func consider(address: UnsafePointer<sockaddr>?, flags: DNSServiceFlags) {
        if let address, address.pointee.sa_family == sa_family_t(AF_INET6) {
            let iid: [UInt8] = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
                withUnsafeBytes(of: ptr.pointee.sin6_addr) { raw in
                    Array(raw.suffix(8))
                }
            }
            if let mac = MACAddress.fromEUI64(interfaceID: iid) {
                finish(mac)
                return
            }
        }
        if flags & DNSServiceFlags(kDNSServiceFlagsMoreComing) == 0 {
            finish(nil)
        }
    }
    
    func finish(_ mac: String?) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        if let serviceRef {
            DNSServiceRefDeallocate(serviceRef)
            self.serviceRef = nil
        }
        box.finish(mac)
        Unmanaged.passUnretained(self).release()
    }
}

private let addrCallback: DNSServiceGetAddrInfoReply = { _, flags, _, errorCode, _, address, _, context in
    guard let context else { return }
    let ctx = Unmanaged<AddrQueryContext>.fromOpaque(context).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else { return }
    ctx.consider(address: address, flags: flags)
}
