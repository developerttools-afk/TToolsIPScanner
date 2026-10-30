import Foundation

/// Lightweight banner reads for already-discovered open ports.
enum BannerGrabber {
    struct Result: Sendable {
        var detailHint: String = ""
        var osHint: String = ""
        var manufacturer: String = ""
    }
    
    static func probe(ip: String, openPorts: [Int], timeout: TimeInterval = 0.8) async -> Result {
        await Task.detached(priority: .utility) {
            probeBlocking(ip: ip, openPorts: openPorts, timeout: timeout)
        }.value
    }
    
    private static func probeBlocking(ip: String, openPorts: [Int], timeout: TimeInterval) -> Result {
        var result = Result()
        
        if openPorts.contains(22), let banner = readLine(ip: ip, port: 22, timeout: timeout) {
            result.detailHint = banner
            if let osHint = DeviceFingerprint.osHint(fromSSH: banner) {
                result.osHint = osHint
            }
            if let vendor = DeviceFingerprint.manufacturer(text: banner) {
                result.manufacturer = vendor
            }
        }
        
        for port in [80, 8080, 8123] where openPorts.contains(port) {
            guard let page = httpPage(ip: ip, port: port, timeout: timeout) else { continue }
            let hint = DeviceFingerprint.httpDetail(server: page.server, title: page.title) ?? ""
            if result.detailHint.isEmpty, !hint.isEmpty {
                result.detailHint = hint
            }
            if result.manufacturer.isEmpty {
                let blob = [page.server, page.title].compactMap { $0 }.joined(separator: " ")
                if let vendor = DeviceFingerprint.manufacturer(text: blob) {
                    result.manufacturer = vendor
                }
            }
            if !result.detailHint.isEmpty, !result.manufacturer.isEmpty { break }
        }
        
        if result.detailHint.isEmpty, openPorts.contains(443) {
            if let page = httpPage(ip: ip, port: 443, timeout: timeout, tls: true) {
                result.detailHint = DeviceFingerprint.httpDetail(server: page.server, title: page.title) ?? ""
                if result.manufacturer.isEmpty {
                    let blob = [page.server, page.title].compactMap { $0 }.joined(separator: " ")
                    if let vendor = DeviceFingerprint.manufacturer(text: blob) {
                        result.manufacturer = vendor
                    }
                }
            }
        }
        
        // 6053 is the ESPHome API, not HTTP. An open port is the signal.
        if result.manufacturer.isEmpty, let vendor = DeviceFingerprint.manufacturer(ports: openPorts) {
            result.manufacturer = vendor
        }
        
        return result
    }
    
    private static func readLine(ip: String, port: Int, timeout: TimeInterval) -> String? {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        defer { Darwin.close(sock) }
        
        guard connectWithTimeout(sock: sock, ip: ip, port: port, timeout: timeout) else { return nil }
        
        var buf = [UInt8](repeating: 0, count: 256)
        let n = recv(sock, &buf, buf.count, 0)
        guard n > 0 else { return nil }
        let line = String(bytes: buf.prefix(n), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return line?.isEmpty == false ? line : nil
    }
    
    private struct HTTPPage {
        var server: String?
        var title: String?
    }
    
    /// Server header and title from a raw HTTP response. Used by the socket probe.
    static func fields(fromHTTPResponse text: String) -> (server: String?, title: String?) {
        let serverLine = text.split(whereSeparator: \.isNewline).first {
            $0.lowercased().hasPrefix("server:")
        }
        let server = serverLine.map {
            String($0.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var title: String?
        if let titleRange = text.range(of: "<title>", options: .caseInsensitive),
           let endRange = text.range(of: "</title>", options: .caseInsensitive, range: titleRange.upperBound..<text.endIndex) {
            let value = text[titleRange.upperBound..<endRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { title = value }
        }
        let cleanedServer = (server?.isEmpty == false) ? server : nil
        return (cleanedServer, title)
    }
    
    private static func httpPage(ip: String, port: Int, timeout: TimeInterval, tls: Bool = false) -> HTTPPage? {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        defer { Darwin.close(sock) }
        
        guard connectWithTimeout(sock: sock, ip: ip, port: port, timeout: timeout) else { return nil }
        
        let request = "GET / HTTP/1.0\r\nHost: \(ip)\r\nConnection: close\r\n\r\n"
        _ = request.withCString { send(sock, $0, strlen($0), 0) }
        
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 512)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let n = recv(sock, &buf, buf.count, 0)
            if n <= 0 { break }
            data.append(buf, count: n)
            if data.count > 4096 { break }
        }
        
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        
        let fields = fields(fromHTTPResponse: text)
        if fields.server == nil, fields.title == nil {
            return tls ? HTTPPage(title: "HTTPS") : nil
        }
        return HTTPPage(server: fields.server, title: fields.title)
    }
    
    private static func connectWithTimeout(sock: Int32, ip: String, port: Int, timeout: TimeInterval) -> Bool {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return false }
        
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
        
        let result = withUnsafePointer(to: addr) { ptr in
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
        guard getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &len) == 0, error == 0 else { return false }
        return true
    }
}
