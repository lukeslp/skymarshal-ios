import Foundation

/// Persists a minimal bulk-delete breadcrumb so the UI can warn after a
/// mid-batch process death. **Never transmitted** — same storage posture as
/// other on-device prefs (`UserDefaults`).
@available(iOS 17, *)
public enum DeleteBatchRecovery: Sendable {
    private static let key = "sm.pendingDeleteBatch"

    public struct Payload: Codable, Equatable {
        public var ownerKey: String
        public var itemIDs: [String]
        public var startedAt: Date

        public init(ownerKey: String, itemIDs: [String], startedAt: Date = Date()) {
            self.ownerKey = ownerKey
            self.itemIDs = itemIDs
            self.startedAt = startedAt
        }
    }

    public static func store(ownerKey: String, itemIDs: [String]) {
        let payload = Payload(ownerKey: ownerKey, itemIDs: itemIDs)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    public static func current() -> Payload? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}
