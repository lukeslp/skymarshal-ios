import Foundation
import SwiftData

/// SwiftData @Model definitions for the three MVP tables. Mirror the
/// IndexedDB stores in `reference/web/skymarshal/database/schema.ts`
/// (`contentItems`, `engagementCache`, `userSettings`). The other five
/// stores (`searchHistory`, `backups`, `carFiles`, `bookmarks`,
/// `growthSnapshots`) are intentionally skipped for the MVP.
///
/// **Visualization graph** tables (`GraphSnapshotRecord`, `GraphNodeRecord`,
/// `GraphEdgeRecord`, `GraphCheckpointRecord`) materialize account/post
/// relationship views with explicit completeness metadata for UI honesty.

@available(iOS 17, *)
@Model
public final class ContentItemRecord {
    @Attribute(.unique) public var compositeKey: String
    public var itemID: String
    public var uri: String
    public var deletionURI: String?
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
    /// at:// URI of the parent post, set only for replies. Powers
    /// the InteractionHistoryView "outgoing replies" filter without
    /// extra fetches. Lightweight migration — nil-default for any
    /// existing rows; gets populated on next forceRefresh.
    public var parentReplyURI: String?
    /// Author handle of the liked/reposted subject at scan time. Nil for
    /// posts/replies and for rows written before this field existed.
    public var subjectAuthorHandle: String?
    /// True for a ghost like — a like whose subject post no longer resolves.
    /// Lightweight migration: `false` default for rows written before this
    /// field existed, which is correct, since those rows all came from
    /// `getActorLikes` and therefore hydrated by definition.
    public var subjectUnresolved: Bool = false

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
        hasMedia: Bool = false,
        ownerHandle: String,
        scannedAt: Date = Date(),
        parentReplyURI: String? = nil,
        subjectAuthorHandle: String? = nil,
        subjectUnresolved: Bool = false
    ) {
        self.compositeKey = Self.makeCompositeKey(
            ownerHandle: ownerHandle,
            contentType: contentType,
            uri: uri
        )
        self.itemID = "\(contentType.rawValue)|\(uri)"
        self.uri = uri
        self.deletionURI = deletionURI
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
        self.parentReplyURI = parentReplyURI
        self.subjectAuthorHandle = subjectAuthorHandle
        self.subjectUnresolved = subjectUnresolved
    }

    public var contentType: ContentType {
        ContentType(rawValue: contentTypeRaw) ?? .posts
    }

    public static func makeCompositeKey(
        ownerHandle: String,
        contentType: ContentType,
        uri: String
    ) -> String {
        "\(ownerHandle)|\(contentType.rawValue)|\(uri)"
    }

    public func toContentItem() -> ContentItem {
        // SwiftData store doesn't yet persist the full media list — when
        // the cache layer lands, decode `mediaJSON` here. For now the
        // round-trip preserves only `hasMedia` as a single flag, which
        // is good enough to power the media filter on cached items.
        ContentItem(
            uri: uri,
            cid: cid,
            deletionURI: deletionURI,
            contentType: contentType,
            text: text,
            createdAt: createdAt,
            likeCount: likeCount,
            repostCount: repostCount,
            replyCount: replyCount,
            media: hasMedia ? [MediaPreview(kind: .image)] : [],
            parentReplyURI: parentReplyURI,
            subjectAuthorHandle: subjectAuthorHandle,
            subjectUnresolved: subjectUnresolved
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

    /// Whether the AppView read of this account's activity was reliable.
    /// Stored as the `ActivityReadState` raw value. Lightweight
    /// migration mirrors `whitelisted`: existing rows decode to
    /// `"unknown"` (the conservative default) on read because the SwiftData
    /// property default fills any column the old schema never wrote.
    public var activityReadStateRaw: String = ActivityReadState.unknown.rawValue

    /// User-applied "this isn't an automated account" override.
    /// Survives re-scans because we upsert by compositeKey and only
    /// the analyzer-derived fields get refreshed in `update(from:)`.
    /// Lightweight migration: existing rows get `false` on read.
    public var whitelisted: Bool = false

    /// Lazily-computed per-account ghost verdict, stored as the
    /// `GhostVerdict` raw value or `nil` when never checked. Lightweight
    /// migration mirrors `activityReadStateRaw`: existing rows decode to
    /// `nil` (not-yet-checked) because the optional property default
    /// fills any column the old schema never wrote. Re-scans preserve it
    /// (only analyzer-derived fields refresh in `update(from:)`), so a
    /// once-computed verdict survives until explicitly recomputed.
    public var ghostVerdictRaw: String? = nil

    /// Inbound engagement count recorded with the ghost check. `nil`
    /// when never checked. Back-compat default `nil`.
    public var reciprocityGapInboundCount: Int? = nil

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
        self.activityReadStateRaw = account.activityReadState.rawValue
        self.whitelisted = account.userWhitelisted
        self.ghostVerdictRaw = account.ghostVerdict?.rawValue
        self.reciprocityGapInboundCount = account.reciprocityGapInboundCount

        self.scannedAt = scannedAt
    }

    /// Mutate-in-place equivalent of the init — used by the upsert
    /// path so we don't churn primary keys. **Whitelist is preserved**
    /// across re-scans: the user's override is sticky, not analyzer-
    /// derived. If a future caller needs to clear it, do so explicitly.
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
        self.activityReadStateRaw = account.activityReadState.rawValue
        // Ghost / reciprocity are lazily computed per-account and sticky
        // across re-scans (a fresh analyzer pass carries `nil`). Only
        // overwrite when the incoming account actually carries a value,
        // so a once-computed verdict survives the next scan — same
        // preserve-on-rescan posture as `whitelisted`.
        if let verdict = account.ghostVerdict {
            self.ghostVerdictRaw = verdict.rawValue
        }
        if let inbound = account.reciprocityGapInboundCount {
            self.reciprocityGapInboundCount = inbound
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

        let readState = ActivityReadState(rawValue: activityReadStateRaw) ?? .unknown
        let verdict = ghostVerdictRaw.flatMap(GhostVerdict.init(rawValue:))

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
            interactedRecently: interacted,
            activityReadState: readState,
            userWhitelisted: whitelisted,
            ghostVerdict: verdict,
            reciprocityGapInboundCount: reciprocityGapInboundCount
        )
    }

    /// Recompute analyzer-derived fields on rows written by versions that
    /// treated `handle.invalid` as deleted. Only the affected row changes;
    /// user whitelist and lazy ghost data remain sticky through `update`.
    /// Returns true when the persisted record was contaminated and repaired.
    @discardableResult
    public func repairUnverifiedHandleClassificationIfNeeded() -> Bool {
        guard handle == "handle.invalid" else { return false }

        let cached = toAnalyzedAccount()
        let recomputed = BluescreenAnalyzer.analyze(
            profile: cached.profile,
            lastPostDate: cached.lastPostDate,
            engagementScore: cached.engagementScore,
            interactedRecently: cached.interactedRecently,
            activityReadState: cached.activityReadState
        )
        let needsRepair = cached.botScore != recomputed.botScore
            || cached.botFlags != recomputed.botFlags
            || cached.isDeleted != recomputed.isDeleted
            || cached.isInactive != recomputed.isInactive
        guard needsRepair else { return false }

        update(from: recomputed, scannedAt: scannedAt)
        return true
    }
}

