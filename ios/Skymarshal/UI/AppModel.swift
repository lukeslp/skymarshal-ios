import SwiftUI
import SwiftData
import SkymarshalCore

/// View-model glue between SwiftUI views and the actor-isolated services.
/// Holds auth state, the loaded content + summary, the loaded follower
/// scan, and progress for both load surfaces. Marked `@MainActor` so
/// view code reads its observable properties without hopping.
@available(iOS 17, *)
@MainActor
@Observable
final class AppModel {

    // ----- Services -----
    private(set) var content: ContentService
    private(set) var followers: FollowerService
    private let client: ATProtoClient

    // ----- Auth state -----
    private(set) var isAuthenticated: Bool = false
    private(set) var currentHandle: String?

    // ----- Content tab state -----
    private(set) var items: [ContentItem] = []
    private(set) var summary: [ContentType: Int] = [:]
    private(set) var loadProgress: ContentService.LoadProgress?

    // ----- Followers tab state -----
    private(set) var accounts: [AnalyzedAccount] = []
    private(set) var scanSummary: ScanSummary = ScanSummary()
    private(set) var scanProgress: ScanProgress?

    // ----- Shared -----
    var isLoading: Bool = false
    var isScanning: Bool = false
    var errorMessage: String?

    private var loadTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    init(client: ATProtoClient, content: ContentService, followers: FollowerService) {
        self.client = client
        self.content = content
        self.followers = followers
    }

    static func liveDefault() -> AppModel {
        // Disk container first; fall back to in-memory; preconditionFailure
        // only if even in-memory schema fails to instantiate.
        let container: ModelContainer = {
            if let onDisk = try? SkymarshalSchema.makeContainer() { return onDisk }
            do { return try SkymarshalSchema.makeContainer(inMemory: true) }
            catch {
                preconditionFailure(
                    "SwiftData container failed to initialize even in memory — schema is malformed. \(error)"
                )
            }
        }()
        let client = ATProtoClient()
        return AppModel(
            client: client,
            content: ContentService(client: client, container: container),
            followers: FollowerService(client: client)
        )
    }

    // MARK: - Auth

    func login(handle: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await content.login(handle: handle, password: password)
            isAuthenticated = await content.isAuthenticated
            currentHandle = await content.currentHandle
            startLoad(forceRefresh: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        cancelLoad()
        cancelScan()
        await content.logout()
        isAuthenticated = false
        currentHandle = nil
        items = []; summary = [:]; loadProgress = nil
        accounts = []; scanSummary = ScanSummary(); scanProgress = nil
    }

    // MARK: - Content tab

    func startLoad(forceRefresh: Bool) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoad(forceRefresh: forceRefresh)
        }
    }

    func cancelLoad() { loadTask?.cancel() }

    private func runLoad(forceRefresh: Bool) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let svc = content
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
            self.items = await svc.loadedSnapshot
            self.summary = await svc.summarize()
            self.loadProgress = nil
        } catch is CancellationError {
            // partial state is fine — user knows they stopped
        } catch {
            errorMessage = error.localizedDescription
            self.loadProgress = nil
        }
    }

    func search(_ request: SearchRequest) async -> [SearchResult] {
        let (results, _) = await content.search(request)
        return results
    }

    func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        let result = await content.delete(uris: uris)
        if !uris.isEmpty {
            self.items.removeAll { uris.contains($0.uri) }
            self.summary = await content.summarize()
        }
        return result
    }

    // MARK: - Followers tab

    func startScan(checkLastPost: Bool = true, inactivityDays: Int = 90) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            await self.runScan(checkLastPost: checkLastPost, inactivityDays: inactivityDays)
        }
    }

    func cancelScan() { scanTask?.cancel() }

    private func runScan(checkLastPost: Bool, inactivityDays: Int) async {
        errorMessage = nil
        isScanning = true
        defer { isScanning = false }
        do {
            let svc = followers
            _ = try await svc.scan(
                checkLastPost: checkLastPost,
                inactivityDays: inactivityDays
            ) { [weak self] progress in
                guard let self else { return }
                let snapshot = await svc.loadedSnapshot
                let summary = await svc.summary
                await MainActor.run {
                    self.scanProgress = progress
                    self.accounts = snapshot
                    self.scanSummary = summary
                }
            }
            self.accounts = await svc.loadedSnapshot
            self.scanSummary = await svc.summary
            // Keep the .complete progress around briefly; UI fades it.
        } catch is CancellationError {
            // partial state — user knows they stopped
        } catch {
            errorMessage = error.localizedDescription
            self.scanProgress = nil
        }
    }

    func unfollow(dids: [String]) async -> (done: Int, errors: [String]) {
        let result = await followers.unfollow(dids: dids)
        if !dids.isEmpty {
            self.accounts.removeAll { dids.contains($0.did) }
            self.scanSummary = await followers.summary
        }
        return result
    }
}
