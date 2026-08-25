import Foundation
import Security

/// Keychain-backed secure storage for API keys and tokens.
///
/// All keys are stored in the iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
/// meaning they remain encrypted at rest and never leave the device except when sent directly
/// to the provider's API over HTTPS.
public enum KeychainService {
    public enum Key: String {
        case openRouterAPIKey = "openrouter.api_key"
        case huggingFaceToken = "huggingface.token"
        case githubToken = "github.token"
        case userAccount = "user.account"
    }

    public enum KeychainError: Error {
        case unhandled(OSStatus)
        case decodeFailed
    }

    private static let service = "com.adventurecoder.app"

    // MARK: - Save / load / delete

    @discardableResult
    public static func save(_ key: Key, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(key, data: data)
    }

    @discardableResult
    public static func saveData(_ key: Key, data: Data) -> Bool {
        // Remove existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    public static func load(_ key: Key) -> String? {
        guard let data = loadData(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func loadData(_ key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    @discardableResult
    public static func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Returns a masked display string for a key, e.g. "sk-or-v1-••••••••3f7a".
    public static func masked(_ key: Key) -> String {
        guard let value = load(key), !value.isEmpty else { return "Not set" }
        if value.count <= 8 {
            return String(repeating: "•", count: value.count)
        }
        let head = String(value.prefix(4))
        let tail = String(value.suffix(4))
        return "\(head)••••••••\(tail)"
    }

    /// Returns true if a key is currently stored.
    public static func has(_ key: Key) -> Bool {
        load(key) != nil
    }
}
