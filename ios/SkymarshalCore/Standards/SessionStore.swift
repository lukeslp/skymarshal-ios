import Foundation
import Security

/// Keychain-backed persistence for the active ``Session`` (DID, handle,
/// accessJwt, refreshJwt).
///
/// Skymarshal never persists the user's app password — only the rotating
/// session tokens issued by `com.atproto.server.createSession` /
/// `com.atproto.server.refreshSession`. Storing them in the keychain
/// (not `UserDefaults`) keeps them off any unencrypted backup and lets
/// them clear when the user reinstalls.
///
/// Access policy: ``kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly``.
/// Tokens stay on this device only — no iCloud Keychain sync (a session
/// bound to one device's app install shouldn't roam), and they're
/// reachable after first unlock so background refresh tasks can read
/// them without the user unlocking the device first.
///
/// Concurrency: the underlying `SecItem*` C API is thread-safe; the
/// static surface here is safe to call from any actor.
public enum SessionStore {

    /// Keychain service identifier — namespaced so the next-tab Skymarshal
    /// extension (Share/Action, hypothetical) could share via App Group
    /// access groups later without a migration. For now, single-target.
    public static let service: String = "blue.skymarshal.ios.session"

    /// Single-session app — only one row, keyed by this account.
    public static let account: String = "atproto-session"

    /// Persist or replace the stored session. Best-effort: keychain
    /// failures are logged-but-swallowed so a transient persistence
    /// error never blocks the in-memory auth flow. The next refresh
    /// will retry the write.
    @discardableResult
    public static func save(_ session: Session) -> Bool {
        guard let payload = try? JSONEncoder().encode(session) else {
            return false
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: payload,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = payload
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        return false
    }

    /// Read the persisted session, if any. Returns nil for "no session
    /// stored" AND "stored payload no longer decodes" (a schema change
    /// to ``Session`` should be treated the same as no session — the
    /// user re-authenticates and the new shape is written).
    public static func load() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    /// Remove the persisted session. Called from explicit logout and
    /// from refresh-failure paths so a dead session doesn't haunt the
    /// next cold start.
    @discardableResult
    public static func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
