import Foundation

/// AT Protocol XRPC response shapes. Only the fields skymarshal-ios
/// actually reads. The full lexicon has many more — they're not in scope.

public struct Session: Codable, Sendable, Equatable {
    public let did: String
    public let handle: String
    public let accessJwt: String
    public let refreshJwt: String

    public init(did: String, handle: String, accessJwt: String, refreshJwt: String) {
        self.did = did
        self.handle = handle
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt
    }
}

/// `app.bsky.feed.getAuthorFeed` response.
public struct AuthorFeedResponse: Decodable, Sendable {
    public let feed: [FeedViewPost]
    public let cursor: String?
}

public struct FeedViewPost: Decodable, Sendable {
    public let post: PostView
    public let reply: ReplyRef?
    public let reason: ReasonRepost?
}

public struct PostView: Decodable, Sendable {
    public let uri: String
    public let cid: String
    public let author: ProfileViewBasic
    public let record: PostRecord?
    public let likeCount: Int?
    public let repostCount: Int?
    public let replyCount: Int?
    public let indexedAt: String?
    public let embed: PostEmbedView?
}

/// Decoded view of an `app.bsky.embed.*` view object. Each embed type
/// is a different `$type` and carries different fields. We only need
/// the bits relevant to "is there media?" and "what's the alt text?" —
/// every field here is optional so unknown embed shapes decode cleanly
/// to a mostly-nil struct rather than failing the whole post.
public struct PostEmbedView: Decodable, Sendable {
    public let type: String?
    public let images: [EmbedImage]?
    public let video: EmbedVideo?
    public let media: PostEmbedMedia?       // recordWithMedia → media → {images, video}
    public let external: EmbedExternal?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case images, video, media, external
    }
}

/// Inner `media` object on `app.bsky.embed.recordWithMedia#view`.
public struct PostEmbedMedia: Decodable, Sendable {
    public let images: [EmbedImage]?
    public let video: EmbedVideo?
}

public struct EmbedImage: Decodable, Sendable {
    public let alt: String?
    public let thumb: String?
    public let fullsize: String?
    public let aspectRatio: AspectRatio?
}

public struct AspectRatio: Decodable, Sendable {
    public let width: Int
    public let height: Int
}

public struct EmbedVideo: Decodable, Sendable {
    public let alt: String?
    public let playlist: String?
}

public struct EmbedExternal: Decodable, Sendable {
    public let external: ExternalLink?
}

public struct ExternalLink: Decodable, Sendable {
    public let uri: String?
    public let title: String?
    public let description: String?
    public let thumb: String?
}

public struct ProfileViewBasic: Decodable, Sendable {
    public let did: String
    public let handle: String
    public let displayName: String?
}

public struct PostRecord: Decodable, Sendable {
    public let text: String?
    public let createdAt: String?
    public let reply: ReplyRef?
    public let facets: [Facet]?

    enum CodingKeys: String, CodingKey {
        case text, createdAt, reply, facets
    }
}

/// `app.bsky.richtext.facet` — annotation on a UTF-8 byte range of
/// post text. Used for inline links, mentions, hashtags. We only
/// surface the link facet for now (mentions and hashtags are
/// out of scope for content management).
public struct Facet: Decodable, Sendable {
    public let index: FacetIndex
    public let features: [FacetFeature]

    public struct FacetIndex: Decodable, Sendable {
        public let byteStart: Int
        public let byteEnd: Int
    }

    public struct FacetFeature: Decodable, Sendable {
        public let type: String
        public let uri: String?      // present on #link
        public let did: String?      // present on #mention
        public let tag: String?      // present on #tag

        enum CodingKeys: String, CodingKey {
            case type = "$type"
            case uri, did, tag
        }
    }
}

public struct ReplyRef: Decodable, Sendable {
    public let parent: StrongRef?
    public let root: StrongRef?
}

public struct StrongRef: Decodable, Sendable {
    public let uri: String
    public let cid: String?
}

public struct ReasonRepost: Decodable, Sendable {
    public let by: ProfileViewBasic?
    public let indexedAt: String?
}

/// `app.bsky.feed.getActorLikes` response — same shape as feed.
public typealias LikesResponse = AuthorFeedResponse

/// `app.bsky.graph.getFollows` response — list of profiles the user follows.
public struct GetFollowsResponse: Decodable, Sendable {
    public let follows: [BskyProfile]
    public let cursor: String?
}

/// `app.bsky.actor.getProfiles` response — batch of detailed profiles.
public struct GetProfilesResponse: Decodable, Sendable {
    public let profiles: [BskyProfile]
}

/// `app.bsky.feed.getLikes` response — who liked a specific post.
public struct GetLikesResponse: Decodable, Sendable {
    public let likes: [LikeRecord]
    public let cursor: String?

    public struct LikeRecord: Decodable, Sendable {
        public let actor: BskyProfile
        public let createdAt: String?
        public let indexedAt: String?
    }
}

/// `app.bsky.feed.getRepostedBy` response — who reposted a post.
public struct GetRepostedByResponse: Decodable, Sendable {
    public let repostedBy: [BskyProfile]
    public let cursor: String?
}

/// Type-erased decode of arbitrary fields we don't model.
/// Lets us decode `embed` without committing to its full shape.
public struct AnyDecodable: Decodable, Sendable {
    public let raw: Data?
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.raw = try? container.decode(Data.self)
    }
}
