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
    /// User-applied "this isn't an automated account" override. When
    /// true: the row badge hides regardless of botScore, the stripe
    /// drops the danger/caution branch, and the account is excluded
    /// from the `showBots` filter even at score ≥ 0.6. Persisted via
    /// AnalyzedAccountRecord.whitelisted so the override survives
    /// re-scans.
    public let userWhitelisted: Bool

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
        userWhitelisted: Bool = false
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
        self.userWhitelisted = userWhitelisted
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
            userWhitelisted: newValue
        )
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
