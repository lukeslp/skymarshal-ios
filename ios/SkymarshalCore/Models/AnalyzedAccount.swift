import Foundation

/// One follower / followed account, scored by the bluescreen analyzer.
/// The output shape mirrors `reference/web/bluescreen/types.ts`
/// `AnalyzedAccount` near-verbatim — the score field semantics are
/// load-bearing and match the user's calibrated sensitivity.
public struct AnalyzedAccount: Hashable, Sendable, Identifiable {
    public let profile: BskyProfile
    public let ratio: Double                 // followers / following (rounded 2dp)
    public let botScore: Double              // 0…1 (rounded 2dp)
    public let botFlags: [String]            // human-readable triggered factors
    public let influenceScore: Double        // log-scale, rounded 2dp
    public let influenceTier: InfluenceTier
    public let accountAgeDays: Int
    public let postsPerDay: Double           // rounded 2dp
    public let profileCompleteness: Double   // 0…1
    public let lastPostDate: Date?
    public let daysSinceLastPost: Int?
    public let isInactive: Bool
    public let isDeleted: Bool
    public let isMutual: Bool
    public let engagementScore: Double
    public let interactedRecently: Bool?
    /// Whether the AppView read of this account's activity was reliable.
    /// `.unknown` (the default) means throttle/gate/error made the
    /// last-post / interaction signals untrustworthy — the cleanup
    /// filters and presets refuse to treat such an account as inactive
    /// or disengaged. Persisted via AnalyzedAccountRecord.activityReadStateRaw.
    public let activityReadState: ActivityReadState
    /// User-applied "this isn't an automated account" override. When
    /// true: the row badge hides regardless of botScore, the stripe
    /// drops the danger/caution branch, and the account is excluded
    /// from the `showBots` filter even at score ≥ 0.6. Persisted via
    /// AnalyzedAccountRecord.whitelisted so the override survives
    /// re-scans.
    public let userWhitelisted: Bool
    /// Per-account ghost classification, computed lazily when the
    /// AccountDetailView opens (never batched over the full follow
    /// graph). `nil` means **not yet checked** — distinct from
    /// `.unknown`, which means we checked but the read was unreadable
    /// (throttled/gated). `.unknown` is fail-safe: a `.unknown` account
    /// is never selectable for bulk cleanup. Persisted via
    /// AnalyzedAccountRecord.ghostVerdictRaw.
    public let ghostVerdict: GhostVerdict?
    /// How many times this account engaged the user (inbound), recorded
    /// alongside the lazy ghost check. `nil` = not yet checked.
    /// Persisted via AnalyzedAccountRecord.reciprocityGapInboundCount.
    public let reciprocityGapInboundCount: Int?

    public init(
        profile: BskyProfile,
        ratio: Double,
        botScore: Double,
        botFlags: [String],
        influenceScore: Double,
        influenceTier: InfluenceTier,
        accountAgeDays: Int,
        postsPerDay: Double,
        profileCompleteness: Double,
        lastPostDate: Date?,
        daysSinceLastPost: Int?,
        isInactive: Bool,
        isDeleted: Bool,
        isMutual: Bool,
        engagementScore: Double,
        interactedRecently: Bool?,
        activityReadState: ActivityReadState = .unknown,
        userWhitelisted: Bool = false,
        ghostVerdict: GhostVerdict? = nil,
        reciprocityGapInboundCount: Int? = nil
    ) {
        self.profile = profile
        self.ratio = ratio
        self.botScore = botScore
        self.botFlags = botFlags
        self.influenceScore = influenceScore
        self.influenceTier = influenceTier
        self.accountAgeDays = accountAgeDays
        self.postsPerDay = postsPerDay
        self.profileCompleteness = profileCompleteness
        self.lastPostDate = lastPostDate
        self.daysSinceLastPost = daysSinceLastPost
        self.isInactive = isInactive
        self.isDeleted = isDeleted
        self.isMutual = isMutual
        self.engagementScore = engagementScore
        self.interactedRecently = interactedRecently
        self.activityReadState = activityReadState
        self.userWhitelisted = userWhitelisted
        self.ghostVerdict = ghostVerdict
        self.reciprocityGapInboundCount = reciprocityGapInboundCount
    }

    public var id: String { profile.did }
    public var did: String { profile.did }
    public var handle: String { profile.handle }

    /// Returns a copy with `userWhitelisted` updated. Used by the
    /// AccountDetailView toggle and the FollowerService whitelist
    /// path — keeps the struct immutable while letting the in-memory
    /// list swap a new value in.
    public func withWhitelist(_ newValue: Bool) -> AnalyzedAccount {
        AnalyzedAccount(
            profile: profile, ratio: ratio, botScore: botScore,
            botFlags: botFlags, influenceScore: influenceScore,
            influenceTier: influenceTier, accountAgeDays: accountAgeDays,
            postsPerDay: postsPerDay, profileCompleteness: profileCompleteness,
            lastPostDate: lastPostDate, daysSinceLastPost: daysSinceLastPost,
            isInactive: isInactive, isDeleted: isDeleted, isMutual: isMutual,
            engagementScore: engagementScore, interactedRecently: interactedRecently,
            activityReadState: activityReadState,
            userWhitelisted: newValue,
            ghostVerdict: ghostVerdict,
            reciprocityGapInboundCount: reciprocityGapInboundCount
        )
    }

