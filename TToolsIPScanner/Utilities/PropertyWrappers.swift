import Foundation

/// Type-safe Property Wrapper für UserDefaults mit Codable-Support.
///
/// Verwendung:
/// ```swift
/// @UserDefault(key: "myKey", defaultValue: 0)
/// var count: Int
/// ```
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    let storage: UserDefaults
    
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }
    
    var wrappedValue: Value {
        get {
            // Spezialbehandlung für verschiedene Typen
            if let value = storage.object(forKey: key) as? Value {
                return value
            }
            return defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                storage.removeObject(forKey: key)
            } else {
                storage.set(newValue, forKey: key)
            }
        }
    }
}

/// Property Wrapper für Codable-Typen in UserDefaults.
///
/// Verwendung:
/// ```swift
/// @CodableUserDefault(key: "devices", defaultValue: [])
/// var devices: [DeviceInfo]
/// ```
@propertyWrapper
struct CodableUserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    let storage: UserDefaults
    
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }
    
    var wrappedValue: Value {
        get {
            guard let data = storage.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                storage.set(encoded, forKey: key)
            }
        }
    }
}

/// Property Wrapper für RawRepresentable-Typen (Enums) in UserDefaults.
///
/// Verwendung:
/// ```swift
/// @EnumUserDefault(key: "sortOption", defaultValue: .ip)
/// var sortOption: SortOption
/// ```
@propertyWrapper
struct EnumUserDefault<Value: RawRepresentable> where Value.RawValue == String {
    let key: String
    let defaultValue: Value
    let storage: UserDefaults
    
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }
    
    var wrappedValue: Value {
        get {
            guard let rawValue = storage.string(forKey: key),
                  let value = Value(rawValue: rawValue) else {
                return defaultValue
            }
            return value
        }
        set {
            storage.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: - Helper Protocol

/// Hilfprotokoll zur Erkennung von Optional-Typen.
private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    var isNil: Bool { self == nil }
}
