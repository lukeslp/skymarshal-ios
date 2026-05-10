import SwiftUI
import SwiftData
import SkymarshalCore

/// View-model glue between SwiftUI views and the ``ContentService`` actor.
/// Holds the auth state and content snapshot the UI binds to. Marked
/// `@MainActor` so view code can read its published properties directly.
@available(iOS 17, *)
@MainActor
@Observable
final class AppModel {

    private(set) var service: ContentService
    private(set) var isAuthenticated: Bool = false
    private(set) var currentHandle: String?
    private(set) var items: [ContentItem] = []
    private(set) var summary: [ContentType: Int] = [:]
    var isLoading: Bool = false
    var errorMessage: String?

    init(service: ContentService) {
        self.service = service
    }

    static func liveDefault() -> AppModel {
        let container = (try? SkymarshalSchema.makeContainer()) ?? {
            // Last-resort in-memory fallback if disk container fails to
            // open (e.g. on a corrupt sandbox). The user can still use
            // the app without persistence — re-login required next launch.
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
            await loadContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        await service.logout()
        isAuthenticated = false
        currentHandle = nil
        items = []
        summary = [:]
    }

    func loadContent(forceRefresh: Bool = false) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await service.ensureContentLoaded(forceRefresh: forceRefresh)
            self.items = loaded
            self.summary = await service.summarize()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(_ request: SearchRequest) async -> [SearchResult] {
        let (results, _) = await service.search(request)
        return results
    }

    func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        let result = await service.delete(uris: uris)
        // Re-pull the snapshot — service mutated its internal cache.
        if !uris.isEmpty {
            self.items.removeAll { uris.contains($0.uri) }
            self.summary = await service.summarize()
        }
        return result
    }
}
