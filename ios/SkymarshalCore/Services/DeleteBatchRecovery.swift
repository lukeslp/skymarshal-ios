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

    /// Remove confirmed-deleted IDs from the breadcrumb so a mid-batch
    /// crash reports only what is actually still pending. Auto-clears
    /// when nothing remains; no-ops when no breadcrumb exists (small
    /// batches never store one). Callers batch this (~every 25
    /// successes) — the payload is rewritten whole on each call.
    public static func markCompleted(_ completedIDs: some Collection<String>) {
        guard var payload = current(), !completedIDs.isEmpty else { return }
        let done = Set(completedIDs)
        payload.itemIDs.removeAll { done.contains($0) }
        if payload.itemIDs.isEmpty {
            clear()
        } else if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    public static func current() -> Payload? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}
