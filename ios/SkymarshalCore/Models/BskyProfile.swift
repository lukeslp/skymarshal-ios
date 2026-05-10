import Foundation

/// Detailed Bluesky profile fetched from `app.bsky.actor.getProfiles`.
/// The fields the bluescreen analyzer needs to score an account.
public struct BskyProfile: Hashable, Sendable, Codable, Identifiable {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let description: String?
    public let avatar: String?
    public let banner: String?
    public let followersCount: Int
    public let followsCount: Int
    public let postsCount: Int
    public let createdAt: String          // ISO8601 from XRPC
    public let labels: [Label]?
    public let viewer: ViewerState?

    public var id: String { did }

    public init(
        did: String,
        handle: String,
        displayName: String? = nil,
        description: String? = nil,
        avatar: String? = nil,
        banner: String? = nil,
        followersCount: Int = 0,
        followsCount: Int = 0,
        postsCount: Int = 0,
        createdAt: String = "",
        labels: [Label]? = nil,
        viewer: ViewerState? = nil
    ) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.description = description
        self.avatar = avatar
        self.banner = banner
        self.followersCount = followersCount
        self.followsCount = followsCount
        self.postsCount = postsCount
        self.createdAt = createdAt
        self.labels = labels
        self.viewer = viewer
    }

    enum CodingKeys: String, CodingKey {
        case did, handle, displayName, description, avatar, banner
        case followersCount, followsCount, postsCount, createdAt, labels, viewer
    }

    /// Custom decoder so `app.bsky.graph.getFollows` (which returns
    /// `ProfileView`, missing `followersCount` / `followsCount` /
    /// `postsCount` / `createdAt`) decodes cleanly. The hydration phase
    /// in `FollowerService.scan` backfills the real values via
    /// `app.bsky.actor.getProfiles` (which returns `ProfileViewDetailed`).
    /// Without this tolerance, the whole `[BskyProfile]` array fails to
    /// decode on the first follow and the scan silently dies.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.did = try c.decode(String.self, forKey: .did)
        self.handle = try c.decode(String.self, forKey: .handle)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
        self.banner = try c.decodeIfPresent(String.self, forKey: .banner)
        self.followersCount = try c.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        self.followsCount = try c.decodeIfPresent(Int.self, forKey: .followsCount) ?? 0
        self.postsCount = try c.decodeIfPresent(Int.self, forKey: .postsCount) ?? 0
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.labels = try c.decodeIfPresent([Label].self, forKey: .labels)
        self.viewer = try c.decodeIfPresent(ViewerState.self, forKey: .viewer)
    }

    public struct Label: Hashable, Sendable, Codable {
        public let val: String
    }

    public struct ViewerState: Hashable, Sendable, Codable {
        public let muted: Bool?
        public let blockedBy: Bool?
        public let blocking: String?
        public let following: String?       // at:// URI of YOUR follow record on them
        public let followedBy: String?      // at:// URI of THEIR follow record on you (= mutual)

        public init(
            muted: Bool? = nil,
            blockedBy: Bool? = nil,
            blocking: String? = nil,
            following: String? = nil,
            followedBy: String? = nil
        ) {
            self.muted = muted
            self.blockedBy = blockedBy
            self.blocking = blocking
            self.following = following
            self.followedBy = followedBy
        }
    }

    /// Account-creation date parsed from `createdAt`. Returns nil for malformed strings.
    public var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
}
