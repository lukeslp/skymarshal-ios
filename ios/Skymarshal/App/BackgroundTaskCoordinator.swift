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
            handleRefresh(task as! BGAppRefreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { task in
            handleProcessing(task as! BGProcessingTask)
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
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.sync {
            runBoundedGraphSync()
        }
        task.setTaskCompleted(success: true)
    }

    private static func handleProcessing(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.sync {
            runBoundedGraphSync()
        }
        task.setTaskCompleted(success: true)
    }

    @MainActor
    private static func runBoundedGraphSync() {
        guard let container = try? SkymarshalSchema.makeContainer() else { return }
        let owners = (try? distinctContentOwners(container: container)) ?? []
        var didRefreshAny = false
        for owner in owners.prefix(4) {
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
        if didRefreshAny {
            UserDefaults.standard.set(true, forKey: BackgroundGraphRefreshNotice.pendingUserDefaultsKey)
        }
    }

    private static func distinctContentOwners(container: ModelContainer) throws -> [String] {
        let ctx = ModelContext(container)
        let descriptor = FetchDescriptor<ContentItemRecord>()
        let rows = try ctx.fetch(descriptor)
        return Array(Set(rows.map(\.ownerHandle))).sorted()
    }
}
