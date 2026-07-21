import Foundation
import SwiftData
import os

/// The orchestration boundary every UI layer should sit on top of.
///
/// Mirrors `reference/python/services/content_service.py` — five public methods
/// plus one read-only property. UI and `AppModel` call **only** this actor for
/// orchestration (no parallel “shadow” load/delete paths around it).
@available(iOS 17, *)
public actor ContentService {

    private static let log = Logger(subsystem: "blue.skymarshal.ios", category: "ContentService")

    private let client: ATProtoClient
    private let container: ModelContainer
    private var loadedContent: [ContentItem] = []
    private var loadedHandle: String?

    /// SwiftData saves on the cache paths are best-effort (a failed cache
    /// write must not fail the user-visible operation), but never silent:
    /// a recurring constraint violation here is how duplicate-key rows
    /// sneak into the store.
    private func saveOrLog(_ context: ModelContext, _ operation: StaticString) {
        do {
            try context.save()
        } catch {
            Self.log.error("\(operation, privacy: .public) save failed: \(error, privacy: .public)")
        }
    }

    public init(
        client: ATProtoClient = ATProtoClient(),
        container: ModelContainer
    ) {
        self.client = client
        self.container = container
    }

    /// Convenience initializer that builds an in-memory container — useful
    /// for previews and tests.
    public static func inMemory() throws -> ContentService {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        return ContentService(container: container)
    }

    // MARK: - Auth

    public func login(handle: String, password: String) async throws -> Bool {
        let normalized = Self.normalizeHandle(handle)
        let session = try await client.createSession(handle: normalized, password: password)
        loadedHandle = session.handle
        return true
    }

    public func logout() async {
        await client.clearSession()
        loadedContent = []
        loadedHandle = nil
    }

    /// Resume a session persisted by ``SessionStore`` on a previous
    /// run. Validates the stored tokens against the PDS by issuing a
    /// refresh — on failure the store is cleared and the caller falls
    /// back to the LoginView. Returns true if the session is live.
    @discardableResult
    public func tryRestoreSession() async -> Bool {
        let resumed = await client.tryResumePersistedSession()
        if resumed {
            loadedHandle = await client.currentHandle
        }
        return resumed
    }

    public var isAuthenticated: Bool {
        get async { await client.isAuthenticated }
    }

    public var currentHandle: String? {
        get async { await client.currentHandle }
    }

    public var currentDID: String? {
        get async { await client.currentDid }
    }

    // MARK: - Content loading

    /// Reported after each page of either endpoint completes. UI binds to
    /// this so the user sees "Loaded 1,247… still scanning" instead of a
    /// frozen spinner. The end of a load fires with `isComplete: true`.
    public struct LoadProgress: Sendable, Equatable {
        public let phase: Phase
        public let itemsLoaded: Int
        public let pagesFetched: Int
        public let isComplete: Bool
        /// True when an endpoint stopped at ``maxPagesPerEndpoint`` with
        /// more pages available — the archive holds items this load never
        /// saw. UI must say so; "delete everything" against a truncated
        /// load silently leaves the overflow live on Bluesky.
        public let truncated: Bool

        public init(
            phase: Phase,
            itemsLoaded: Int,
            pagesFetched: Int,
            isComplete: Bool,
            truncated: Bool = false
        ) {
            self.phase = phase
            self.itemsLoaded = itemsLoaded
            self.pagesFetched = pagesFetched
            self.isComplete = isComplete
            self.truncated = truncated
        }

        public enum Phase: String, Sendable, Equatable {
            case posts = "Posts and replies"
            case likes = "Likes"
            case done  = "Done"

            /// Segment for ``ArchiveLoadCheckpointRecord`` persistence (no `.done` row).
            var archivePhaseRaw: String? {
                switch self {
                case .posts: return "posts"
                case .likes: return "likes"
                case .done: return nil
                }
            }
        }
    }

    /// Maximum pages we'll fetch per endpoint before giving up. 200 pages
    /// × 100 items = 20k records — defensive ceiling for runaway accounts,
    /// generous for the median power user. Tunable.
    public static let maxPagesPerEndpoint = 200

    /// Snapshot of the in-memory cache. The UI pulls this between progress
    /// ticks so items appear as pages arrive instead of all-at-once.
    public var loadedSnapshot: [ContentItem] { loadedContent }

    /// True when the most recent ``ensureContentLoaded`` hit the page cap
    /// on any endpoint with more pages remaining. See ``LoadProgress/truncated``.
    public private(set) var lastLoadTruncated: Bool = false

    /// Fetch only the newest page from each content endpoint and merge it
    /// into the current snapshot. This is the fast path for app launch and
    /// pull-to-refresh; full archive refresh remains available through
    /// ``ensureContentLoaded(forceRefresh:progress:)``.
    @discardableResult
    public func refreshMostRecentContent(
        progress: (@Sendable (LoadProgress) async -> Void)? = nil
    ) async throws -> [ContentItem] {
        guard let did = await client.currentDid else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }

        let owner = await client.currentHandle ?? did

        let postsResponse = try await client.getAuthorFeed(actor: did, limit: 100)
        let posts = postsResponse.feed.map(Self.toContentItem)
        mergeFreshItems(posts)
        persist(posts, owner: owner)
        await progress?(LoadProgress(
            phase: .posts,
            itemsLoaded: loadedContent.count,
            pagesFetched: 1,
            isComplete: false
        ))

        let likesResponse = try await client.getActorLikes(actor: did, limit: 100)
        let likes = likesResponse.feed.map { view -> ContentItem in
            let base = Self.toContentItem(view)
            return ContentItem(
                uri: base.uri, cid: base.cid,
                deletionURI: view.post.viewer?.like,
                contentType: .likes,
                text: base.text, createdAt: base.createdAt,
                likeCount: base.likeCount, repostCount: base.repostCount,
                replyCount: base.replyCount, media: base.media,
                linkCard: base.linkCard, textLinks: base.textLinks,
                subjectAuthorHandle: view.post.author.handle
            )
        }
        mergeFreshItems(likes)
        persist(likes, owner: owner)
        await progress?(LoadProgress(
            phase: .done,
            itemsLoaded: loadedContent.count,
            pagesFetched: 2,
            isComplete: true
        ))

        return loadedContent
    }

    /// Fetch the user's complete posts/replies/reposts/likes set from the
    /// PDS via cursor pagination. Both endpoints are looped to exhaustion
    /// (or the page cap), with `progress` called after every page so the
    /// caller can incrementally update its UI.
    ///
    /// `Task.checkCancellation` is honored between pages — calling
    /// `task.cancel()` from a parent stops the load and leaves the
    /// already-collected items intact. The same cancellation is what
    /// powers the user-visible "Stop" button.
    @discardableResult
    public func ensureContentLoaded(
        forceRefresh: Bool = false,
        progress: (@Sendable (LoadProgress) async -> Void)? = nil
    ) async throws -> [ContentItem] {
        guard let did = await client.currentDid else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }

        let owner = await client.currentHandle ?? did
        let previousSnapshot = loadedContent
        let pendingGeneration = archiveLoadGeneration(owner: owner)
        if !forceRefresh, !loadedContent.isEmpty, pendingGeneration == nil {
            return loadedContent
        }

        let generationID: String
        if forceRefresh {
            clearRefreshStaging(owner: owner)
            clearArchiveLoadCheckpoints(owner: owner)
            generationID = UUID().uuidString
        } else if let pendingGeneration {
            generationID = pendingGeneration
        } else {
            clearRefreshStaging(owner: owner)
            clearArchiveLoadCheckpoints(owner: owner)
            generationID = UUID().uuidString
        }
        loadedContent = loadRefreshStaging(owner: owner, generationID: generationID)

        do {
            let postsExhausted = try await loopEndpoint(
                phase: .posts,
                owner: owner,
                generationID: generationID,
                progress: progress
            ) { cursor in
                let response = try await self.client.getAuthorFeed(
                    actor: did, limit: 100, cursor: cursor
                )
                return (response.feed.map(Self.toContentItem), response.cursor)
            }

            let likesExhausted = try await loopEndpoint(
                phase: .likes,
                owner: owner,
                generationID: generationID,
                progress: progress
            ) { cursor in
                let response = try await self.client.getActorLikes(
                    actor: did, limit: 100, cursor: cursor
                )
                let items = response.feed.map { view -> ContentItem in
                    let base = Self.toContentItem(view)
                    return ContentItem(
                        uri: base.uri, cid: base.cid,
                        deletionURI: view.post.viewer?.like,
                        contentType: .likes,
                        text: base.text, createdAt: base.createdAt,
                        likeCount: base.likeCount, repostCount: base.repostCount,
                        replyCount: base.replyCount, media: base.media,
                        linkCard: base.linkCard, textLinks: base.textLinks,
                        subjectAuthorHandle: view.post.author.handle
                    )
                }
                return (items, response.cursor)
            }

            let truncated = !(postsExhausted && likesExhausted)
            lastLoadTruncated = truncated
            try replaceCommittedContent(
                owner: owner,
                with: loadedContent,
                evictStale: !truncated
            )
            clearRefreshStaging(owner: owner)
            clearArchiveLoadCheckpoints(owner: owner)
            await progress?(LoadProgress(
                phase: .done,
                itemsLoaded: loadedContent.count,
                pagesFetched: 0,
                isComplete: true,
                truncated: truncated
            ))
            return loadedContent
        } catch {
            loadedContent = previousSnapshot
            throw error
        }
    }

    /// Loop one paginated endpoint until cursor is nil or the page cap
    /// trips. Appends each page's items to `loadedContent` so the UI can
    /// render incrementally, and persists each page to the SwiftData
    /// cache so cold-start gets the same view back.
    ///
    /// Returns `true` when the endpoint was exhausted (cursor ran out) and
    /// `false` when the page cap stopped it with more pages available.
    @discardableResult
    private func loopEndpoint(
        phase: LoadProgress.Phase,
        owner: String,
        generationID: String,
        progress: (@Sendable (LoadProgress) async -> Void)?,
        fetch: (String?) async throws -> ([ContentItem], String?)
    ) async throws -> Bool {
        guard let phaseKey = phase.archivePhaseRaw else { return true }

        var cursor: String? = loadArchiveCheckpointCursor(owner: owner, phaseKey: phaseKey)
        var pages = loadArchiveCheckpointPagesFetched(owner: owner, phaseKey: phaseKey)
        if pages > 0 && cursor == nil { return true }
        var knownIDs = Set(loadedContent.map(\.id))
        repeat {
            try Task.checkCancellation()
            let (items, nextCursor) = try await fetch(cursor)
            for item in items {
                if knownIDs.insert(item.id).inserted {
                    loadedContent.append(item)
                }
            }
            persistRefreshStaging(items, owner: owner, generationID: generationID)
            pages += 1
            cursor = nextCursor
            upsertArchiveCheckpoint(
                owner: owner,
                phaseKey: phaseKey,
                cursor: nextCursor,
                pagesFetched: pages,
                generationID: generationID
            )
            await progress?(LoadProgress(
                phase: phase,
                itemsLoaded: loadedContent.count,
                pagesFetched: pages,
                isComplete: false
            ))
        } while cursor != nil && pages < Self.maxPagesPerEndpoint

        return cursor == nil
    }

    /// Inject a content list directly. Useful for previews, tests, and
    /// loading from an offline backup.
    public func setLoadedContent(_ items: [ContentItem]) {
        self.loadedContent = items
    }

    private func mergeFreshItems(_ freshItems: [ContentItem]) {
        guard !freshItems.isEmpty else { return }
        var byID: [String: ContentItem] = [:]
        for item in loadedContent {
            byID[item.id] = item
        }
        for item in freshItems {
            byID[item.id] = item
        }
        loadedContent = byID.values.sorted {
            switch ($0.createdAt, $1.createdAt) {
            case let (lhs?, rhs?):
                return lhs > rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return $0.id < $1.id
            }
        }
    }

    /// How ``applyBackupImport`` should combine imported rows with the live cache.
    public enum BackupImportMode: String, Sendable {
        case mergeByURI
        case replaceAll
    }

    /// Merge or replace in-memory content and upsert into SwiftData for `owner`
    /// (the same owner key used when persisting loaded pages — typically
    /// ``currentHandle`` or DID from the active session).
    public func applyBackupImport(
        items: [ContentItem],
        mode: BackupImportMode,
        owner: String
    ) async {
        switch mode {
        case .mergeByURI:
            var byURI: [String: ContentItem] = [:]
            for i in loadedContent { byURI[i.uri] = i }
            for i in items { byURI[i.uri] = i }
            loadedContent = Array(byURI.values)
        case .replaceAll:
            loadedContent = items
            clearPersistedContent(owner: owner)
        }
        persist(loadedContent, owner: owner)
    }

    // MARK: - Search

    public func search(_ request: SearchRequest) -> (results: [SearchResult], total: Int) {
        let allMatches = request.apply(to: loadedContent)
        let capped = Array(allMatches.prefix(request.limit))
        let results = capped.map(SearchResult.init(item:))
        return (results, allMatches.count)
    }

    /// Resolves delete targets the same way as ``delete(itemIDs:)`` without XRPC.
    public func preflightDelete(itemIDs: [String]) -> DeletePreflightSummary {
        DeletePreflight.summarize(itemIDs: itemIDs, loadedContent: loadedContent)
    }

    // MARK: - Delete

    /// Consecutive failures that halt a batch. Once the network is down or
    /// the hourly write window is exhausted, every remaining item fails the
    /// same way — grinding on just burns hours and floods the error list.
    public static let maxConsecutiveDeleteFailures = 10

    /// Breadcrumb write cadence. Rewriting a 50k-ID payload per success
    /// would be O(n²) UserDefaults churn over a multi-hour batch.
    private static let breadcrumbChunk = 25

    /// Delete each item individually. Returns (deletedCount, errorMessages).
    /// Each call is wrapped in `RateLimit.withBackoff` inside ``ATProtoClient``
    /// — concurrent fan-out is intentionally avoided so we don't blow past
    /// the per-account write quota faster, and past ``DeletePacing/burstAllowance``
    /// the loop self-paces below the hourly quota.
    ///
    /// The loop honors task cancellation between items, trims the
    /// ``DeleteBatchRecovery`` breadcrumb as successes land, and halts after
    /// ``maxConsecutiveDeleteFailures`` so a dead network or exhausted quota
    /// fails the batch honestly instead of grinding through every item.
    public func delete(
        itemIDs: [String],
        progress: (@Sendable (Int) async -> Void)? = nil,
        onRateLimitWait: (@Sendable (Int) -> Void)? = nil
    ) async -> (deleted: Int, errors: [String]) {
        // Owner is captured BEFORE any network call: if the session dies
        // mid-batch, a nil owner would send deletePersistedContent down its
        // ownerless branch and evict cache rows for every account on the
        // device.
        let ownerHandle = await client.currentHandle
        let ownerDID = await client.currentDid
        let owner = ownerHandle ?? ownerDID

        var deleted = 0
        var errors: [String] = []
        var deletedIDs: [String] = []
        var breadcrumbBacklog: [String] = []
        var consecutiveFailures = 0

        defer {
            DeleteBatchRecovery.markCompleted(breadcrumbBacklog)
            if !deletedIDs.isEmpty {
                deletePersistedContent(itemIDs: deletedIDs, owner: owner)
            }
        }

        for (index, id) in itemIDs.enumerated() {
            if Task.isCancelled {
                errors.append("Stopped by user: \(itemIDs.count - index) item(s) not attempted.")
                break
            }
            if consecutiveFailures >= Self.maxConsecutiveDeleteFailures {
                errors.append("Stopped after \(consecutiveFailures) consecutive failures: \(itemIDs.count - index) item(s) not attempted. Check your connection or try again later — Bluesky may be rate-limiting this account.")
                break
            }
            guard let item = loadedContent.first(where: { $0.id == id || $0.uri == id }) else {
                errors.append("\(id): not in loaded content")
                continue
            }
            guard let deletionURI = item.deletionURI else {
                errors.append("\(item.uri): no deletable \(item.contentType.label.lowercased()) record")
                continue
            }
            do {
                let expectedCollection: ATProtoRecordCollection
                switch item.contentType {
                case .posts, .replies:
                    expectedCollection = .post
                case .likes:
                    expectedCollection = .like
                case .reposts:
                    expectedCollection = .repost
                case .all:
                    errors.append("\(item.uri): unsupported aggregate content type")
                    continue
                }
                if deleted + 1 > DeletePacing.burstAllowance {
                    try? await Task.sleep(
                        nanoseconds: UInt64(DeletePacing.pacedDelaySeconds * 1_000_000_000)
                    )
                }
                try await client.deleteRecord(
                    uri: deletionURI,
                    expectedCollection: expectedCollection,
                    onRateLimitWait: onRateLimitWait
                )
                deleted += 1
                consecutiveFailures = 0
                loadedContent.removeAll { $0.id == item.id }
                deletedIDs.append(item.id)
                await progress?(deleted)
                breadcrumbBacklog.append(item.id)
                if breadcrumbBacklog.count >= Self.breadcrumbChunk {
                    DeleteBatchRecovery.markCompleted(breadcrumbBacklog)
                    breadcrumbBacklog.removeAll(keepingCapacity: true)
                }
            } catch {
                consecutiveFailures += 1
                errors.append("\(item.uri): \(error.localizedDescription)")
            }
        }
        return (deleted, errors)
    }

    public func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        await delete(itemIDs: uris)
    }

    // MARK: - Summary

    public func summarize() -> [ContentType: Int] {
        var counts: [ContentType: Int] = [:]
        for item in loadedContent {
            counts[item.contentType, default: 0] += 1
        }
        return counts
    }

    public var loadedItemCount: Int { loadedContent.count }

    // MARK: - Helpers

    public static func normalizeHandle(_ raw: String) -> String {
        var handle = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if handle.hasPrefix("@") { handle.removeFirst() }
        // Email-style custom domains (e.g. `adam@blacksky.com`) are a real
        // user-visible mistake — AT Protocol uses dots, not @ symbols, so
        // rewrite any remaining `@` to `.`. Mirrors Python at
        // `reference/python/auth.py:140-142`.
        handle = handle.replacingOccurrences(of: "@", with: ".")
        if !handle.contains(".") { handle += ".bsky.social" }
        return handle
    }

    private static func toContentItem(_ view: FeedViewPost) -> ContentItem {
        let post = view.post
        let isReply = view.reply != nil || (post.record?.reply != nil)
        let isRepost = view.reason != nil
        let type: ContentType = isRepost ? .reposts : (isReply ? .replies : .posts)

        let createdAt = ATProtoDate.parse(post.record?.createdAt)

        let subjectHandle: String? = (type == .likes || type == .reposts)
            ? post.author.handle
            : nil

        return ContentItem(
            uri: post.uri,
            cid: post.cid,
            deletionURI: deletionURI(for: type, post: post),
            contentType: type,
            text: post.record?.text,
            createdAt: createdAt,
            likeCount: post.likeCount ?? 0,
            repostCount: post.repostCount ?? 0,
            replyCount: post.replyCount ?? 0,
            media: extractMediaPreviews(post.embed),
            linkCard: extractLinkCard(post.embed),
            textLinks: extractTextLinks(post.record?.facets),
            // Capture the parent URI for replies. Used by
            // InteractionService.loadInteractions to filter "your
            // replies to @alice" without extra network calls.
            // FeedViewPost.reply.parent.uri is more reliable than
            // record.reply.parent.uri because the relay enriches it.
            parentReplyURI: view.reply?.parent?.uri ?? post.record?.reply?.parent?.uri,
            subjectAuthorHandle: subjectHandle
        )
    }

    /// Maps a content type + post view to the at:// URI of the record
    /// to delete from the caller's own repo. For posts/replies this is
    /// the subject URI; for likes/reposts it's the viewer's record URI
    /// (a no-op against the subject if mis-targeted, hence
    /// `DeleteURIMappingTests` guards this mapping directly).
    internal static func deletionURI(for type: ContentType, post: PostView) -> String? {
        switch type {
        case .posts, .replies:
            return post.uri
        case .reposts:
            return post.viewer?.repost
        case .likes:
            return post.viewer?.like
        case .all:
            return nil
        }
    }

    /// Walk an `app.bsky.embed.*#view` and pull out image / video previews
    /// with their alt text. External link cards are intentionally skipped
    /// — "media" filter means photos and videos, matching the user's
    /// mental model. Link cards travel separately on `linkCard`.
    private static func extractMediaPreviews(_ embed: PostEmbedView?) -> [MediaPreview] {
        guard let embed else { return [] }
        var previews: [MediaPreview] = []

        for image in embed.images ?? [] {
            previews.append(MediaPreview(
                kind: .image,
                thumbnailURL: image.thumb.flatMap(URL.init(string:)),
                fullsizeURL: image.fullsize.flatMap(URL.init(string:)),
                alt: image.alt
            ))
        }
        if let video = embed.video {
            previews.append(MediaPreview(
                kind: .video,
                thumbnailURL: video.playlist.flatMap(URL.init(string:)),
                alt: video.alt
            ))
        }
        // recordWithMedia → recurse one level
        if let inner = embed.media {
            for image in inner.images ?? [] {
                previews.append(MediaPreview(
                    kind: .image,
                    thumbnailURL: image.thumb.flatMap(URL.init(string:)),
                    fullsizeURL: image.fullsize.flatMap(URL.init(string:)),
                    alt: image.alt
                ))
            }
            if let video = inner.video {
                previews.append(MediaPreview(
                    kind: .video,
                    thumbnailURL: video.playlist.flatMap(URL.init(string:)),
                    alt: video.alt
                ))
            }
        }
        return previews
    }

    /// Pull out the `app.bsky.embed.external` link card, if any. Lives
    /// alongside (not inside) the media list — it has different render
    /// affordances (title + description + thumb, tap = open in Safari).
    private static func extractLinkCard(_ embed: PostEmbedView?) -> LinkCard? {
        guard let extEmbed = embed?.external?.external,
              let urlString = extEmbed.uri,
              let url = URL(string: urlString) else { return nil }
        return LinkCard(
            url: url,
            title: extEmbed.title,
            summary: extEmbed.description,
            thumbnailURL: extEmbed.thumb.flatMap(URL.init(string:))
        )
    }

    /// Decode `app.bsky.richtext.facet#link` features into TextLink
    /// records. Mentions and hashtags are skipped — content management
    /// doesn't need them tappable. UTF-8 byte ranges flow through
    /// unchanged; the AttributedString builder converts them to
    /// String.Index when rendering.
    private static func extractTextLinks(_ facets: [Facet]?) -> [TextLink] {
        guard let facets else { return [] }
        return facets.compactMap { facet in
            guard let link = facet.features.first(where: {
                $0.type == "app.bsky.richtext.facet#link"
            })?.uri,
                  let url = URL(string: link) else { return nil }
            return TextLink(
                url: url,
                byteStart: facet.index.byteStart,
                byteEnd: facet.index.byteEnd
            )
        }
    }

    // MARK: - Persistence (write-through to SwiftData cache)

    /// Upsert a slice of content items into the SwiftData cache.
    /// Called once per page in loopEndpoint. Fresh ModelContext per
    /// call — same pattern as FollowerService.
    private func persist(_ items: [ContentItem], owner: String) {
        let context = ModelContext(container)
        let now = Date()
        for item in items {
            let key = ContentItemRecord.makeCompositeKey(
                ownerHandle: owner,
                contentType: item.contentType,
                uri: item.uri
            )
            let descriptor = FetchDescriptor<ContentItemRecord>(
                predicate: #Predicate { $0.compositeKey == key }
            )
            if let existing = try? context.fetch(descriptor).first {
                // Refresh counts (engagement may have changed since
                // the cache was populated) and bump scannedAt.
                existing.likeCount = item.likeCount
                existing.repostCount = item.repostCount
                existing.replyCount = item.replyCount
                existing.hasMedia = item.hasMedia
                existing.deletionURI = item.deletionURI
                existing.parentReplyURI = item.parentReplyURI
                existing.subjectAuthorHandle = item.subjectAuthorHandle
                existing.scannedAt = now
            } else {
                context.insert(ContentItemRecord(
                    uri: item.uri,
                    cid: item.cid,
                    deletionURI: item.deletionURI,
                    contentType: item.contentType,
                    text: item.text,
                    createdAt: item.createdAt,
                    likeCount: item.likeCount,
                    repostCount: item.repostCount,
                    replyCount: item.replyCount,
                    hasMedia: item.hasMedia,
                    ownerHandle: owner,
                    scannedAt: now,
                    parentReplyURI: item.parentReplyURI,
                    subjectAuthorHandle: item.subjectAuthorHandle
                ))
            }
        }
        saveOrLog(context, "persist")
    }

    /// Drop matching cached records after a successful delete so they
    /// don't reappear on cold-start.
    private func deletePersistedContent(itemIDs: [String], owner: String?) {
        let context = ModelContext(container)
        for id in itemIDs {
            let descriptor: FetchDescriptor<ContentItemRecord>
            if let owner {
                descriptor = FetchDescriptor<ContentItemRecord>(
                    predicate: #Predicate { $0.itemID == id && $0.ownerHandle == owner }
                )
            } else {
                descriptor = FetchDescriptor<ContentItemRecord>(
                    predicate: #Predicate { $0.itemID == id }
                )
            }
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
            }
        }
        saveOrLog(context, "deletePersistedContent")
    }

    /// Wipe all cached content for one owner before a forceRefresh
    /// scan — same rationale as FollowerService.clearPersistedScan.
    private func clearPersistedContent(owner: String) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContentItemRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        if let rows = try? context.fetch(descriptor) {
            for row in rows { context.delete(row) }
            try? context.save()
        }
        clearArchiveLoadCheckpoints(owner: owner)
        clearRefreshStaging(owner: owner)
    }

    // MARK: - Transactional refresh staging

    private func persistRefreshStaging(
        _ items: [ContentItem],
        owner: String,
        generationID: String
    ) {
        let context = ModelContext(container)
        for item in items {
            let key = "\(owner)|\(generationID)|\(item.id)"
            let descriptor = FetchDescriptor<ContentRefreshStagingRecord>(
                predicate: #Predicate { $0.compositeKey == key }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.update(from: item)
            } else {
                context.insert(ContentRefreshStagingRecord(
                    item: item,
                    ownerHandle: owner,
                    generationID: generationID
                ))
            }
        }
        saveOrLog(context, "persistRefreshStaging")
    }

    private func loadRefreshStaging(owner: String, generationID: String) -> [ContentItem] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContentRefreshStagingRecord>(
            predicate: #Predicate {
                $0.ownerHandle == owner && $0.generationID == generationID
            }
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toContentItem() }
    }

    private func clearRefreshStaging(owner: String) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContentRefreshStagingRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        for row in (try? context.fetch(descriptor)) ?? [] {
            context.delete(row)
        }
        try? context.save()
    }

    /// `evictStale: false` is the truncated-load path: rows absent from a
    /// capped load may simply live beyond the page cap, so deleting them
    /// would evict known-good cache for content that still exists upstream.
    private func replaceCommittedContent(
        owner: String,
        with items: [ContentItem],
        evictStale: Bool = true
    ) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContentItemRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        let existingRows = (try? context.fetch(descriptor)) ?? []
        // uniquingKeysWith: a duplicate composite key (possible across
        // migrations / multi-context writes despite the .unique attribute)
        // must not trap at the end of a multi-hour refresh.
        var existingByKey = Dictionary(
            existingRows.map { ($0.compositeKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let now = Date()

        for item in items {
            let key = ContentItemRecord.makeCompositeKey(
                ownerHandle: owner,
                contentType: item.contentType,
                uri: item.uri
            )
            if let existing = existingByKey.removeValue(forKey: key) {
                existing.deletionURI = item.deletionURI
                existing.cid = item.cid
                existing.text = item.text
                existing.createdAt = item.createdAt
                existing.likeCount = item.likeCount
                existing.repostCount = item.repostCount
                existing.replyCount = item.replyCount
                existing.hasMedia = item.hasMedia
                existing.parentReplyURI = item.parentReplyURI
                existing.subjectAuthorHandle = item.subjectAuthorHandle
                existing.scannedAt = now
            } else {
                context.insert(ContentItemRecord(
                    uri: item.uri,
                    cid: item.cid,
                    deletionURI: item.deletionURI,
                    contentType: item.contentType,
                    text: item.text,
                    createdAt: item.createdAt,
                    likeCount: item.likeCount,
                    repostCount: item.repostCount,
                    replyCount: item.replyCount,
                    hasMedia: item.hasMedia,
                    ownerHandle: owner,
                    scannedAt: now,
                    parentReplyURI: item.parentReplyURI,
                    subjectAuthorHandle: item.subjectAuthorHandle
                ))
            }
        }
        if evictStale {
            for stale in existingByKey.values {
                context.delete(stale)
            }
        }
        try context.save()
    }

    // MARK: - Archive load checkpoints (resume pagination)

    private func archiveLoadGeneration(owner: String) -> String? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        let generations = Set(((try? context.fetch(descriptor)) ?? []).map(\.generationID))
        guard generations.count == 1, let generation = generations.first, !generation.isEmpty else {
            if !generations.isEmpty {
                clearArchiveLoadCheckpoints(owner: owner)
                clearRefreshStaging(owner: owner)
            }
            return nil
        }
        return generation
    }

    private func clearArchiveLoadCheckpoints(owner: String) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        for row in (try? context.fetch(descriptor)) ?? [] {
            context.delete(row)
        }
        try? context.save()
    }

    private func loadArchiveCheckpointCursor(owner: String, phaseKey: String) -> String? {
        let scopeKey = "\(owner)|\(phaseKey)"
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.scopeKey == scopeKey }
        )
        return try? context.fetch(descriptor).first?.cursor
    }

    private func loadArchiveCheckpointPagesFetched(owner: String, phaseKey: String) -> Int {
        let scopeKey = "\(owner)|\(phaseKey)"
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.scopeKey == scopeKey }
        )
        return (try? context.fetch(descriptor).first?.pagesFetched) ?? 0
    }

    private func upsertArchiveCheckpoint(
        owner: String,
        phaseKey: String,
        cursor: String?,
        pagesFetched: Int,
        generationID: String
    ) {
        let scopeKey = "\(owner)|\(phaseKey)"
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.scopeKey == scopeKey }
        )
        let now = Date()
        if let row = try? context.fetch(descriptor).first {
            row.cursor = cursor
            row.pagesFetched = pagesFetched
            row.generationID = generationID
            row.updatedAt = now
        } else {
            context.insert(ArchiveLoadCheckpointRecord(
                ownerHandle: owner,
                phaseRaw: phaseKey,
                cursor: cursor,
                pagesFetched: pagesFetched,
                generationID: generationID,
                updatedAt: now
            ))
        }
        try? context.save()
    }
}
