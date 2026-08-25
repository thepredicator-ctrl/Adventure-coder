import Foundation

/// Stores and validates SSH host keys to prevent man-in-the-middle attacks.
public final class RemoteHostKeyStore {
    public static let shared = RemoteHostKeyStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "ssh_host_keys"

    private init() {}

    /// Validates a host key against the stored fingerprint.
    /// Returns true if:
    /// - No key is stored yet (first connection — stores the key)
    /// - The stored key matches the presented key
    /// Returns false if the keys don't match (potential MITM).
    public func validate(host: String, fingerprint: String) -> Bool {
        var keys = storedKeys
        if let existing = keys[host] {
            return existing == fingerprint
        }
        // First connection — store the key
        keys[host] = fingerprint
        save(keys)
        return true
    }

    /// Returns the stored fingerprint for a host, or nil if none.
    public func storedFingerprint(for host: String) -> String? {
        storedKeys[host]
    }

    /// Removes the stored fingerprint for a host.
    public func remove(host: String) {
        var keys = storedKeys
        keys.removeValue(forKey: host)
        save(keys)
    }

    /// Removes all stored fingerprints.
    public func clearAll() {
        defaults.removeObject(forKey: storageKey)
    }

    private var storedKeys: [String: String] {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded
        }
        return [:]
    }

    private func save(_ keys: [String: String]) {
        if let data = try? JSONEncoder().encode(keys) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
