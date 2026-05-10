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
    public let embed: AnyDecodable?
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

    enum CodingKeys: String, CodingKey {
        case text, createdAt, reply
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

/// Type-erased decode of arbitrary fields we don't model.
/// Lets us decode `embed` without committing to its full shape.
public struct AnyDecodable: Decodable, Sendable {
    public let raw: Data?
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.raw = try? container.decode(Data.self)
    }
}
