import Foundation
import dnssd

/// Reverse PTR via mDNSResponder (`DNSServiceQueryRecord`).
/// Falls back to timed `getnameinfo` when dnssd returns nothing.
enum MDNSReverseLookup {
    static func lookup(ip: String, timeout: TimeInterval = 1.0) async -> String? {
        if let ptr = await queryPTR(ip: ip, timeout: timeout) {
            return ptr
        }
        return await TimedNameLookup.reverseDNS(ip: ip, timeout: min(timeout, 0.9), requireName: true)
    }
    
    /// Query `x.x.x.x.in-addr.arpa` PTR (unicast DNS + mDNS via mDNSResponder).
    private static func queryPTR(ip: String, timeout: TimeInterval) async -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        let reverseName = "\(parts[3]).\(parts[2]).\(parts[1]).\(parts[0]).in-addr.arpa"
        
        return await withCheckedContinuation { continuation in
            let box = OnceBox<String?>(continuation)
            let context = Unmanaged.passRetained(PTRQueryContext(box: box)).toOpaque()
            
            var serviceRef: DNSServiceRef?
            let err = DNSServiceQueryRecord(
                &serviceRef,
                DNSServiceFlags(kDNSServiceFlagsReturnIntermediates),
                0,
                reverseName,
                UInt16(kDNSServiceType_PTR),
                UInt16(kDNSServiceClass_IN),
                ptrCallback,
                context
            )
            
            guard err == kDNSServiceErr_NoError, let serviceRef else {
                Unmanaged<PTRQueryContext>.fromOpaque(context).release()
                box.finish(nil)
                return
            }
            
            let ctx = Unmanaged<PTRQueryContext>.fromOpaque(context).takeUnretainedValue()
            ctx.serviceRef = serviceRef
            
            let queue = DispatchQueue.global(qos: .userInitiated)
            let setErr = DNSServiceSetDispatchQueue(serviceRef, queue)
            if setErr != kDNSServiceErr_NoError {
                DNSServiceRefDeallocate(serviceRef)
                Unmanaged<PTRQueryContext>.fromOpaque(context).release()
                box.finish(nil)
                return
            }
            
            queue.asyncAfter(deadline: .now() + timeout) {
                ctx.finish(nil)
            }
        }
    }
}

fileprivate final class PTRQueryContext: @unchecked Sendable {
    let box: OnceBox<String?>
    var serviceRef: DNSServiceRef?
    private let lock = NSLock()
    private var done = false
    
    init(box: OnceBox<String?>) {
        self.box = box
    }
    
    func finish(_ name: String?) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        if let serviceRef {
            DNSServiceRefDeallocate(serviceRef)
            self.serviceRef = nil
        }
        box.finish(name)
        Unmanaged.passUnretained(self).release()
    }
}

private let ptrCallback: DNSServiceQueryRecordReply = { _, _, _, errorCode, _, rrtype, _, rdlen, rdata, _, context in
    guard let context else { return }
    let ctx = Unmanaged<PTRQueryContext>.fromOpaque(context).takeUnretainedValue()
    
    guard errorCode == kDNSServiceErr_NoError,
          rrtype == UInt16(kDNSServiceType_PTR),
          let rdata,
          rdlen > 0 else {
        return
    }
    
    let bytes = UnsafeRawBufferPointer(start: rdata, count: Int(rdlen))
    guard let name = decodeDNSName(bytes) else { return }
    var cleaned = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    if cleaned.lowercased().hasSuffix(".local") {
        cleaned = String(cleaned.dropLast(6))
    }
    guard !cleaned.isEmpty else { return }
    ctx.finish(cleaned)
}

/// Decode a DNS wire-format domain name (no compression pointers expected in rdata for PTR).
private func decodeDNSName(_ bytes: UnsafeRawBufferPointer) -> String? {
    var labels: [String] = []
    var index = 0
    while index < bytes.count {
        let length = Int(bytes[index])
        index += 1
        if length == 0 { break }
        if length & 0xC0 != 0 { return labels.isEmpty ? nil : labels.joined(separator: ".") }
        guard index + length <= bytes.count else { return nil }
        let slice = bytes[index..<(index + length)]
        if let label = String(bytes: slice, encoding: .utf8), !label.isEmpty {
            labels.append(label)
        }
        index += length
    }
    return labels.isEmpty ? nil : labels.joined(separator: ".")
}
