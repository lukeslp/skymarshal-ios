import BackgroundTasks
import Foundation
import SwiftData
import SkymarshalCore

/// Registers `BGAppRefreshTask` / `BGProcessingTask` handlers and performs
/// bounded local work (graph snapshot refresh from SwiftData only — no network).
///
/// Crash history: early builds loaded every ``ContentItemRecord`` on the main
/// actor just to discover owner handles. Large archives jetsam’d under the
/// background memory budget. Owner resolution is now tiny (session / snapshot
/// rows), item fetches are capped, and work runs off the main actor.
@available(iOS 17, *)
enum BackgroundTaskCoordinator {
    static let refreshIdentifier = "blue.skymarshal.ios.refresh"
    static let processingIdentifier = "blue.skymarshal.ios.processing"

    /// Hard ceiling for content rows materialised per owner in a background pass.
    /// Heatmaps stay useful; multi-hundred-thousand archives no longer OOM.
    private static let maxItemsPerOwner = 12_000
    private static let maxOwnersPerPass = 2

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleRefresh(refreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleProcessing(processingTask)
        }
    }

    /// Schedules a low-priority processing pass (graph summaries). Safe to call from foreground.
    static func scheduleProcessingPass(earliestBeginDate: Date? = nil) {
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = earliestBeginDate ?? Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Duplicate submissions and rate limits are expected; never crash.
        }
    }

    /// Light `BGAppRefreshTask` — same bounded graph sync cap as processing.
    static func scheduleAppRefreshPass(earliestBeginDate: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = earliestBeginDate ?? Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Same as processing — ignore expected submit failures.
        }
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        run(task)
    }

    private static func handleProcessing(_ task: BGProcessingTask) {
        run(task)
    }

    private static func run(_ task: BGTask) {
        // Resubmit *before* completing the current task so the system still
        // grants execution budget long enough for the submit calls to land.
        scheduleProcessingPass()
        scheduleAppRefreshPass()

        let completion = BackgroundTaskCompletion { success in
            task.setTaskCompleted(success: success)
        }

        // Detached + utility: never pin the main actor for multi-MB SwiftData work.
        let work = Task.detached(priority: .utility) {
            let success = await runBoundedGraphSync()
            completion.finish(success: success)
        }

        task.expirationHandler = {
            work.cancel()
            completion.finish(success: false)
        }
    }

    /// Pure SwiftData work. Safe to call from a background task; creates its own
    /// container/context and never touches UI.
    private static func runBoundedGraphSync() async -> Bool {
        if Task.isCancelled { return false }

        let container: ModelContainer
        do {
            container = try SkymarshalSchema.makeContainer()
        } catch {
            return false
        }

        let owners = prioritizeOwners(resolveOwnerHandles(container: container))
        guard !owners.isEmpty else { return true }

        var didRefreshAny = false
        for owner in owners.prefix(maxOwnersPerPass) {
            if Task.isCancelled { return false }
            do {
                try GraphSnapshotWriter.refreshPersistedSummariesFromCache(
                    container: container,
                    ownerHandle: owner,
                    itemFetchLimit: maxItemsPerOwner
                )
                didRefreshAny = true
            } catch {
                // Per-owner failure must not abort the whole task or crash.
                continue
            }
        }

        if Task.isCancelled { return false }
        if didRefreshAny {
            UserDefaults.standard.set(true, forKey: BackgroundGraphRefreshNotice.pendingUserDefaultsKey)
        }
        return true
    }

    /// Prefer tiny sources of owner identity. Never scan the full content table.
    private static func resolveOwnerHandles(container: ModelContainer) -> [String] {
        var handles = Set<String>()

        if let sessionHandle = SessionStore.load()?.handle,
           !sessionHandle.isEmpty {
            handles.insert(sessionHandle.lowercased())
        }

        let context = ModelContext(container)

        // Graph snapshots are few rows (kinds × owners). Cap the fetch anyway.
        var snapshotDescriptor = FetchDescriptor<GraphSnapshotRecord>()
        snapshotDescriptor.fetchLimit = 64
        if let snapshots = try? context.fetch(snapshotDescriptor) {
            for row in snapshots where !row.ownerHandle.isEmpty {
                handles.insert(row.ownerHandle.lowercased())
            }
        }

        // One-row account fallback — never materialize the full follower cache
        // (scan can hold tens of thousands of AnalyzedAccountRecord rows).
        if handles.isEmpty {
            var accountDescriptor = FetchDescriptor<AnalyzedAccountRecord>(
                sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
            )
            accountDescriptor.fetchLimit = 1
            if let row = try? context.fetch(accountDescriptor).first,
               !row.ownerHandle.isEmpty {
                handles.insert(row.ownerHandle.lowercased())
            }
        }

        // Content-only cache (signed-out / expired session, no snapshots yet):
        // one recent content row is enough to recover the owner handle.
        if handles.isEmpty {
            var contentDescriptor = FetchDescriptor<ContentItemRecord>(
                sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
            )
            contentDescriptor.fetchLimit = 1
            if let row = try? context.fetch(contentDescriptor).first,
               !row.ownerHandle.isEmpty {
                handles.insert(row.ownerHandle.lowercased())
            }
        }

        return Array(handles)
    }

    /// Active session owner first so the maxOwnersPerPass cap never starves it
    /// behind lexicographically earlier historical owners.
    private static func prioritizeOwners(_ owners: [String]) -> [String] {
        guard let session = SessionStore.load()?.handle.lowercased(),
              !session.isEmpty else {
            return owners.sorted()
        }
        let rest = owners.filter { $0 != session }.sorted()
        if owners.contains(session) {
            return [session] + rest
        }
        return [session] + rest
    }
}

final class BackgroundTaskCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private let completion: @Sendable (Bool) -> Void

    init(completion: @escaping @Sendable (Bool) -> Void) {
        self.completion = completion
    }

    func finish(success: Bool) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()
        completion(success)
    }
}
