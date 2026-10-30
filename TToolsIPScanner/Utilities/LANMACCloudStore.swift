import Foundation

/// MAC addresses the Mac app already resolved, shared to iOS through iCloud Key-Value Storage.
/// The provisioning profile has no `com.apple.developer.ubiquity-kvstore-identifier`, so the
/// store is never opened. Checking that with SecTaskCreateFromSelf logs a task-port error.
enum LANMACCloudStore {
    private static let key = "lan-mac-map-v1"
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    
    struct Snapshot: Codable, Equatable {
        var prefix: String
        var updated: Date
        var hosts: [String: String]
    }
    
    static func publish(prefix: String, hosts: [String: String]) {
        guard storeIsAvailable, SettingsManager.shared.shareMACOveriCloud else { return }
        guard !prefix.isEmpty, !hosts.isEmpty else { return }
        let snapshot = Snapshot(prefix: prefix, updated: Date(), hosts: hosts)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: key)
        store.synchronize()
    }
    
    static func hosts(prefix: String) -> [String: String] {
        guard storeIsAvailable, SettingsManager.shared.shareMACOveriCloud else { return [:] }
        guard !prefix.isEmpty else { return [:] }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard let data = store.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.prefix == prefix,
              Date().timeIntervalSince(snapshot.updated) < maxAge else {
            return [:]
        }
        return snapshot.hosts
    }
    
    /// Off until the signed app actually has the iCloud Key-Value entitlement.
    private static let storeIsAvailable = false
}
