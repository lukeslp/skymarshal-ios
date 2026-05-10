import Foundation
import SwiftData

/// SwiftData @Model definitions for the three MVP tables. Mirror the
/// IndexedDB stores in `reference/web/skymarshal/database/schema.ts`
/// (`contentItems`, `engagementCache`, `userSettings`). The other five
/// stores (`searchHistory`, `backups`, `carFiles`, `bookmarks`,
/// `growthSnapshots`) are intentionally skipped for the MVP.

@available(iOS 17, *)
@Model
public final class ContentItemRecord {
    @Attribute(.unique) public var uri: String
    public var cid: String
    public var contentTypeRaw: String
    public var text: String?
    public var createdAt: Date?
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var hasMedia: Bool
    public var ownerHandle: String
    /// When this row was last written. Used by the cold-start
    /// "Last scanned 3 hours ago" hint. Defaults to `.distantPast`
    /// for the lightweight migration so existing-but-empty stores
    /// don't blow up on a missing-attribute decode.
    public var scannedAt: Date

    public init(
        uri: String,
        cid: String,
        contentType: ContentType,
        text: String? = nil,
        createdAt: Date? = nil,
        likeCount: Int = 0,
        repostCount: Int = 0,
        replyCount: Int = 0,
        hasMedia: Bool = false,
        ownerHandle: String,
        scannedAt: Date = Date()
    ) {
        self.uri = uri
        self.cid = cid
        self.contentTypeRaw = contentType.rawValue
        self.text = text
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.hasMedia = hasMedia
        self.ownerHandle = ownerHandle
        self.scannedAt = scannedAt
    }

    public var contentType: ContentType {
        ContentType(rawValue: contentTypeRaw) ?? .posts
    }

    public func toContentItem() -> ContentItem {
        // SwiftData store doesn't yet persist the full media list — when
        // the cache layer lands, decode `mediaJSON` here. For now the
        // round-trip preserves only `hasMedia` as a single flag, which
        // is good enough to power the media filter on cached items.
        ContentItem(
            uri: uri,
            cid: cid,
            contentType: contentType,
            text: text,
            createdAt: createdAt,
            likeCount: likeCount,
            repostCount: repostCount,
            replyCount: replyCount,
            media: hasMedia ? [MediaPreview(kind: .image)] : []
        )
    }
}

@available(iOS 17, *)
@Model
public final class EngagementCacheRecord {
    @Attribute(.unique) public var uri: String
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var cachedAt: Date
    public var ttlSeconds: TimeInterval

    public init(
        uri: String,
        likeCount: Int,
        repostCount: Int,
        replyCount: Int,
        cachedAt: Date = Date(),
        ttlSeconds: TimeInterval
    ) {
        self.uri = uri
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.cachedAt = cachedAt
        self.ttlSeconds = ttlSeconds
    }

    public var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > ttlSeconds
    }
}

@available(iOS 17, *)
@Model
public final class UserSettingsRecord {
    @Attribute(.unique) public var handle: String
    public var downloadLimitDefault: Int
    public var batchSize: Int
    public var fetchOrderRaw: String
    public var lastSessionAccessJwt: String?
    public var lastSessionRefreshJwt: String?
    public var lastSessionDid: String?

    public init(
        handle: String,
        downloadLimitDefault: Int = 500,
        batchSize: Int = 100,
        fetchOrder: String = "newest",
        lastSessionAccessJwt: String? = nil,
        lastSessionRefreshJwt: String? = nil,
        lastSessionDid: String? = nil
    ) {
        self.handle = handle
        self.downloadLimitDefault = downloadLimitDefault
        self.batchSize = batchSize
        self.fetchOrderRaw = fetchOrder
        self.lastSessionAccessJwt = lastSessionAccessJwt
        self.lastSessionRefreshJwt = lastSessionRefreshJwt
        self.lastSessionDid = lastSessionDid
    }
}

