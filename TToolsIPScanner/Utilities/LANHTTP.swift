import Foundation
import Darwin

/// HTTP on the LAN without URLSession, so a timeout or a refused port does not
/// become an NSURLError log line.
enum LANHTTP {
    struct Response: Equatable, Sendable {
        var status: Int
        var headers: [String: String]
        var body: Data
    }
    
    static func get(url: URL, timeout: TimeInterval, maxBytes: Int = 65_536) -> Response? {
        perform(
            method: "GET",
            url: url,
            headers: ["User-Agent": "TToolsIPScanner/1.0", "Accept": "*/*"],
            body: nil,
            timeout: timeout,
            maxBytes: maxBytes
        )
    }
    
    static func perform(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval,
        maxBytes: Int = 65_536
    ) -> Response? {
        guard url.scheme?.lowercased() == "http", let host = url.host, !host.isEmpty else { return nil }
        let port = url.port ?? 80
        guard let address = resolveIPv4(host, port: port) else { return nil }
        
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        defer { Darwin.close(sock) }
        var nosig: Int32 = 1
        _ = setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
        
        guard connect(sock, to: address, timeout: timeout) else { return nil }
        
        var fields = headers
        if !fields.keys.contains(where: { $0.caseInsensitiveCompare("Host") == .orderedSame }) {
            fields["Host"] = port == 80 ? host : "\(host):\(port)"
        }
        if !fields.keys.contains(where: { $0.caseInsensitiveCompare("Connection") == .orderedSame }) {
            fields["Connection"] = "close"
        }
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        var head = "\(method) \(path)\(query) HTTP/1.1\r\n"
        for (name, value) in fields {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        var payload = Data(head.utf8)
        if let body, !body.isEmpty { payload.append(body) }
        guard sendAll(sock, payload, timeout: timeout) else { return nil }
        
        let data = readAll(sock, timeout: timeout, maxBytes: maxBytes)
        guard !data.isEmpty else { return nil }
        return parse(data)
    }
    
    static func parse(_ data: Data) -> Response? {
        let separator = Data([13, 10, 13, 10])
        let split: Data.Index
        let headerData: Data
        let body: Data
        if let range = data.range(of: separator) {
            split = range.lowerBound
            headerData = data[..<split]
            let bodyStart = range.upperBound
            body = bodyStart < data.endIndex ? data[bodyStart...] : Data()
        } else {
            headerData = data
            body = Data()
        }
        guard let headerText = String(data: headerData, encoding: .utf8)
                ?? String(data: headerData, encoding: .isoLatin1) else { return nil }
        let lines = headerText.split(whereSeparator: \.isNewline)
        guard let statusLine = lines.first else { return nil }
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let status = Int(parts[1]) else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { headers[name] = value }
        }
        return Response(status: status, headers: headers, body: Data(body))
    }
    
    private static func resolveIPv4(_ host: String, port: Int) -> sockaddr_in? {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        if inet_pton(AF_INET, host, &address.sin_addr) == 1 {
            return address
        }
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &info) == 0, let info else { return nil }
        defer { freeaddrinfo(info) }
        guard let resolved = info.pointee.ai_addr else { return nil }
        return resolved.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
    }
    
    private static func connect(_ sock: Int32, to address: sockaddr_in, timeout: TimeInterval) -> Bool {
        var address = address
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
        let result = withUnsafePointer(to: &address) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(sock, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        
        var fds = fd_set()
        __darwin_fd_set(sock, &fds)
        var tv = SocketTimeout.makeTimeval(from: timeout)
        guard select(sock + 1, nil, &fds, nil, &tv) > 0 else { return false }
        var error: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        return getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &len) == 0 && error == 0
    }
    
    private static func sendAll(_ sock: Int32, _ data: Data, timeout: TimeInterval) -> Bool {
        var remaining = data
        let deadline = Date().addingTimeInterval(timeout)
        while !remaining.isEmpty, Date() < deadline {
            let sent = remaining.withUnsafeBytes { raw in
                Darwin.send(sock, raw.baseAddress, raw.count, 0)
            }
            if sent > 0 {
                remaining.removeFirst(sent)
                continue
            }
            if errno == EAGAIN || errno == EWOULDBLOCK {
                guard wait(sock, write: true, deadline: deadline) else { return false }
                continue
            }
            return false
        }
        return remaining.isEmpty
    }
    
    private static func readAll(_ sock: Int32, timeout: TimeInterval, maxBytes: Int) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 2048)
        let deadline = Date().addingTimeInterval(timeout)
        while data.count < maxBytes, Date() < deadline {
            let count = Darwin.recv(sock, &buffer, buffer.count, 0)
            if count > 0 {
                data.append(buffer, count: count)
                continue
            }
            if count == 0 { break }
            if errno == EAGAIN || errno == EWOULDBLOCK {
                guard wait(sock, write: false, deadline: deadline) else { break }
                continue
            }
            break
        }
        return data
    }
    
    private static func wait(_ sock: Int32, write: Bool, deadline: Date) -> Bool {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return false }
        var fds = fd_set()
        __darwin_fd_set(sock, &fds)
        var tv = SocketTimeout.makeTimeval(from: remaining, minimumMicroseconds: 1_000)
        let ready = write
            ? select(sock + 1, nil, &fds, nil, &tv)
            : select(sock + 1, &fds, nil, nil, &tv)
        return ready > 0
    }
}
