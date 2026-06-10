import BackgroundTasks
import Foundation
import SwiftData
import SkymarshalCore

/// Registers `BGAppRefreshTask` / `BGProcessingTask` handlers and performs
/// bounded local work (graph snapshot refresh from SwiftData only — no network).
@available(iOS 17, *)
enum BackgroundTaskCoordinator {
    static let refreshIdentifier = "blue.skymarshal.ios.refresh"
    static let processingIdentifier = "blue.skymarshal.ios.processing"

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
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Light `BGAppRefreshTask` — same bounded graph sync cap as processing.
    static func scheduleAppRefreshPass(earliestBeginDate: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = earliestBeginDate ?? Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        run(task)
    }

    private static func handleProcessing(_ task: BGProcessingTask) {
        run(task)
    }

    private static func run(_ task: BGTask) {
        let completion = BackgroundTaskCompletion { success in
            task.setTaskCompleted(success: success)
        }
        let work = Task { @MainActor in
            let success = runBoundedGraphSync()
            completion.finish(success: success)
        }
        task.expirationHandler = {
            work.cancel()
            completion.finish(success: false)
        }
    }

    @MainActor
    private static func runBoundedGraphSync() -> Bool {
        guard !Task.isCancelled,
              let container = try? SkymarshalSchema.makeContainer() else { return false }
        let owners = (try? distinctContentOwners(container: container)) ?? []
        var didRefreshAny = false
        for owner in owners.prefix(4) {
            guard !Task.isCancelled else { return false }
            do {
                try GraphSnapshotWriter.refreshPersistedSummariesFromCache(
                    container: container,
                    ownerHandle: owner
                )
                didRefreshAny = true
            } catch {
                continue
            }
        }
        guard !Task.isCancelled else { return false }
        if didRefreshAny {
            UserDefaults.standard.set(true, forKey: BackgroundGraphRefreshNotice.pendingUserDefaultsKey)
        }
        return true
    }

    private static func distinctContentOwners(container: ModelContainer) throws -> [String] {
        let ctx = ModelContext(container)
        let descriptor = FetchDescriptor<ContentItemRecord>()
        let rows = try ctx.fetch(descriptor)
        return Array(Set(rows.map(\.ownerHandle))).sorted()
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
