import Foundation

enum IPAddressValidator {
    /// Validates a dotted-quad IPv4 address (each octet 0–255).
    static func isValidIPv4(_ ipAddress: String) -> Bool {
        let components = ipAddress.components(separatedBy: ".")
        guard components.count == 4 else { return false }
        
        return components.allSatisfy { component in
            guard !component.isEmpty,
                  component.allSatisfy(\.isNumber),
                  let number = Int(component) else {
                return false
            }
            // Reject leading zeros like "01" except for "0"
            if component.count > 1 && component.hasPrefix("0") { return false }
            return number >= 0 && number <= 255
        }
    }
}
