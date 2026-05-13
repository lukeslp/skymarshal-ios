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
    private(set) var interactions: InteractionService
    /// Paginated profile graph reads (followers/following lists).
    private(set) var profileGraph: ProfileService
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

    // ----- Cold-start hydration markers -----
    /// Most-recent scannedAt from the cached content items, set during
    /// hydrateFromCache. Drives the "Last scanned 3 hours ago" banner
    /// in ContentListView.
    private(set) var lastContentScannedAt: Date?
    /// Same, for the followers tab.
    private(set) var lastFollowerScannedAt: Date?
    private(set) var hydratedOwnerHandle: String?
    /// True when the most-recent hydration source was the disk cache,
    /// not a live scan. Used to gate the "Sign in to refresh" hint
    /// when we're showing stale data without an authenticated client.
    private(set) var hydratedFromCache: Bool = false

    // ----- Shared -----
    var isLoading: Bool = false
    var isScanning: Bool = false
    var errorMessage: String?

    private var loadTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private let container: ModelContainer?

    init(
        client: ATProtoClient,
        content: ContentService,
        followers: FollowerService,
        interactions: InteractionService,
        profileGraph: ProfileService,
        container: ModelContainer? = nil
    ) {
        self.client = client
        self.content = content
        self.followers = followers
        self.interactions = interactions
        self.profileGraph = profileGraph
        self.container = container
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
            followers: FollowerService(client: client, container: container),
            interactions: InteractionService(client: client),
            profileGraph: ProfileService(client: client),
            container: container
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
            // If hydration already populated a snapshot for this same handle,
            // skip the immediate refetch. If the hydrated owner differs, do
            // a live load so another account's cache is never shown as yours.
            if hydratedFromCacheOwnerMismatch {
                items = []
                summary = [:]
                accounts = []
                scanSummary = ScanSummary()
                lastContentScannedAt = nil
                lastFollowerScannedAt = nil
                hydratedFromCache = false
                hydratedOwnerHandle = nil
                await followers.clear()
                startLoad(forceRefresh: true)
            } else if items.isEmpty {
                startLoad(forceRefresh: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var hydratedFromCacheOwnerMismatch: Bool {
        guard hydratedFromCache,
              let currentHandle,
              lastContentScannedAt != nil || lastFollowerScannedAt != nil else {
            return false
        }
        return hydratedOwnerHandle != currentHandle
    }

    /// Read the SwiftData cache on cold start and pre-populate `items`
    /// + `accounts`. Idempotent — safe to call from RootView.task on
    /// every launch. Does nothing if there's nothing in the cache.
    /// Surfaces a "Last scanned …" timestamp per tab.
    ///
    /// Per-handle isolation: hydrates the most-recently-scanned
    /// owner's data. If the user later signs in as a different handle,
    /// the live scan replaces it; if they sign in as the same handle,
    /// the cache is the truth until they Refresh.
    func hydrateFromCache() async {
        guard let container, !hydratedFromCache else { return }
        let context = ModelContext(container)

        // Followers — pick the owner with the most recent scannedAt
        let analyzedDescriptor = FetchDescriptor<AnalyzedAccountRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        if let allAccounts = try? context.fetch(analyzedDescriptor),
           let lastOwner = allAccounts.first?.ownerHandle {
            let mine = allAccounts.filter { $0.ownerHandle == lastOwner }
            if !mine.isEmpty {
                let restored = mine.map { $0.toAnalyzedAccount() }
                self.accounts = restored
                self.scanSummary = BluescreenAnalyzer.summarize(restored)
                self.lastFollowerScannedAt = mine.map(\.scannedAt).max()
                self.hydratedOwnerHandle = lastOwner
                await followers.setLoaded(restored)
            }
        }

        // Content — same pattern, sorted by scannedAt
        let contentDescriptor = FetchDescriptor<ContentItemRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        if let allItems = try? context.fetch(contentDescriptor),
           let lastOwner = allItems.first?.ownerHandle {
            let mine = allItems.filter { $0.ownerHandle == lastOwner }
            if !mine.isEmpty {
                let restored = mine.map { $0.toContentItem() }
                self.items = restored
                self.summary = Self.computeContentSummary(restored)
                self.lastContentScannedAt = mine.map(\.scannedAt).max()
                self.currentHandle = self.currentHandle ?? lastOwner
                self.hydratedOwnerHandle = lastOwner
                await content.setLoadedContent(restored)
            }
        }

        if !accounts.isEmpty || !items.isEmpty {
            hydratedFromCache = true
        }
    }

    /// Recompute the content-type counts from a list of items.
    /// Mirrors ContentService.summarize but works on a pure-Swift
    /// snapshot without an actor hop — needed during hydrateFromCache
    /// where we have the items in hand already.
    private static func computeContentSummary(_ items: [ContentItem]) -> [ContentType: Int] {
        var counts: [ContentType: Int] = [:]
        for item in items {
            counts[item.contentType, default: 0] += 1
        }
        return counts
    }

    func logout() async {
        cancelLoad()
        cancelScan()
        await content.logout()
        isAuthenticated = false
        currentHandle = nil
        hydratedOwnerHandle = nil
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
            self.lastContentScannedAt = Date()
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

    func delete(itemIDs: [String]) async -> (deleted: Int, errors: [String]) {
        let result = await content.delete(itemIDs: itemIDs)
        if !itemIDs.isEmpty {
            self.items.removeAll { itemIDs.contains($0.id) }
            self.summary = await content.summarize()
        }
        return result
    }

    func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        await delete(itemIDs: uris)
    }

    func preflightDelete(itemIDs: [String]) async -> DeletePreflightSummary {
        await content.preflightDelete(itemIDs: itemIDs)
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
            self.lastFollowerScannedAt = Date()
            // Keep the .complete progress around briefly; UI fades it.
        } catch is CancellationError {
            // partial state — user knows they stopped
        } catch {
            errorMessage = error.localizedDescription
            self.scanProgress = nil
        }
    }

    func unfollow(dids: [String], dryRun: Bool = false) async -> (done: Int, errors: [String]) {
        let result = await followers.unfollow(dids: dids, dryRun: dryRun)
        if !dryRun, !dids.isEmpty {
            self.accounts.removeAll { dids.contains($0.did) }
            self.scanSummary = await followers.summary
        }
        return result
    }

    /// Toggle the user-whitelist override on a scanned account. Pulls
    /// the new snapshot through after the FollowerService write so the
    /// AccountRow / AccountDetailView rebuild with the updated state.
    func setWhitelist(did: String, to newValue: Bool) async {
        guard let owner = currentHandle else { return }
        await followers.setWhitelist(did: did, to: newValue, owner: owner)
        self.accounts = await followers.loadedSnapshot
    }

    // MARK: - Saved search presets

    func fetchSavedSearchPresets() throws -> [SavedSearchPresetRecord] {
        guard let container, let owner = currentHandle else { return [] }
        let context = ModelContext(container)
        let ownerHandle = owner
        let descriptor = FetchDescriptor<SavedSearchPresetRecord>(
            predicate: #Predicate { $0.ownerHandle == ownerHandle },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func saveSearchPreset(name: String, request: SearchRequest, sort: ContentSortOrder) throws {
        guard let container, let owner = currentHandle else { return }
        let context = ModelContext(container)
        let data = try JSONEncoder().encode(request)
        guard let json = String(data: data, encoding: .utf8) else { return }
        context.insert(
            SavedSearchPresetRecord(
                ownerHandle: owner,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                searchRequestJSON: json,
                sortOrderRaw: sort.rawValue
            )
        )
        try context.save()
    }

    func deleteSavedSearchPreset(id: UUID) throws {
        guard let container else { return }
        let context = ModelContext(container)
        let tid = id
        let descriptor = FetchDescriptor<SavedSearchPresetRecord>(
            predicate: #Predicate { $0.id == tid }
        )
        if let rec = try context.fetch(descriptor).first {
            context.delete(rec)
            try context.save()
        }
    }

    // MARK: - Profile explorer

    func loadExplorerFollowers(actor: String) async throws -> [BskyProfile] {
        try await profileGraph.loadFollowers(actor: actor)
    }

    func loadExplorerFollows(actor: String) async throws -> [BskyProfile] {
        try await profileGraph.loadFollows(actor: actor)
    }

    func fetchPublicProfile(actor: String) async throws -> BskyProfile {
        try await profileGraph.fetchProfile(actor: actor)
    }
}