/// Cached AnalyzedAccount from a Followers-tab scan. Stores both the
/// source profile fields AND the scored output — gives instant
/// cold-start UI without recomputing on every read, while still
/// keeping enough source data to re-render or re-score later.
///
/// Keyed by `compositeKey = "<ownerHandle>|<did>"` for per-handle
/// isolation on a single `@Attribute(.unique)` column. Composing
/// uniqueness across columns isn't a SwiftData primitive, and a
/// relationship to UserSettingsRecord would introduce save-order
/// coupling we don't need.
@available(iOS 17, *)
@Model
public final class AnalyzedAccountRecord {
    @Attribute(.unique) public var compositeKey: String

    // Identity
    public var did: String
    public var handle: String
    public var ownerHandle: String                   // who scanned

    // Profile (mirror of BskyProfile fields used by the detail view)
    public var displayName: String?
    public var profileDescription: String?           // `description` clashes
    public var avatar: String?
    public var banner: String?
    public var followersCount: Int
    public var followsCount: Int
    public var postsCount: Int
    public var profileCreatedAt: String              // ISO8601 raw
    public var followingURI: String?                 // viewer.following — needed for unfollow
    public var followedByURI: String?                // viewer.followedBy — mutual signal
    public var muted: Bool
    public var blockedBy: Bool
    public var blocking: String?

    // Scored output (cache of analyzer's verdict)
    public var ratio: Double
    public var botScore: Double
    public var botFlagsJSON: String                  // [String] JSON
    public var influenceScore: Double
    public var influenceTierRaw: String
    public var accountAgeDays: Int
    public var postsPerDay: Double
    public var profileCompleteness: Double
    public var lastPostDate: Date?
    public var daysSinceLastPost: Int?
    public var isInactive: Bool
    public var isDeleted: Bool
    public var isMutual: Bool
    public var engagementScore: Double
    public var interactedRecentlyRaw: Int            // -1 = unknown, 0 = no, 1 = yes

    public var scannedAt: Date

    public init(account: AnalyzedAccount, ownerHandle: String, scannedAt: Date = Date()) {
        self.compositeKey = "\(ownerHandle)|\(account.did)"
        self.did = account.did
        self.handle = account.handle
        self.ownerHandle = ownerHandle

        let p = account.profile
        self.displayName = p.displayName
        self.profileDescription = p.description
        self.avatar = p.avatar
        self.banner = p.banner
        self.followersCount = p.followersCount
        self.followsCount = p.followsCount
        self.postsCount = p.postsCount
        self.profileCreatedAt = p.createdAt
        self.followingURI = p.viewer?.following
        self.followedByURI = p.viewer?.followedBy
        self.muted = p.viewer?.muted ?? false
        self.blockedBy = p.viewer?.blockedBy ?? false
        self.blocking = p.viewer?.blocking

        self.ratio = account.ratio
        self.botScore = account.botScore
        self.botFlagsJSON = (try? String(
            data: JSONEncoder().encode(account.botFlags), encoding: .utf8
        )) ?? "[]"
        self.influenceScore = account.influenceScore
        self.influenceTierRaw = account.influenceTier.rawValue
        self.accountAgeDays = account.accountAgeDays
        self.postsPerDay = account.postsPerDay
        self.profileCompleteness = account.profileCompleteness
        self.lastPostDate = account.lastPostDate
        self.daysSinceLastPost = account.daysSinceLastPost
        self.isInactive = account.isInactive
        self.isDeleted = account.isDeleted
        self.isMutual = account.isMutual
        self.engagementScore = account.engagementScore
        switch account.interactedRecently {
        case .some(true):  self.interactedRecentlyRaw = 1
        case .some(false): self.interactedRecentlyRaw = 0
        case .none:        self.interactedRecentlyRaw = -1
        }

        self.scannedAt = scannedAt
    }

