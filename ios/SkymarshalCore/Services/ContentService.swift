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

    /// Fetch the user's posts, replies, reposts, and likes from the PDS,
    /// converting AT Protocol records to ``ContentItem`` and caching them
    /// in memory. The MVP loads up to `limit` items per category — full
    /// pagination follow-on for later.
    @discardableResult
    public func ensureContentLoaded(
        limit: Int = 250,
        forceRefresh: Bool = false
    ) async throws -> [ContentItem] {
        if !forceRefresh, !loadedContent.isEmpty {
            return loadedContent
        }
        guard let did = await client.currentDid else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }

        var collected: [ContentItem] = []

        // Posts + replies + reposts come from getAuthorFeed
        let feed = try await client.getAuthorFeed(actor: did, limit: min(limit, 100))
        for view in feed.feed {
            collected.append(Self.toContentItem(view))
        }

        // Likes come from a separate endpoint
        let likes = try await client.getActorLikes(actor: did, limit: min(limit, 100))
        for view in likes.feed {
            var item = Self.toContentItem(view)
            item = ContentItem(
                uri: item.uri,
                cid: item.cid,
                contentType: .likes,
                text: item.text,
                createdAt: item.createdAt,
                likeCount: item.likeCount,
                repostCount: item.repostCount,
                replyCount: item.replyCount,
                hasMedia: item.hasMedia
            )
            collected.append(item)
        }

        loadedContent = collected
        return loadedContent
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
