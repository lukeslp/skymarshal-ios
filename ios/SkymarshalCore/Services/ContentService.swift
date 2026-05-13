import Foundation
import SwiftData

/// The orchestration boundary every UI layer should sit on top of.
///
/// Mirrors `reference/python/services/content_service.py` — five public methods
/// plus one read-only property. UI and `AppModel` call **only** this actor for
/// orchestration (no parallel “shadow” load/delete paths around it).
@available(iOS 17, *)
public actor ContentService {

    private let client: ATProtoClient
    private let container: ModelContainer
    private var loadedContent: [ContentItem] = []
    private var loadedHandle: String?

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

        public init(phase: Phase, itemsLoaded: Int, pagesFetched: Int, isComplete: Bool) {
            self.phase = phase
            self.itemsLoaded = itemsLoaded
            self.pagesFetched = pagesFetched
            self.isComplete = isComplete
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
        let hasPendingArchiveCheckpoint = archiveLoadHasPendingCheckpoint(owner: owner)
        if !forceRefresh, !loadedContent.isEmpty, !hasPendingArchiveCheckpoint {
            return loadedContent
        }

        if forceRefresh {
            loadedContent = []
            clearPersistedContent(owner: owner)
            clearArchiveLoadCheckpoints(owner: owner)
        }

        try await loopEndpoint(
            phase: .posts,
            owner: owner,
            progress: progress
        ) { cursor in
            let response = try await self.client.getAuthorFeed(
                actor: did, limit: 100, cursor: cursor
            )
            return (response.feed.map(Self.toContentItem), response.cursor)
        }

        try await loopEndpoint(
            phase: .likes,
            owner: owner,
            progress: progress
        ) { cursor in
            let response = try await self.client.getActorLikes(
                actor: did, limit: 100, cursor: cursor
            )
            // getActorLikes returns the liked posts as subjects. The
            // user's deletable like record lives in post.viewer.like.
            let items = response.feed.map { view -> ContentItem in
                let base = Self.toContentItem(view)
                return ContentItem(
                    uri: base.uri, cid: base.cid,
                    deletionURI: view.post.viewer?.like,
                    contentType: .likes,
                    text: base.text, createdAt: base.createdAt,
                    likeCount: base.likeCount, repostCount: base.repostCount,
                    replyCount: base.replyCount, media: base.media,
                    linkCard: base.linkCard, textLinks: base.textLinks
                )
            }
            return (items, response.cursor)
        }

        await progress?(LoadProgress(
            phase: .done,
            itemsLoaded: loadedContent.count,
            pagesFetched: 0,
            isComplete: true
        ))
        return loadedContent
    }

    /// Loop one paginated endpoint until cursor is nil or the page cap
    /// trips. Appends each page's items to `loadedContent` so the UI can
    /// render incrementally, and persists each page to the SwiftData
    /// cache so cold-start gets the same view back.
    private func loopEndpoint(
        phase: LoadProgress.Phase,
        owner: String,
        progress: (@Sendable (LoadProgress) async -> Void)?,
        fetch: (String?) async throws -> ([ContentItem], String?)
    ) async throws {
        guard let phaseKey = phase.archivePhaseRaw else { return }

        var cursor: String? = loadArchiveCheckpointCursor(owner: owner, phaseKey: phaseKey)
        var pages = loadArchiveCheckpointPagesFetched(owner: owner, phaseKey: phaseKey)
        var knownIDs = Set(loadedContent.map(\.id))
        repeat {
            try Task.checkCancellation()
            let (items, nextCursor) = try await fetch(cursor)
            for item in items {
                if knownIDs.insert(item.id).inserted {
                    loadedContent.append(item)
                }
            }
            persist(items, owner: owner)
            pages += 1
            cursor = nextCursor
            upsertArchiveCheckpoint(
                owner: owner,
                phaseKey: phaseKey,
                cursor: nextCursor,
                pagesFetched: pages
            )
            await progress?(LoadProgress(
                phase: phase,
                itemsLoaded: loadedContent.count,
                pagesFetched: pages,
                isComplete: false
            ))
        } while cursor != nil && pages < Self.maxPagesPerEndpoint

        if cursor == nil {
            deleteArchiveCheckpoint(owner: owner, phaseKey: phaseKey)
        }
    }

    /// Inject a content list directly. Useful for previews, tests, and
    /// loading from an offline backup.
    public func setLoadedContent(_ items: [ContentItem]) {
        self.loadedContent = items
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
        let filtered = request.apply(to: loadedContent)
        let results = filtered.map(SearchResult.init(item:))
        return (results, filtered.count)
    }

    /// Resolves delete targets the same way as ``delete(itemIDs:)`` without XRPC.
    public func preflightDelete(itemIDs: [String]) -> DeletePreflightSummary {
        DeletePreflight.summarize(itemIDs: itemIDs, loadedContent: loadedContent)
    }

    // MARK: - Delete

    /// Delete each item individually. Returns (deletedCount, errorMessages).
    /// Each call is wrapped in `RateLimit.withBackoff` inside ``ATProtoClient``
    /// — concurrent fan-out is intentionally avoided so we don't blow past
    /// the per-account write quota faster.
    public func delete(itemIDs: [String]) async -> (deleted: Int, errors: [String]) {
        var deleted = 0
        var errors: [String] = []
        var deletedIDs: [String] = []
        for id in itemIDs {
            guard let item = loadedContent.first(where: { $0.id == id || $0.uri == id }) else {
                errors.append("\(id): not in loaded content")
                continue
            }
            guard let deletionURI = item.deletionURI else {
                errors.append("\(item.uri): no deletable \(item.contentType.label.lowercased()) record")
                continue
            }
            do {
                try await client.deleteRecord(uri: deletionURI)
                deleted += 1
                loadedContent.removeAll { $0.id == item.id }
                deletedIDs.append(item.id)
            } catch {
                errors.append("\(item.uri): \(error.localizedDescription)")
            }
        }
        if !deletedIDs.isEmpty {
            let currentHandle = await client.currentHandle
            let currentDID = await client.currentDid
            let owner = currentHandle ?? currentDID
            deletePersistedContent(itemIDs: deletedIDs, owner: owner)
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
        if !handle.contains(".") { handle += ".bsky.social" }
        return handle
    }

    private static func toContentItem(_ view: FeedViewPost) -> ContentItem {
        let post = view.post
        let isReply = view.reply != nil || (post.record?.reply != nil)
        let isRepost = view.reason != nil
        let type: ContentType = isRepost ? .reposts : (isReply ? .replies : .posts)

        let createdAt: Date? = {
            if let iso = post.record?.createdAt {
                return ISO8601DateFormatter().date(from: iso)
            }
            return nil
        }()

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
            parentReplyURI: view.reply?.parent?.uri ?? post.record?.reply?.parent?.uri
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
                    parentReplyURI: item.parentReplyURI
                ))
            }
        }
        try? context.save()
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
        try? context.save()
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
    }

    // MARK: - Archive load checkpoints (resume pagination)

    private func archiveLoadHasPendingCheckpoint(owner: String) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        guard let rows = try? context.fetch(descriptor) else { return false }
        return !rows.isEmpty
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
        pagesFetched: Int
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
            row.updatedAt = now
        } else {
            context.insert(ArchiveLoadCheckpointRecord(
                ownerHandle: owner,
                phaseRaw: phaseKey,
                cursor: cursor,
                pagesFetched: pagesFetched,
                updatedAt: now
            ))
        }
        try? context.save()
    }

    private func deleteArchiveCheckpoint(owner: String, phaseKey: String) {
        let scopeKey = "\(owner)|\(phaseKey)"
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.scopeKey == scopeKey }
        )
        for row in (try? context.fetch(descriptor)) ?? [] {
            context.delete(row)
        }
        try? context.save()
    }
}
