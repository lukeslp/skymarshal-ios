import SwiftUI
import SwiftData
import SkymarshalCore
import WidgetKit

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
    private(set) var currentDid: String?

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

    /// Latest persisted graph snapshot JSON keyed by ``GraphSnapshotKind/rawValue``.
    private(set) var graphSnapshotSummaries: [String: String] = [:]

    // ----- Shared -----
    var isLoading: Bool = false
    var isScanning: Bool = false
    var errorMessage: String?
    /// Set when a multi-item delete may have been interrupted before completion.
    var deleteInterruptionNotice: String?
    /// True when the last archive load hit the per-endpoint page cap with
    /// more pages remaining — the visible archive is the most recent
    /// ~20,000 items per category, not everything. Honest-UX gate for
    /// "delete everything" expectations.
    private(set) var archiveTruncated: Bool = false
    /// Set when the session refresh path can't recover the user's tokens
    /// and the UI has been flipped back to LoginView. Distinct from
    /// ``errorMessage`` so a stale "ExpiredToken" toast from an in-flight
    /// scan doesn't smother the actionable "please sign in again" copy.
    var sessionExpiredNotice: String?

    private var loadTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private let container: ModelContainer?
    private let reviewPromptPolicy: ReviewPromptPolicy
    /// Changes when a positive completion makes an App Store review request eligible.
    private(set) var reviewRequestToken = 0

    init(
        client: ATProtoClient,
        content: ContentService,
        followers: FollowerService,
        interactions: InteractionService,
        profileGraph: ProfileService,
        container: ModelContainer? = nil,
        reviewPromptPolicy: ReviewPromptPolicy = ReviewPromptPolicy()
    ) {
        self.client = client
        self.content = content
        self.followers = followers
        self.interactions = interactions
        self.profileGraph = profileGraph
        self.container = container
        self.reviewPromptPolicy = reviewPromptPolicy
        self.reviewPromptPolicy.noteAppOpened()
        observeSessionInvalidation()
    }

    /// Subscribe to ``Notification.Name.skymarshalSessionInvalidated`` —
    /// posted by ``ATProtoClient`` when the refresh-and-retry path runs
    /// out of road (refresh JWT expired/revoked, account locked, PDS
    /// rejection). Flips the app to a signed-out state with an actionable
    /// banner instead of letting bare `ATProtoError` toasts pile up on
    /// every in-flight request.
    ///
    /// No deinit cleanup: `AppModel.liveDefault()` is held in `@State`
    /// on the root `WindowGroup`, lives for the whole app, and the
    /// observer closure captures `[weak self]` so there's no retain
    /// cycle even if the @State did somehow tear down. Avoiding the
    /// deinit also dodges the MainActor-isolated-property-in-deinit
    /// compile error that Swift 5.9 raises on this `@MainActor` class.
    private func observeSessionInvalidation() {
        NotificationCenter.default.addObserver(
            forName: .skymarshalSessionInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleSessionInvalidatedFromBackground()
            }
        }
    }

    private func handleSessionInvalidatedFromBackground() {
        cancelLoad()
        cancelScan()
        Task {
            await content.logout()
        }
        isAuthenticated = false
        currentHandle = nil
        currentDid = nil
        loadProgress = nil
        scanProgress = nil
        // Clear in-memory snapshots so RootView's gating drops the
        // user back to LoginView. SwiftData cache stays intact — the
        // next successful sign-in re-hydrates from disk in milliseconds.
        // Without this, the TabView would stick around with cached data
        // while every authenticated tap silently 401s — the exact
        // failure mode the user reported.
        items = []
        summary = [:]
        accounts = []
        scanSummary = ScanSummary()
        hydratedFromCache = false
        hydratedOwnerHandle = nil
        sessionExpiredNotice =
            "Your Bluesky session expired. Please sign in again with your app password to keep going."
        // Clear the generic errorMessage so a stale ExpiredToken
        // toast doesn't double up with the more useful banner copy.
        errorMessage = nil
    }

    /// Attempt to restore a previously-persisted session from the
    /// Keychain. Called from ``RootView``'s cold-start `.task`. On
    /// success the UI shows the cached data and continues authenticated
    /// flows; on failure (no stored session or refresh JWT also
    /// expired) the user lands on the LoginView with no surprise toast.
    func tryRestoreSession() async {
        await ColdLaunchSignposts.runAsyncInterval("session_restore") {
            let restored = await content.tryRestoreSession()
            guard restored else { return }
            isAuthenticated = await content.isAuthenticated
            currentHandle = await content.currentHandle
            currentDid = await content.currentDID
            sessionExpiredNotice = nil
        }
    }

    /// One-shot dismissal for the session-expired banner. Tapping the
    /// "Sign in" affordance also clears this so the LoginView surface
    /// stays focused on the form.
    func dismissSessionExpiredNotice() {
        sessionExpiredNotice = nil
    }

    static func liveDefault() -> AppModel {
        ColdLaunchSignposts.runSyncInterval("live_default_total") {
            // Disk container first; fall back to in-memory; preconditionFailure
            // only if even in-memory schema fails to instantiate.
            let container: ModelContainer = ColdLaunchSignposts.runSyncInterval("model_container_open") {
                if let onDisk = try? SkymarshalSchema.makeContainer() { return onDisk }
                do { return try SkymarshalSchema.makeContainer(inMemory: true) }
                catch {
                    preconditionFailure(
                        "SwiftData container failed to initialize even in memory — schema is malformed. \(error)"
                    )
                }
            }
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
    }

    // MARK: - Auth

    func login(handle: String, password: String) async {
        errorMessage = nil
        sessionExpiredNotice = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await content.login(handle: handle, password: password)
            isAuthenticated = await content.isAuthenticated
            currentHandle = await content.currentHandle
            currentDid = await content.currentDID
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
                startMostRecentContentRefresh()
            } else if items.isEmpty {
                startMostRecentContentRefresh()
            }
            evaluateDeleteInterruptionRecovery()
        } catch {
            // Wrong-password-kind hint: a login failure with something
            // that isn't shaped like an app password (xxxx-xxxx-xxxx-xxxx)
            // is almost always the main account password. Say so before
            // the opaque server error.
            if AppPasswordFormat.looksLikeAppPassword(password) {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "That doesn't look like an app password — check Settings → App Passwords at bsky.app. "
                    + error.localizedDescription
            }
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
        await ColdLaunchSignposts.runAsyncInterval("hydrate_from_cache") {
            let context = ModelContext(container)

            // Predicate-scoped reads — see `CacheHydration.swift`.
            if let lastOwner = CacheHydration.latestOwnerHandle(from: context) {
                let accountRows = CacheHydration.analyzedAccountRecords(
                    for: lastOwner,
                    context: context
                )
                if !accountRows.isEmpty {
                    let restored = accountRows.map { $0.toAnalyzedAccount() }
                    self.accounts = restored
                    self.scanSummary = BluescreenAnalyzer.summarize(restored)
                    self.lastFollowerScannedAt = accountRows.map(\.scannedAt).max()
                    self.hydratedOwnerHandle = lastOwner
                    await followers.setLoaded(restored)
                }

                let contentRows = CacheHydration.contentRecords(
                    for: lastOwner,
                    context: context
                )
                if !contentRows.isEmpty {
                    let restored = contentRows.map { $0.toContentItem() }
                    self.items = restored
                    self.summary = Self.computeContentSummary(restored)
                    self.lastContentScannedAt = contentRows.map(\.scannedAt).max()
                    self.currentHandle = self.currentHandle ?? lastOwner
                    self.hydratedOwnerHandle = lastOwner
                    await content.setLoadedContent(restored)
                }
            }

            if !accounts.isEmpty || !items.isEmpty {
                hydratedFromCache = true
            }
            evaluateDeleteInterruptionRecovery()
        }
    }

    /// UI-testing only: forces one in-memory row so TabView + Insights can load without auth or network.
    func seedUITestMinimalContentIfNeeded() async {
        guard ProcessInfo.processInfo.arguments.contains("-uitestStubMinimalContent") else { return }
        let stub = ContentItem(
            uri: "at://did:plc:uitestfixture/app.bsky.feed.post/uitestrkeyaaa",
            cid: "uitestcid",
            deletionURI: "at://did:plc:uitestfixture/app.bsky.feed.post/uitestrkeyaaa",
            contentType: .posts,
            text: "UI test placeholder",
            createdAt: Date()
        )
        items = [stub]
        summary = Self.computeContentSummary([stub])
        await content.setLoadedContent([stub])

        // One analyzed account so Scope / viz surfaces have non-empty completeness
        // (XCUITest `test_AX5_scopeTab_completenessPill_readsAsExpected`).
        let createdAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-365 * 86_400))
        let stubProfile = BskyProfile(
            did: "did:plc:uitestfixturefollow",
            handle: "uitestfollow.bsky.social",
            displayName: "UI Test Follow",
            followersCount: 120,
            followsCount: 200,
            postsCount: 50,
            createdAt: createdAt
        )
        let stubAccount = BluescreenAnalyzer.analyze(profile: stubProfile)
        accounts = [stubAccount]
        scanSummary = BluescreenAnalyzer.summarize([stubAccount])
        await followers.setLoaded([stubAccount])
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
        currentDid = nil
        hydratedOwnerHandle = nil
        items = []; summary = [:]; loadProgress = nil
        accounts = []; scanSummary = ScanSummary(); scanProgress = nil
        deleteInterruptionNotice = nil
        sessionExpiredNotice = nil
        DeleteBatchRecovery.clear()
    }

    // MARK: - Content tab

    func startLoad(forceRefresh: Bool) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoad(forceRefresh: forceRefresh)
        }
    }

    func startMostRecentContentRefresh() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshMostRecentContent()
        }
    }

    func cancelLoad() { loadTask?.cancel() }

    func refreshMostRecentContent() async {
        guard isAuthenticated else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let svc = content
            _ = try await svc.refreshMostRecentContent { [weak self] progress in
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
            self.archiveTruncated = await svc.lastLoadTruncated
            writeWidgetSnapshot()
        } catch is CancellationError {
            self.items = await content.loadedSnapshot
            self.summary = await content.summarize()
            self.loadProgress = nil
        } catch {
            self.items = await content.loadedSnapshot
            self.summary = await content.summarize()
            errorMessage = error.localizedDescription
            self.loadProgress = nil
        }
    }

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
            self.archiveTruncated = await svc.lastLoadTruncated
            writeWidgetSnapshot()
            if !self.items.isEmpty {
                registerReviewableSuccess()
            }
        } catch is CancellationError {
            self.items = await content.loadedSnapshot
            self.summary = await content.summarize()
            self.loadProgress = nil
        } catch {
            self.items = await content.loadedSnapshot
            self.summary = await content.summarize()
            errorMessage = error.localizedDescription
            self.loadProgress = nil
        }
    }

    func search(_ request: SearchRequest) async -> [SearchResult] {
        let (results, _) = await content.search(request)
        return results
    }

    /// True while a bulk delete batch is running; drives the in-progress
    /// UI and the Stop button.
    private(set) var isDeleting: Bool = false
    /// (confirmed deletions so far, batch size) for the progress banner.
    private(set) var deleteProgress: (deleted: Int, total: Int)?
    /// Seconds of the current 429 backoff sleep, when the delete loop is
    /// paused waiting out a rate limit. Nil while deleting normally.
    /// Drives the "Pausing about Ns" line in DeleteProgressBanner.
    private(set) var deleteRateLimitWaitSeconds: Int?
    private var deleteTask: Task<(deleted: Int, errors: [String]), Never>?

    private func noteDeleteProgress(deleted: Int, total: Int) {
        deleteProgress = (deleted, total)
        // A confirmed deletion means the rate-limit pause is over.
        deleteRateLimitWaitSeconds = nil
    }

    private func noteDeleteRateLimitWait(seconds: Int) {
        // Announce only on the transition into a paused state so VoiceOver
        // hears one pause notice, not one per retry step.
        if deleteRateLimitWaitSeconds == nil {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Deleting paused for about \(seconds) seconds. Bluesky asked us to slow down."
            )
        }
        deleteRateLimitWaitSeconds = seconds
    }

    func delete(itemIDs: [String]) async -> (deleted: Int, errors: [String]) {
        errorMessage = nil
        let ownerKey = currentHandle ?? currentDid ?? ""
        if itemIDs.count >= 2, !ownerKey.isEmpty {
            DeleteBatchRecovery.store(ownerKey: ownerKey, itemIDs: itemIDs)
        }

        // A paced 1,000-item batch outlives the 30s screen autolock many
        // times over; without these two holds the process suspends and the
        // batch dies mid-flight. The idle-timer hold keeps the screen on
        // while the app is frontmost; the background task buys a grace
        // window if the user switches away anyway.
        UIApplication.shared.isIdleTimerDisabled = true
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "sm.bulkDelete") {
            self.deleteTask?.cancel()
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        isDeleting = true
        deleteProgress = (0, itemIDs.count)
        deleteRateLimitWaitSeconds = nil
        defer {
            isDeleting = false
            deleteProgress = nil
            deleteRateLimitWaitSeconds = nil
            deleteTask = nil
            UIApplication.shared.isIdleTimerDisabled = false
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }

        let total = itemIDs.count
        let task = Task { [self, content] in
            await content.delete(
                itemIDs: itemIDs,
                progress: { deleted in
                    await self.noteDeleteProgress(deleted: deleted, total: total)
                },
                onRateLimitWait: { seconds in
                    Task { @MainActor in
                        self.noteDeleteRateLimitWait(seconds: seconds)
                    }
                }
            )
        }
        deleteTask = task
        let result = await task.value

        // The breadcrumb self-trims as items succeed (ContentService calls
        // DeleteBatchRecovery.markCompleted) and self-clears when nothing
        // remains. Do NOT clear it unconditionally here: after a cancel,
        // a circuit-breaker halt, or a wall of errors, what's left in the
        // breadcrumb is exactly the set of items whose fate is unconfirmed.
        if !itemIDs.isEmpty {
            self.items = await content.loadedSnapshot
            self.summary = await content.summarize()
        }
        if result.deleted > 0 {
            registerReviewableSuccess(allowsPrompt: false)
        }
        surfaceOperationErrors(result.errors)
        return result
    }

    /// Stop button for an in-flight bulk delete. Already-deleted records
    /// stay deleted; the result surfaces how many items were not attempted.
    func cancelDelete() {
        deleteTask?.cancel()
    }

    func dismissDeleteInterruptionRecovery() {
        DeleteBatchRecovery.clear()
        deleteInterruptionNotice = nil
    }

    /// Surfaces a one-shot notice when a bulk delete breadcrumb remains on disk.
    func evaluateDeleteInterruptionRecovery() {
        guard let payload = DeleteBatchRecovery.current() else {
            deleteInterruptionNotice = nil
            return
        }
        let owner = currentHandle ?? currentDid ?? ""
        if !owner.isEmpty, payload.ownerKey != owner {
            deleteInterruptionNotice = nil
            return
        }
        deleteInterruptionNotice =
            "A bulk delete of \(payload.itemIDs.count) items may have been interrupted before Skymarshal finished. Some records may already be gone on Bluesky. Run Refresh full archive to reconcile this device."
    }

    func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        await delete(itemIDs: uris)
    }

    func preflightDelete(itemIDs: [String]) async -> DeletePreflightSummary {
        await content.preflightDelete(itemIDs: itemIDs)
    }

    /// Apply a decoded backup into the content cache (merge by URI or replace all).
    func applyBackupImport(importedItems: [ContentItem], mode: ContentService.BackupImportMode) async {
        guard let owner = currentHandle ?? currentDid else {
            errorMessage = "Sign in to apply a backup to your account cache."
            return
        }
        await content.applyBackupImport(items: importedItems, mode: mode, owner: owner)
        self.items = await content.loadedSnapshot
        self.summary = await content.summarize()
    }

    /// Materialize ``GraphSnapshotRecord`` rows from the current in-memory lists (local-only).
    func refreshGraphSnapshots() async {
        guard let container, let owner = currentHandle ?? currentDid else { return }
        let ctx = ModelContext(container)
        do {
            try GraphSnapshotWriter.syncLocalSummaries(
                context: ctx,
                ownerHandle: owner,
                items: items,
                accounts: accounts
            )
            let descriptor = FetchDescriptor<GraphSnapshotRecord>(
                predicate: #Predicate { $0.ownerHandle == owner }
            )
            let rows = try ctx.fetch(descriptor)
            var m: [String: String] = [:]
            for r in rows {
                if let s = r.summaryJSON { m[r.kindRaw] = s }
            }
            graphSnapshotSummaries = m
        } catch {
            // non-fatal — Scope tab still shows live counts
        }
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
            writeWidgetSnapshot()
            if !self.accounts.isEmpty {
                registerReviewableSuccess()
            }
            // Keep the .complete progress around briefly; UI fades it.
        } catch is CancellationError {
            self.accounts = await followers.loadedSnapshot
            self.scanSummary = await followers.summary
            self.scanProgress = nil
        } catch {
            self.accounts = await followers.loadedSnapshot
            self.scanSummary = await followers.summary
            errorMessage = error.localizedDescription
            self.scanProgress = nil
        }
    }

    func unfollow(
        dids: [String],
        dryRun: Bool = false,
        requireKnownActivity: Bool = false
    ) async -> (done: Int, errors: [String]) {
        if !dryRun { errorMessage = nil }
        let result = await followers.unfollow(
            dids: dids, dryRun: dryRun, requireKnownActivity: requireKnownActivity
        )
        if !dryRun, !dids.isEmpty {
            self.accounts = await followers.loadedSnapshot
            self.scanSummary = await followers.summary
        }
        if !dryRun, result.done > 0 {
            registerReviewableSuccess(allowsPrompt: false)
        }
        if !dryRun {
            surfaceOperationErrors(result.errors)
        }
        return result
    }

    private func registerReviewableSuccess(allowsPrompt: Bool = true) {
        if reviewPromptPolicy.registerSuccessfulAction(
            appVersion: currentAppVersion,
            allowsPrompt: allowsPrompt
        ) {
            reviewRequestToken += 1
        }
    }

    /// Re-emits persisted eligibility after a relaunch or scene activation.
    func refreshReviewRequestEligibility() {
        if reviewPromptPolicy.isEligible(appVersion: currentAppVersion) {
            reviewRequestToken += 1
        }
    }

    /// Consume eligibility only when the active UI calls StoreKit.
    func recordReviewRequestAttempt() {
        reviewPromptPolicy.recordRequestAttempt(appVersion: currentAppVersion)
    }

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private func surfaceOperationErrors(_ errors: [String]) {
        guard let first = errors.first else { return }
        let remaining = errors.count - 1
        errorMessage = remaining == 0
            ? first
            : "\(first)\n\(remaining) more issue\(remaining == 1 ? "" : "s") occurred."
    }

    /// Opt-in "Deep analyze": fold the engaged-audience signal into the
    /// scanned follows. Reads the user's recent post URIs from cached
    /// content and runs ``FollowerService/enrichEngagement(userPostURIs:)``
    /// — likers/reposters of those posts become the engaged set, which
    /// stamps `interactedRecently` per follow. Fail-safe: a throttled
    /// audience read leaves engagement signals untouched and marks the
    /// affected accounts `.unknown`.
    func deepAnalyzeEngagement(
        progress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async {
        let postURIs = items
            .filter { $0.contentType == .posts || $0.contentType == .replies }
            .map(\.uri)
        await followers.enrichEngagement(userPostURIs: postURIs, progress: progress)
        self.accounts = await followers.loadedSnapshot
        self.scanSummary = await followers.summary
        writeWidgetSnapshot()
    }

    /// Lazily compute the per-account ghost verdict + reciprocity for a
    /// single account when its detail view opens. One cheap
    /// user-initiated read (≤ 2 PDS pages); the verdict is stamped and
    /// persisted so re-opening is instant. Pulls the refreshed snapshot
    /// through so the row badge + detail chip rebuild. Returns the
    /// stamped account for the caller to render immediately.
    @discardableResult
    func ghostReciprocity(forDID did: String) async -> AnalyzedAccount? {
        let stamped = await followers.computeGhostReciprocity(
            forDID: did,
            userItems: items
        )
        self.accounts = await followers.loadedSnapshot
        return stamped
    }

    /// The user's own outbound engaged-DID set, used by the detail view
    /// to render the reciprocity line ("you've engaged them M×" vs not).
    /// Pure, derived from cached content — no network.
    var userOutboundEngagedDIDs: Set<String> {
        EngagementEngine.outboundEngagedDIDs(from: items)
    }

    /// Opt-in capped batch (BluescreenView menu): verify ghosts over the
    /// already-flagged disengaged candidates only, capped per run. Never
    /// the full follow set. Refreshes `accounts` afterward.
    @discardableResult
    func verifyFlaggedGhosts(
        cap: Int = 100,
        progress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async -> Int {
        let count = await followers.verifyFlaggedGhosts(
            userItems: items, cap: cap, progress: progress
        )
        self.accounts = await followers.loadedSnapshot
        return count
    }

    /// Toggle the user-whitelist override on a scanned account. Pulls
    /// the new snapshot through after the FollowerService write so the
    /// AccountRow / AccountDetailView rebuild with the updated state.
    func setWhitelist(did: String, to newValue: Bool) async {
        guard let owner = currentHandle else { return }
        await followers.setWhitelist(did: did, to: newValue, owner: owner)
        self.accounts = await followers.loadedSnapshot
    }

    // MARK: - Home-screen widgets

    /// Build a ``WidgetSnapshot`` from the current scan + content and
    /// write it to the shared App Group container, then ask WidgetKit to
    /// refresh. Network-free: reads only in-memory engine results. Called
    /// after a follower scan or content load completes. A missing App
    /// Group (e.g. a build without the entitlement) is a no-op.
    func writeWidgetSnapshot() {
        let previousHistory = WidgetSnapshotStore.read()?.followerHistory ?? []
        let snapshot = WidgetSnapshotBuilder.build(
            accounts: accounts,
            summary: scanSummary,
            items: items,
            followerCount: nil,
            previousHistory: previousHistory
        )
        if WidgetSnapshotStore.write(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        let currentAccounts = accounts
        Task { [client] in
            let recommendations = await EngagementRecommendationService.fetch(
                client: client, accounts: currentAccounts
            )
            guard !recommendations.isEmpty else { return }
            let enriched = WidgetSnapshot(
                hygieneSummary: snapshot.hygieneSummary,
                peopleToEngage: snapshot.peopleToEngage,
                recommendedPosts: recommendations,
                topPost: snapshot.topPost,
                followerHistory: snapshot.followerHistory,
                generatedAt: Date()
            )
            if WidgetSnapshotStore.write(enriched) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
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
