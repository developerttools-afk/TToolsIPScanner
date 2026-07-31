import Foundation

enum PortListParser {
    /// Parses a comma-separated port list into a set of valid port numbers (1...65535).
    static func parse(_ text: String) -> Set<Int> {
        Set(
            text.components(separatedBy: ",")
                .compactMap { raw -> Int? in
                    let trimmed = raw.trimmingCharacters(in: .whitespaces)
                    guard let port = Int(trimmed), port >= 1, port <= 65535 else { return nil }
                    return port
                }
        )
    }
    
    static func format(_ ports: Set<Int>) -> String {
        ports.sorted().map(String.init).joined(separator: ", ")
    }
}