/// Saved search preset for the Content tab — keyword + structured filters + sort.
@available(iOS 17, *)
@Model
public final class SavedSearchPresetRecord {
    @Attribute(.unique) public var id: UUID
    public var ownerHandle: String
    public var name: String
    /// JSON-encoded ``SearchRequest``.
    public var searchRequestJSON: String
    /// ``ContentSortOrder`` raw value.
    public var sortOrderRaw: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        ownerHandle: String,
        name: String,
        searchRequestJSON: String,
        sortOrderRaw: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerHandle = ownerHandle
        self.name = name
        self.searchRequestJSON = searchRequestJSON
        self.sortOrderRaw = sortOrderRaw
        self.createdAt = createdAt
    }

    public func decodedRequest() throws -> SearchRequest {
        guard let data = searchRequestJSON.data(using: .utf8) else {
            throw NSError(domain: "Skymarshal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid saved search payload"])
        }
        return try JSONDecoder().decode(SearchRequest.self, from: data)
    }

    public var contentSortOrder: ContentSortOrder {
        ContentSortOrder(rawValue: sortOrderRaw) ?? .newestCreated
    }
}

// MARK: - Visualization graph (materialized snapshots)

/// Completeness of a graph snapshot — UI must never imply full coverage when `.partial`.
@available(iOS 17, *)
public enum GraphCompletenessState: String, Sendable, Codable, CaseIterable {
    case unknown
    case partial
    case complete
}

/// What produced this snapshot (drives hub tabs and invalidation).
@available(iOS 17, *)
public enum GraphSnapshotKind: String, Sendable, Codable, CaseIterable {
    case accountGraph
    case interactionGraph
    case postGraph
    case timelineHeatmap
}

