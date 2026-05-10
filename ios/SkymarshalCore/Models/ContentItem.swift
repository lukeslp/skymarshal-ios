import Foundation

/// One piece of the user's Bluesky content — a post, reply, repost, or like.
///
/// Mirrors `reference/python/models.py` `ContentItem` and the TypeScript
/// `reference/web/skymarshal/types.ts` `ContentItem`. The `engagementScore`
/// follows the **Python weighting** (`1×likes + 2×reposts + 2.5×replies`),
/// not the TS port's `1/2/3` — see MIGRATION.md for the drift rationale.
public struct ContentItem: Identifiable, Hashable, Codable, Sendable {

    /// at:// URI — the delete key.
    public let uri: String
    public let cid: String
    public let contentType: ContentType
    public let text: String?
    public let createdAt: Date?
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var media: [MediaPreview]

    public var id: String { uri }

    /// True when the post has any image or video attachment. External
    /// link cards do NOT count as media for filter purposes — that
    /// matches user mental model ("photos and videos").
    public var hasMedia: Bool { !media.isEmpty }

    /// Concatenation of all alt-text strings on the post's media.
    /// Empty when no media or all alts are blank. Used as a search
    /// haystack when ``SearchRequest/includeAltTextInKeyword`` is on.
    public var altText: String {
        media.compactMap { $0.alt }.joined(separator: " ")
    }

    public init(
        uri: String,
        cid: String,
        contentType: ContentType,
        text: String? = nil,
        createdAt: Date? = nil,
        likeCount: Int = 0,
        repostCount: Int = 0,
        replyCount: Int = 0,
        media: [MediaPreview] = []
    ) {
        self.uri = uri
        self.cid = cid
        self.contentType = contentType
        self.text = text
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.media = media
    }

    /// Engagement score — the same `1L + 2R + 2.5Reply` formula as the
    /// Python source. Replies weighted highest because they require the
    /// most effort; reposts beat likes because the user willingly put it
    /// on their own timeline. The 2.5 (not 3) prevents single-thread
    /// blowups from dominating the ranking.
    public var engagementScore: Double {
        EngagementScore.compute(
            likes: likeCount,
            reposts: repostCount,
            replies: replyCount
        )
    }
}

/// Engagement score formula. Lifted from `reference/python/models.py:51-60`.
public enum EngagementScore {
    public static func compute(likes: Int, reposts: Int, replies: Int) -> Double {
        Double(likes) + 2.0 * Double(reposts) + 2.5 * Double(replies)
    }
}

/// One image or video attached to a post. We carry the thumbnail URL
/// for inline rendering and the alt text for accessibility + search.
public struct MediaPreview: Hashable, Sendable, Codable {
    public let kind: Kind
    public let thumbnailURL: URL?
    public let alt: String?

    public enum Kind: String, Sendable, Codable {
        case image
        case video
    }

    public init(kind: Kind, thumbnailURL: URL? = nil, alt: String? = nil) {
        self.kind = kind
        self.thumbnailURL = thumbnailURL
        self.alt = alt?.isEmpty == false ? alt : nil
    }
}
