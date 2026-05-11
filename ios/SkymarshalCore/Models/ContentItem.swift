import Foundation

/// One piece of the user's Bluesky content — a post, reply, repost, or like.
///
/// Mirrors `reference/python/models.py` `ContentItem` and the TypeScript
/// `reference/web/skymarshal/types.ts` `ContentItem`. The `engagementScore`
/// follows the **Python weighting** (`1×likes + 2×reposts + 2.5×replies`),
/// not the TS port's `1/2/3` — see MIGRATION.md for the drift rationale.
public struct ContentItem: Identifiable, Hashable, Codable, Sendable {

    /// at:// URI of the subject being displayed.
    public let uri: String
    /// at:// URI of the record to delete from the signed-in user's repo.
    /// For posts/replies this is the same as `uri`; for likes/reposts it
    /// is the viewer's like/repost record URI.
    public let deletionURI: String?
    public let cid: String
    public let contentType: ContentType
    public let text: String?
    public let createdAt: Date?
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var media: [MediaPreview]
    public var linkCard: LinkCard?
    public var textLinks: [TextLink]
    /// at:// URI of the parent post for replies. Used to build
    /// interaction-history filters ("show me everything I've sent
    /// toward @alice" walks `parentReplyURI` across cached items).
    /// Nil for non-replies; for likes and reposts, `uri` itself IS
    /// the subject URI so no extra field is needed.
    public var parentReplyURI: String?

    public var id: String { "\(contentType.rawValue)|\(uri)" }

    /// at:// URI parsed into the (handle/did, rkey) pair so we can build
    /// a `https://bsky.app/profile/<handle>/post/<rkey>` deep link for
    /// the "View on Bluesky" affordance in PostDetailView.
    public var bskyAppURL: URL? {
        guard uri.hasPrefix("at://") else { return nil }
        let parts = uri.dropFirst("at://".count).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let actor = String(parts[0])         // did:plc:... — bsky.app accepts DIDs
        let collection = String(parts[1])
        let rkey = String(parts[2])
        switch collection {
        case "app.bsky.feed.post":
            return URL(string: "https://bsky.app/profile/\(actor)/post/\(rkey)")
        default:
            // Likes and reposts also live on the user's profile but
            // bsky.app doesn't have a stable per-record URL for them.
            return URL(string: "https://bsky.app/profile/\(actor)")
        }
    }

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
        deletionURI: String? = nil,
        contentType: ContentType,
        text: String? = nil,
        createdAt: Date? = nil,
        likeCount: Int = 0,
        repostCount: Int = 0,
        replyCount: Int = 0,
        media: [MediaPreview] = [],
        linkCard: LinkCard? = nil,
        textLinks: [TextLink] = [],
        parentReplyURI: String? = nil
    ) {
        self.uri = uri
        self.deletionURI = deletionURI ?? (contentType.isOwnRecord ? uri : nil)
        self.cid = cid
        self.contentType = contentType
        self.text = text
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.media = media
        self.linkCard = linkCard
        self.textLinks = textLinks
        self.parentReplyURI = parentReplyURI
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

private extension ContentType {
    var isOwnRecord: Bool {
        self == .posts || self == .replies
    }
}

/// Engagement score formula. Lifted from `reference/python/models.py:51-60`.
public enum EngagementScore {
    public static func compute(likes: Int, reposts: Int, replies: Int) -> Double {
        Double(likes) + 2.0 * Double(reposts) + 2.5 * Double(replies)
    }
}

/// One image or video attached to a post. We carry the thumbnail URL
/// for inline rendering, the fullsize URL for the lightbox, and the
/// alt text for accessibility + search + lightbox caption.
public struct MediaPreview: Hashable, Sendable, Codable {
    public let kind: Kind
    public let thumbnailURL: URL?
    public let fullsizeURL: URL?
    public let alt: String?

    public enum Kind: String, Sendable, Codable {
        case image
        case video
    }

    public init(
        kind: Kind,
        thumbnailURL: URL? = nil,
        fullsizeURL: URL? = nil,
        alt: String? = nil
    ) {
        self.kind = kind
        self.thumbnailURL = thumbnailURL
        self.fullsizeURL = fullsizeURL ?? thumbnailURL  // fallback when not provided
        self.alt = alt?.isEmpty == false ? alt : nil
    }
}

/// External link card on a post (`app.bsky.embed.external`). Renders
/// as a tappable card showing the destination's title, description,
/// and thumbnail. Tapping opens the URL in Safari.
public struct LinkCard: Hashable, Sendable, Codable {
    public let url: URL
    public let title: String?
    public let summary: String?
    public let thumbnailURL: URL?

    public init(url: URL, title: String? = nil, summary: String? = nil, thumbnailURL: URL? = nil) {
        self.url = url
        self.title = title
        self.summary = summary
        self.thumbnailURL = thumbnailURL
    }
}

/// One tappable URL range inside a post's text body. Decoded from the
/// post's richtext facets — Bluesky stores URL annotations as UTF-8
/// byte ranges + a destination URI rather than embedded in the text.
public struct TextLink: Hashable, Sendable, Codable {
    public let url: URL
    public let byteStart: Int
    public let byteEnd: Int

    public init(url: URL, byteStart: Int, byteEnd: Int) {
        self.url = url
        self.byteStart = byteStart
        self.byteEnd = byteEnd
    }
}