    /// Mutate-in-place equivalent of the init — used by the upsert
    /// path so we don't churn primary keys.
    public func update(from account: AnalyzedAccount, scannedAt: Date) {
        let p = account.profile
        self.handle = account.handle
        self.displayName = p.displayName
        self.profileDescription = p.description
        self.avatar = p.avatar
        self.banner = p.banner
        self.followersCount = p.followersCount
        self.followsCount = p.followsCount
        self.postsCount = p.postsCount
        self.profileCreatedAt = p.createdAt
        self.followingURI = p.viewer?.following
        self.followedByURI = p.viewer?.followedBy
        self.muted = p.viewer?.muted ?? false
        self.blockedBy = p.viewer?.blockedBy ?? false
        self.blocking = p.viewer?.blocking
        self.ratio = account.ratio
        self.botScore = account.botScore
        self.botFlagsJSON = (try? String(
            data: JSONEncoder().encode(account.botFlags), encoding: .utf8
        )) ?? "[]"
        self.influenceScore = account.influenceScore
        self.influenceTierRaw = account.influenceTier.rawValue
        self.accountAgeDays = account.accountAgeDays
        self.postsPerDay = account.postsPerDay
        self.profileCompleteness = account.profileCompleteness
        self.lastPostDate = account.lastPostDate
        self.daysSinceLastPost = account.daysSinceLastPost
        self.isInactive = account.isInactive
        self.isDeleted = account.isDeleted
        self.isMutual = account.isMutual
        self.engagementScore = account.engagementScore
        switch account.interactedRecently {
        case .some(true):  self.interactedRecentlyRaw = 1
        case .some(false): self.interactedRecentlyRaw = 0
        case .none:        self.interactedRecentlyRaw = -1
        }
        self.scannedAt = scannedAt
    }

    public func toAnalyzedAccount() -> AnalyzedAccount {
        let viewer: BskyProfile.ViewerState?
        if muted || blockedBy || blocking != nil || followingURI != nil || followedByURI != nil {
            viewer = .init(
                muted: muted ? true : nil,
                blockedBy: blockedBy ? true : nil,
                blocking: blocking,
                following: followingURI,
                followedBy: followedByURI
            )
        } else {
            viewer = nil
        }

        let profile = BskyProfile(
            did: did,
            handle: handle,
            displayName: displayName,
            description: profileDescription,
            avatar: avatar,
            banner: banner,
            followersCount: followersCount,
            followsCount: followsCount,
            postsCount: postsCount,
            createdAt: profileCreatedAt,
            labels: nil,
            viewer: viewer
        )

        let flags: [String] = (try? JSONDecoder().decode(
            [String].self,
            from: Data(botFlagsJSON.utf8)
        )) ?? []

        let interacted: Bool?
        switch interactedRecentlyRaw {
        case 1:  interacted = true
        case 0:  interacted = false
        default: interacted = nil
        }

        return AnalyzedAccount(
            profile: profile,
            ratio: ratio,
            botScore: botScore,
            botFlags: flags,
            influenceScore: influenceScore,
            influenceTier: InfluenceTier(rawValue: influenceTierRaw) ?? .nano,
            accountAgeDays: accountAgeDays,
            postsPerDay: postsPerDay,
            profileCompleteness: profileCompleteness,
            lastPostDate: lastPostDate,
            daysSinceLastPost: daysSinceLastPost,
            isInactive: isInactive,
            isDeleted: isDeleted,
            isMutual: isMutual,
            engagementScore: engagementScore,
            interactedRecently: interacted
        )
    }
}

/// SwiftData container factory for the app and tests.
@available(iOS 17, *)
public enum SkymarshalSchema {
    public static let allModels: [any PersistentModel.Type] = [
        ContentItemRecord.self,
        EngagementCacheRecord.self,
        UserSettingsRecord.self,
        AnalyzedAccountRecord.self,
    ]

    public static func makeContainer(
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