@available(iOS 17, *)
@Model
public final class GraphSnapshotRecord {
    @Attribute(.unique) public var id: UUID
    public var ownerHandle: String
    public var kindRaw: String
    public var completenessRaw: String
    public var generatedAt: Date
    /// Optional JSON blob for hub-specific metrics (counts, caps hit, etc.).
    public var summaryJSON: String?

    public init(
        id: UUID = UUID(),
        ownerHandle: String,
        kind: GraphSnapshotKind,
        completeness: GraphCompletenessState,
        generatedAt: Date = Date(),
        summaryJSON: String? = nil
    ) {
        self.id = id
        self.ownerHandle = ownerHandle
        self.kindRaw = kind.rawValue
        self.completenessRaw = completeness.rawValue
        self.generatedAt = generatedAt
        self.summaryJSON = summaryJSON
    }

    public var kind: GraphSnapshotKind {
        GraphSnapshotKind(rawValue: kindRaw) ?? .accountGraph
    }

    public var completeness: GraphCompletenessState {
        GraphCompletenessState(rawValue: completenessRaw) ?? .unknown
    }
}

@available(iOS 17, *)
@Model
public final class GraphNodeRecord {
    @Attribute(.unique) public var compositeKey: String
    public var ownerHandle: String
    public var snapshotId: UUID
    /// Stable node identifier (typically DID or AT URI).
    public var nodeId: String
    public var displayLabel: String?
    public var nodeKindRaw: String
    public var completenessRaw: String
    public var lastSyncedAt: Date

    public init(
        ownerHandle: String,
        snapshotId: UUID,
        nodeId: String,
        displayLabel: String? = nil,
        nodeKind: String = "account",
        completeness: GraphCompletenessState = .unknown,
        lastSyncedAt: Date = Date()
    ) {
        self.compositeKey = Self.makeCompositeKey(
            ownerHandle: ownerHandle,
            snapshotId: snapshotId,
            nodeId: nodeId
        )
        self.ownerHandle = ownerHandle
        self.snapshotId = snapshotId
        self.nodeId = nodeId
        self.displayLabel = displayLabel
        self.nodeKindRaw = nodeKind
        self.completenessRaw = completeness.rawValue
        self.lastSyncedAt = lastSyncedAt
    }

    public static func makeCompositeKey(ownerHandle: String, snapshotId: UUID, nodeId: String) -> String {
        "\(ownerHandle)|\(snapshotId.uuidString)|\(nodeId)"
    }

    public var completeness: GraphCompletenessState {
        GraphCompletenessState(rawValue: completenessRaw) ?? .unknown
    }
}

@available(iOS 17, *)
@Model
public final class GraphEdgeRecord {
    @Attribute(.unique) public var compositeKey: String
    public var ownerHandle: String
    public var snapshotId: UUID
    public var sourceNodeId: String
    public var targetNodeId: String
    public var edgeTypeRaw: String
    public var weight: Double
    public var provenanceJSON: String?
    public var createdAt: Date

    public init(
        ownerHandle: String,
        snapshotId: UUID,
        sourceNodeId: String,
        targetNodeId: String,
        edgeType: String,
        weight: Double = 1,
        provenanceJSON: String? = nil,
        createdAt: Date = Date()
    ) {
        self.compositeKey = Self.makeCompositeKey(
            ownerHandle: ownerHandle,
            snapshotId: snapshotId,
            sourceNodeId: sourceNodeId,
            targetNodeId: targetNodeId,
            edgeType: edgeType
        )
        self.ownerHandle = ownerHandle
        self.snapshotId = snapshotId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.edgeTypeRaw = edgeType
        self.weight = weight
        self.provenanceJSON = provenanceJSON
        self.createdAt = createdAt
    }

    public static func makeCompositeKey(
        ownerHandle: String,
        snapshotId: UUID,
        sourceNodeId: String,
        targetNodeId: String,
        edgeType: String
    ) -> String {
        "\(ownerHandle)|\(snapshotId.uuidString)|\(sourceNodeId)|\(targetNodeId)|\(edgeType)"
    }
}

/// Rows fetched by an in-progress archive refresh. These remain isolated from
/// the committed cache until both archive endpoints finish successfully.
@available(iOS 17, *)
@Model
public final class ContentRefreshStagingRecord {
    @Attribute(.unique) public var compositeKey: String
    public var generationID: String
    public var ownerHandle: String
    public var uri: String
    public var deletionURI: String?
    public var cid: String
    public var contentTypeRaw: String
    public var text: String?
    public var createdAt: Date?
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var hasMedia: Bool
    public var parentReplyURI: String?
    public var subjectAuthorHandle: String?
    public var subjectUnresolved: Bool = false