    /// Returns a copy with `activityReadState` updated, preserving every
    /// other field. The throttle-safe read path uses this to stamp an
    /// account `.read` or `.unknown` after an activity sweep without
    /// re-running the analyzer.
    public func withActivityReadState(_ newValue: ActivityReadState) -> AnalyzedAccount {
        AnalyzedAccount(
            profile: profile, ratio: ratio, botScore: botScore,
            botFlags: botFlags, influenceScore: influenceScore,
            influenceTier: influenceTier, accountAgeDays: accountAgeDays,
            postsPerDay: postsPerDay, profileCompleteness: profileCompleteness,
            lastPostDate: lastPostDate, daysSinceLastPost: daysSinceLastPost,
            isInactive: isInactive, isDeleted: isDeleted, isMutual: isMutual,
            engagementScore: engagementScore, interactedRecently: interactedRecently,
            activityReadState: newValue,
            userWhitelisted: userWhitelisted,
            ghostVerdict: ghostVerdict,
            reciprocityGapInboundCount: reciprocityGapInboundCount
        )
    }

    /// Returns a copy with the lazily-computed ghost verdict and
    /// inbound reciprocity count stamped on, preserving every other
    /// field. The AccountDetailView `.task` calls this once per account
    /// after the single cheap per-account read, then saves so re-opening
    /// is instant.
    public func withGhostReciprocity(
        verdict: GhostVerdict,
        inboundCount: Int
    ) -> AnalyzedAccount {
        AnalyzedAccount(
            profile: profile, ratio: ratio, botScore: botScore,
            botFlags: botFlags, influenceScore: influenceScore,
            influenceTier: influenceTier, accountAgeDays: accountAgeDays,
            postsPerDay: postsPerDay, profileCompleteness: profileCompleteness,
            lastPostDate: lastPostDate, daysSinceLastPost: daysSinceLastPost,
            isInactive: isInactive, isDeleted: isDeleted, isMutual: isMutual,
            engagementScore: engagementScore, interactedRecently: interactedRecently,
            activityReadState: activityReadState,
            userWhitelisted: userWhitelisted,
            ghostVerdict: verdict,
            reciprocityGapInboundCount: inboundCount
        )
    }
}

/// Persistable per-account ghost classification, surfaced in the detail
/// view. Maps from ``EngagementEngine/GhostVerdict/Classification``
/// (`confirmedGhost`/`engaged`/`unknown`) into a Codable enum the model
/// and SwiftData store can round-trip.
///
/// `.unknown` is the fail-safe state: the read was throttled or gated,
/// so we could not confirm whether the account engages the user. Per the
/// engine's fail-safe contract, `.unknown` is **never** a reason to
/// unfollow and is never selectable for bulk cleanup.
public enum GhostVerdict: String, Sendable, Hashable, Codable, CaseIterable {
    /// Source-side read confirmed: they never engage the user.
    case ghost
    /// They do engage the user (engaged set or source-side hit).
    case engaged
    /// Read was unreliable (throttle/gate) — fail-safe, not a ghost.
    case unknown
}

@available(iOS 17, *)
public extension GhostVerdict {
    /// Map the engine's source-side classification into the persistable
    /// model verdict. `confirmedGhost → .ghost`, `engaged → .engaged`,
    /// `unknown → .unknown` (fail-safe preserved).
    init(_ classification: EngagementEngine.GhostVerdict.Classification) {
        switch classification {
        case .confirmedGhost: self = .ghost
        case .engaged:        self = .engaged
        case .unknown:        self = .unknown
        }
    }
}

public enum InfluenceTier: String, Sendable, Hashable, Codable, CaseIterable {
    case mega       // ≥ 100,000 followers
    case macro      // ≥ 10,000
    case micro      // ≥ 1,000
    case nano       // < 1,000

    public var label: String {
        switch self {
        case .mega:  return "Mega"
        case .macro: return "Macro"
        case .micro: return "Micro"
        case .nano:  return "Nano"
        }
    }
}

/// Aggregate counters returned by ``BluescreenAnalyzer/summarize(_:)``.
public struct ScanSummary: Hashable, Sendable {
    public let totalAnalyzed: Int
    public let badRatio: Int
    public let inactive: Int
    public let deleted: Int
    public let bots: Int
    public let disengaged: Int
    public let mutuals: Int
    public let avgBotScore: Double
    public let avgInfluenceScore: Double

    public init(
        totalAnalyzed: Int = 0, badRatio: Int = 0, inactive: Int = 0,
        deleted: Int = 0, bots: Int = 0, disengaged: Int = 0,
        mutuals: Int = 0, avgBotScore: Double = 0, avgInfluenceScore: Double = 0
    ) {
        self.totalAnalyzed = totalAnalyzed
        self.badRatio = badRatio
        self.inactive = inactive
        self.deleted = deleted
        self.bots = bots
        self.disengaged = disengaged
        self.mutuals = mutuals
        self.avgBotScore = avgBotScore
        self.avgInfluenceScore = avgInfluenceScore
    }
}

/// Reported during a follower scan. `phase` advances strictly.
public struct ScanProgress: Hashable, Sendable {
    public let phase: Phase
    public let current: Int
    public let total: Int
    public let message: String

    public init(phase: Phase, current: Int, total: Int, message: String) {
        self.phase = phase
        self.current = current
        self.total = total
        self.message = message
    }

    public enum Phase: String, Sendable, Hashable {
        case fetching       // pulling follow records
        case hydrating      // batch-resolving profiles
        case lastPosts      // optional: last-post-date per account
        case interactions   // optional: mutual-interaction sweep
        case analyzing      // running BluescreenAnalyzer
        case complete
        case error
    }
}
