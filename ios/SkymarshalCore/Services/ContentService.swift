import Foundation
import SwiftData

/// The orchestration boundary every UI layer should sit on top of.
///
/// Mirrors `reference/python/services/content_service.py:69-…` — five
/// public methods plus one read-only property. The "shadow function" rule
/// from `~/.swarm/snippets/2026-05-09-skymarshal-content-service-api-shape.md`
/// applies: view code calls into this surface, never around it.
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
        if !forceRefresh, !loadedContent.isEmpty {
            return loadedContent
        }
        guard let did = await client.currentDid else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }

        if forceRefresh { loadedContent = [] }

        try await loopEndpoint(
            phase: .posts,
            progress: progress
        ) { cursor in
            let response = try await self.client.getAuthorFeed(
                actor: did, limit: 100, cursor: cursor
            )
            return (response.feed.map(Self.toContentItem), response.cursor)
        }

        try await loopEndpoint(
            phase: .likes,
            progress: progress
        ) { cursor in
            let response = try await self.client.getActorLikes(
                actor: did, limit: 100, cursor: cursor
            )
            // getActorLikes returns the *liked* posts in the feed; the
            // user's Like record is what we'd actually delete, so we
            // re-tag the contentType. Same URI as the post, but the
            // delete will hit app.bsky.feed.like via the user's repo
            // when we build the like-record URI in a follow-on.
            let items = response.feed.map { view -> ContentItem in
                let base = Self.toContentItem(view)
                return ContentItem(
                    uri: base.uri, cid: base.cid, contentType: .likes,
                    text: base.text, createdAt: base.createdAt,
                    likeCount: base.likeCount, repostCount: base.repostCount,
                    replyCount: base.replyCount, hasMedia: base.hasMedia
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
    /// render incrementally.
    private func loopEndpoint(
        phase: LoadProgress.Phase,
        progress: (@Sendable (LoadProgress) async -> Void)?,
        fetch: (String?) async throws -> ([ContentItem], String?)
    ) async throws {
        var cursor: String? = nil
        var pages = 0
        repeat {
            try Task.checkCancellation()
            let (items, nextCursor) = try await fetch(cursor)
            loadedContent.append(contentsOf: items)
            pages += 1
            cursor = nextCursor
            await progress?(LoadProgress(
                phase: phase,
                itemsLoaded: loadedContent.count,
                pagesFetched: pages,
                isComplete: false
            ))
        } while cursor != nil && pages < Self.maxPagesPerEndpoint
    }

    /// Inject a content list directly. Useful for previews, tests, and
    /// loading from an offline backup.
    public func setLoadedContent(_ items: [ContentItem]) {
        self.loadedContent = items
    }

    // MARK: - Search

    public func search(_ request: SearchRequest) -> (results: [SearchResult], total: Int) {
        let filtered = request.apply(to: loadedContent)
        let results = filtered.map(SearchResult.init(item:))
        return (results, filtered.count)
    }

    // MARK: - Delete

    /// Delete each URI individually. Returns (deletedCount, errorMessages).
    /// Each call is wrapped in `RateLimit.withBackoff` inside ``ATProtoClient``
    /// — concurrent fan-out is intentionally avoided so we don't blow past
    /// the per-account write quota faster.
    public func delete(uris: [String]) async -> (deleted: Int, errors: [String]) {
        var deleted = 0
        var errors: [String] = []
        for uri in uris {
            do {
                try await client.deleteRecord(uri: uri)
                deleted += 1
                loadedContent.removeAll { $0.uri == uri }
            } catch {
                errors.append("\(uri): \(error.localizedDescription)")
            }
        }
        return (deleted, errors)
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
            contentType: type,
            text: post.record?.text,
            createdAt: createdAt,
            likeCount: post.likeCount ?? 0,
            repostCount: post.repostCount ?? 0,
            replyCount: post.replyCount ?? 0,
            hasMedia: post.embed != nil
        )
    }
}
