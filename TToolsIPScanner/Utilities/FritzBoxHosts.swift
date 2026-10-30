import Foundation
import CommonCrypto
import CryptoKit

struct FritzHostEntry: Equatable, Sendable {
    var ip: String
    var mac: String
    var hostName: String
}

/// TR-064 `Hosts:GetGenericHostEntry` on port 49000. The password never leaves the challenge handshake.
enum FritzBoxHosts {
    static func fetch(
        host: String,
        username: String,
        password: String,
        timeout: TimeInterval = 5
    ) async -> [FritzHostEntry] {
        let target = normalizeHost(host)
        guard !target.isEmpty else { return [] }
        let deadline = Date().addingTimeInterval(timeout)
        let sid: String?
        if password.isEmpty {
            sid = nil
        } else {
            sid = await login(host: target, username: username, password: password, deadline: deadline)
            if sid == nil { return [] }
        }
        guard let count = await hostCount(host: target, sid: sid, deadline: deadline), count > 0 else {
            return []
        }
        var entries: [FritzHostEntry] = []
        let limit = min(count, 128)
        for index in 0..<limit {
            if Date() >= deadline { break }
            if let entry = await hostEntry(host: target, index: index, sid: sid, deadline: deadline) {
                entries.append(entry)
            }
        }
        return entries
    }
    
    static func response(challenge: String, password: String) -> String? {
        if challenge.hasPrefix("2$") {
            return pbkdf2Response(challenge: challenge, password: password)
        }
        let text = "\(challenge)-\(password)"
        guard let data = text.data(using: .utf16LittleEndian) else { return nil }
        let digest = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return "\(challenge)-\(digest)"
    }
    
    private static func normalizeHost(_ raw: String) -> String {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("http://") { host.removeFirst(7) }
        if host.hasPrefix("https://") { host.removeFirst(8) }
        if let slash = host.firstIndex(of: "/") { host = String(host[..<slash]) }
        if let colon = host.firstIndex(of: ":") { host = String(host[..<colon]) }
        return host
    }
    
    private static func pbkdf2Response(challenge: String, password: String) -> String? {
        let parts = challenge.split(separator: "$").map(String.init)
        guard parts.count == 5, parts[0] == "2",
              let iter1 = UInt32(parts[1]),
              let iter2 = UInt32(parts[3]),
              let salt1 = Data(hex: parts[2]),
              let salt2 = Data(hex: parts[4]),
              let passwordData = password.data(using: .utf8),
              let hash1 = pbkdf2(password: passwordData, salt: salt1, iterations: iter1),
              let hash2 = pbkdf2(password: hash1, salt: salt2, iterations: iter2) else {
            return nil
        }
        return "\(parts[4])$\(hash2.hex)"
    }
    
    private static func pbkdf2(password: Data, salt: Data, iterations: UInt32) -> Data? {
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { derivedBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        return status == kCCSuccess ? derived : nil
    }
    
    private static func login(host: String, username: String, password: String, deadline: Date) async -> String? {
        guard let first = await get(url: "http://\(host)/login_sid.lua?version=2", deadline: deadline) else {
            return nil
        }
        guard let challenge = xmlValue("Challenge", in: first),
              let response = response(challenge: challenge, password: password),
              var components = URLComponents(string: "http://\(host)/login_sid.lua") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "response", value: response)
        ]
        guard let url = components.url,
              let second = await get(url: url.absoluteString, deadline: deadline),
              let sid = xmlValue("SID", in: second),
              sid != String(repeating: "0", count: 16) else {
            return nil
        }
        return sid
    }
    
    private static func hostCount(host: String, sid: String?, deadline: Date) async -> Int? {
        let xml = await soap(
            host: host,
            sid: sid,
            action: "GetHostNumberOfEntries",
            body: "",
            deadline: deadline
        )
        guard let raw = xml.flatMap({ xmlValue("NewHostNumberOfEntries", in: $0) }) else { return nil }
        return Int(raw)
    }
    
    private static func hostEntry(host: String, index: Int, sid: String?, deadline: Date) async -> FritzHostEntry? {
        let xml = await soap(
            host: host,
            sid: sid,
            action: "GetGenericHostEntry",
            body: "<NewIndex>\(index)</NewIndex>",
            deadline: deadline
        )
        guard let xml,
              let ip = xmlValue("NewIPAddress", in: xml),
              let mac = xmlValue("NewMACAddress", in: xml),
              MACAddress.normalize(mac) != nil else { return nil }
        let name = xmlValue("NewHostName", in: xml) ?? ""
        return FritzHostEntry(ip: ip, mac: mac, hostName: name)
    }
    
    private static func soap(
        host: String,
        sid: String?,
        action: String,
        body: String,
        deadline: Date
    ) async -> String? {
        var urlString = "http://\(host):49000/upnp/control/hosts"
        if let sid, !sid.isEmpty {
            urlString += "?sid=\(sid)"
        }
        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:\(action) xmlns:u="urn:dslforum-org:service:Hosts:1">\(body)</u:\(action)></s:Body></s:Envelope>
        """
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: min(2, max(0.2, deadline.timeIntervalSinceNow)))
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("urn:dslforum-org:service:Hosts:1#\(action)", forHTTPHeaderField: "SOAPAction")
        request.httpBody = Data(envelope.utf8)
        return await send(request)
    }
    
    private static func get(url: String, deadline: Date) async -> String? {
        guard let url = URL(string: url) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: min(2, max(0.2, deadline.timeIntervalSinceNow)))
        request.httpMethod = "GET"
        return await send(request)
    }
    
    private static func send(_ request: URLRequest) async -> String? {
        guard let url = request.url else { return nil }
        let timeout = min(2, max(0.2, request.timeoutInterval))
        let method = request.httpMethod ?? "GET"
        let headers = request.allHTTPHeaderFields ?? [:]
        let body = request.httpBody
        let page = await Task.detached(priority: .utility) {
            LANHTTP.perform(method: method, url: url, headers: headers, body: body, timeout: timeout)
        }.value
        guard let page, (200...299).contains(page.status) else { return nil }
        return String(data: page.body, encoding: .utf8)
            ?? String(data: page.body, encoding: .isoLatin1)
    }
    
    static func xmlValue(_ tag: String, in xml: String) -> String? {
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        guard let start = xml.range(of: open),
              let end = xml.range(of: close, range: start.upperBound..<xml.endIndex) else { return nil }
        let value = String(xml[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Data {
    init?(hex: String) {
        let cleaned = hex.filter(\.isHexDigit)
        guard cleaned.count == hex.count, cleaned.count.isMultiple(of: 2), !cleaned.isEmpty else { return nil }
        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
    
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