    public init(item: ContentItem, ownerHandle: String, generationID: String) {
        self.compositeKey = "\(ownerHandle)|\(generationID)|\(item.id)"
        self.generationID = generationID
        self.ownerHandle = ownerHandle
        self.uri = item.uri
        self.deletionURI = item.deletionURI
        self.cid = item.cid
        self.contentTypeRaw = item.contentType.rawValue
        self.text = item.text
        self.createdAt = item.createdAt
        self.likeCount = item.likeCount
        self.repostCount = item.repostCount
        self.replyCount = item.replyCount
        self.hasMedia = item.hasMedia
        self.parentReplyURI = item.parentReplyURI
        self.subjectAuthorHandle = item.subjectAuthorHandle
        self.subjectUnresolved = item.subjectUnresolved
    }

    public func update(from item: ContentItem) {
        deletionURI = item.deletionURI
        cid = item.cid
        text = item.text
        createdAt = item.createdAt
        likeCount = item.likeCount
        repostCount = item.repostCount
        replyCount = item.replyCount
        hasMedia = item.hasMedia
        parentReplyURI = item.parentReplyURI
        subjectAuthorHandle = item.subjectAuthorHandle
        subjectUnresolved = item.subjectUnresolved
    }

    public func toContentItem() -> ContentItem {
        ContentItem(
            uri: uri,
            cid: cid,
            deletionURI: deletionURI,
            contentType: ContentType(rawValue: contentTypeRaw) ?? .posts,
            text: text,
            createdAt: createdAt,
            likeCount: likeCount,
            repostCount: repostCount,
            replyCount: replyCount,
            media: hasMedia ? [MediaPreview(kind: .image)] : [],
            parentReplyURI: parentReplyURI,
            subjectAuthorHandle: subjectAuthorHandle,
            subjectUnresolved: subjectUnresolved
        )
    }
}

/// Pagination resume cursor for ``ContentService.ensureContentLoaded`` —
/// one row per `(ownerHandle, phase)` while a phase is in flight. Rows are
/// deleted when the phase finishes cleanly; any remaining row means a prior
/// load was interrupted and pagination should continue from ``cursor``.
@available(iOS 17, *)
@Model
public final class ArchiveLoadCheckpointRecord {
    @Attribute(.unique) public var scopeKey: String
    public var ownerHandle: String
    /// `posts` or `likes` — matches ``ContentService/LoadProgress/Phase`` archive segments.
    public var phaseRaw: String
    public var cursor: String?
    public var pagesFetched: Int
    public var generationID: String = ""
    public var updatedAt: Date

    public init(
        ownerHandle: String,
        phaseRaw: String,
        cursor: String?,
        pagesFetched: Int,
        generationID: String = "",
        updatedAt: Date = Date()
    ) {
        self.scopeKey = "\(ownerHandle)|\(phaseRaw)"
        self.ownerHandle = ownerHandle
        self.phaseRaw = phaseRaw
        self.cursor = cursor
        self.pagesFetched = pagesFetched
        self.generationID = generationID
        self.updatedAt = updatedAt
    }
}

/// Resume tokens for incremental graph materialization (per owner + logical scope).
@available(iOS 17, *)
@Model
public final class GraphCheckpointRecord {
    @Attribute(.unique) public var scopeKey: String
    public var ownerHandle: String
    public var scopeKindRaw: String
    public var cursorJSON: String?
    public var updatedAt: Date

    public init(
        ownerHandle: String,
        scopeKind: GraphSnapshotKind,
        cursorJSON: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.scopeKey = "\(ownerHandle)|\(scopeKind.rawValue)"
        self.ownerHandle = ownerHandle
        self.scopeKindRaw = scopeKind.rawValue
        self.cursorJSON = cursorJSON
        self.updatedAt = updatedAt
    }

    public var scopeKind: GraphSnapshotKind {
        GraphSnapshotKind(rawValue: scopeKindRaw) ?? .accountGraph
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
        SavedSearchPresetRecord.self,
        GraphSnapshotRecord.self,
        GraphNodeRecord.self,
        GraphEdgeRecord.self,
        GraphCheckpointRecord.self,
        ArchiveLoadCheckpointRecord.self,
        ContentRefreshStagingRecord.self,
    ]

    public static func makeContainer(
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(allModels)
        // Background task launches can race the first creation of
        // Application Support. SwiftData/Core Data then logs
        // "Sandbox access to file-write-create denied" and can fail hard
        // under a tight BG memory/time budget. Ensure the parent exists.
        if !inMemory {
            let fm = FileManager.default
            if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? fm.createDirectory(at: support, withIntermediateDirectories: true)
            }
        }
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
