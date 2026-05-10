import SwiftUI
import SwiftData
import SkymarshalCore

/// View-model glue between SwiftUI views and the ``ContentService`` actor.
/// Holds the auth state, content snapshot, and load progress the UI binds
/// to. `@MainActor` so view code can read its observable properties
/// without hopping.
@available(iOS 17, *)
@MainActor
@Observable
final class AppModel {

    private(set) var service: ContentService
    private(set) var isAuthenticated: Bool = false
    private(set) var currentHandle: String?
    private(set) var items: [ContentItem] = []
    private(set) var summary: [ContentType: Int] = [:]
    private(set) var loadProgress: ContentService.LoadProgress?
    var isLoading: Bool = false
    var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    init(service: ContentService) {
        self.service = service
    }

    static func liveDefault() -> AppModel {
        let container = (try? SkymarshalSchema.makeContainer()) ?? {
            try! SkymarshalSchema.makeContainer(inMemory: true)
        }()
        return AppModel(service: ContentService(container: container))
    }

    func login(handle: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.login(handle: handle, password: password)
            isAuthenticated = await service.isAuthenticated
            currentHandle = await service.currentHandle
            startLoad(forceRefresh: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        cancelLoad()
        await service.logout()
        isAuthenticated = false
        currentHandle = nil
        items = []
        summary = [:]
        loadProgress = nil
    }

    /// Kick off a paginated load. Cancels any in-flight load first so a
    /// pull-to-refresh while a load is running can't double-fetch.
    func startLoad(forceRefresh: Bool) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoad(forceRefresh: forceRefresh)
        }
    }

    /// Stop the current load. Items already collected stay in `items`.
    func cancelLoad() {
        loadTask?.cancel()
    }

    private func runLoad(forceRefresh: Bool) async {
        errorMessage = nil
        isLoading = true
        defer {
            isLoading = false
            // Drop progress only if the load completed cleanly. On
            // cancellation, leave it visible briefly so the user can see
            // where they stopped before it fades.
        }
        do {
            let svc = service
            _ = try await svc.ensureContentLoaded(forceRefresh: forceRefresh) { [weak self] progress in
                guard let self else { return }
                let snapshot = await svc.loadedSnapshot
                let summary = await svc.summarize()
                await MainActor.run {
                    self.loadProgress = progress
                    self.items = snapshot
                    self.summary = summary
                }
            }
            // Final snapshot in case the last page didn't fire a progress callback.
            self.items = await svc.loadedSnapshot
            self.summary = await svc.summarize()
            self.loadProgress = nil
        } catch is CancellationError {
            // Keep items + summary; user knows they stopped.
        } catch {
            errorMessage = error.localizedDescription
            self.loadProgress = nil
        }
    }

    func search(_ request: SearchRequest) async -> [SearchResult] {
        let (results, _) = await service.search(request)
        return results
    }

    func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        let result = await service.delete(uris: uris)
        if !uris.isEmpty {
            self.items.removeAll { uris.contains($0.uri) }
            self.summary = await service.summarize()
        }
        return result
    }
}
