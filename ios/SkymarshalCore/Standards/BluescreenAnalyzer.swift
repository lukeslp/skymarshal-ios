import Foundation

/// Pure-function follower-cleanup scoring engine.
///
/// Bluescreen-style weighted scoring (upstream web client lineage; see `MIGRATION.md`).
/// Multi-factor weighted bot detection + influence + activity + completeness scoring.
///
/// **Do not adjust thresholds lightly.** Coordinate changes with
/// `BluescreenAnalyzerTests` and parity notes in `MIGRATION.md`.
public enum BluescreenAnalyzer {

    /// followers / following. Returns a sentinel 999 when following == 0
    /// AND followers > 0 (avoids divide-by-zero while still expressing
    /// "infinite ratio"); 0 when both are zero.
    public static func ratio(followers: Int, following: Int) -> Double {
        if following == 0 { return followers > 0 ? 999 : 0 }
        return Double(followers) / Double(following)
    }

    /// Multi-factor bot score in [0, 1]. Each triggered factor contributes
    /// a (weight, score) pair; the final value is the weighted average,
    /// clamped. `flags` lists the human-readable factors that triggered.
    public static func botScore(for profile: BskyProfile) -> (score: Double, flags: [String]) {
        var flags: [String] = []
        var factors: [(weight: Double, score: Double)] = []

        let r = ratio(followers: profile.followersCount, following: profile.followsCount)

        // 1. Mass following with very low ratio (spam pattern) — high weight
        if profile.followsCount > 500 && r < 0.1 {
            factors.append((3, 0.95))
            flags.append("Mass following, very low ratio")
        } else if profile.followsCount > 200 && r < 0.2 {
            factors.append((2, 0.7))
            flags.append("High following, low ratio")
        } else if profile.followsCount > 100 && r < 0.3 {
            factors.append((1, 0.4))
            flags.append("Moderate following, below-average ratio")
        }

        // 2. Zero posts with high following — high weight
        if profile.postsCount == 0 && profile.followsCount > 50 {
            factors.append((3, 0.9))
            flags.append("No posts despite following many")
        } else if profile.postsCount < 5 && profile.followsCount > 100 {
            factors.append((2, 0.6))
            flags.append("Very few posts, high following")
        }

        // 3. Missing profile info — medium weight
        var missing: [String] = []
        if profile.displayName?.isEmpty != false { missing.append("display name") }
        if profile.description?.isEmpty != false { missing.append("bio") }
        if profile.avatar?.isEmpty != false { missing.append("avatar") }

        if missing.count >= 3 {
            factors.append((2, 0.6))
            flags.append("Missing: \(missing.joined(separator: ", "))")
        } else if missing.count == 2 {
            factors.append((1, 0.35))
            flags.append("Missing: \(missing.joined(separator: ", "))")
        }

        // 4. Round-number following (bot farms often follow in round numbers) — low weight
        if profile.followsCount > 100 && profile.followsCount % 100 == 0 {
            factors.append((0.5, 0.3))
            flags.append("Round number following count")
        } else if profile.followsCount > 50 && profile.followsCount % 50 == 0 {
            factors.append((0.3, 0.15))
            flags.append("Suspiciously round following count")
        }

        // 5. Extremely high ratio (suspicious amplification) — low weight
        if r > 100 && profile.followersCount > 1000 {
            factors.append((0.5, 0.2))
            flags.append("Suspiciously high follower ratio")
        }

        // 6. Very new account with high activity — medium weight.
        // CRITICAL: only check this when we KNOW the account age. The basic
        // ProfileView from getFollows often lacks createdAt; if we treated
        // unknown-age as 0, every account with >100 follows would falsely
        // fire "new account" and the entire follow list would score as
        // bot. Matches the TS source: `new Date("").getTime()` is NaN
        // there, NaN < 7 is false, factor naturally skipped.
        if let date = profile.createdDate {
            let ageDays = Date().timeIntervalSince(date) / 86_400
            if ageDays < 7 && profile.followsCount > 100 {
                factors.append((2, 0.7))
                flags.append("New account, aggressive following")
            } else if ageDays < 30 && profile.followsCount > 500 {
                factors.append((1.5, 0.5))
                flags.append("Young account, high following")
            }
        }

        guard !factors.isEmpty else { return (0, flags) }

        let totalWeight = factors.reduce(0) { $0 + $1.weight }
        let weightedSum = factors.reduce(0) { $0 + $1.weight * $1.score }
        let raw = min(weightedSum / totalWeight, 1.0)
        return ((raw * 100).rounded() / 100, flags)
    }

    /// `log10(followers) × (0.4 + ratioFactor×0.3 + postFactor×0.3)`.
    public static func influenceScore(for profile: BskyProfile) -> Double {
        let followers = max(profile.followersCount, 1)
        let r = ratio(followers: profile.followersCount, following: profile.followsCount)

        let logFollowers = log10(Double(followers))
        let ratioFactor = min(r, 10) / 10
        let postFactor: Double
        if profile.postsCount > 0 {
            postFactor = min(log10(Double(profile.postsCount + 1)) / 3, 1)
        } else {
            postFactor = 0
        }

        let raw = logFollowers * (0.4 + ratioFactor * 0.3 + postFactor * 0.3)
        return (raw * 100).rounded() / 100
    }

    public static func influenceTier(for followers: Int) -> InfluenceTier {
        if followers >= 100_000 { return .mega }
        if followers >= 10_000  { return .macro }
        if followers >= 1_000   { return .micro }
        return .nano
    }

    /// Completeness in [0, 1]. Same weights as the source:
    /// displayName 0.25 + description 0.25 + avatar 0.25 + banner 0.15 + posts 0.10.
    public static func profileCompleteness(for profile: BskyProfile) -> Double {
        var score = 0.0
        if (profile.displayName?.trimmingCharacters(in: .whitespaces).isEmpty == false) {
            score += 0.25
        }
        if (profile.description?.trimmingCharacters(in: .whitespaces).isEmpty == false) {
            score += 0.25
        }
        if profile.avatar?.isEmpty == false { score += 0.25 }
        if profile.banner?.isEmpty == false { score += 0.15 }
        if profile.postsCount > 0 { score += 0.10 }
        return (score * 100).rounded() / 100
    }

    /// Run the full analysis on a single profile.
    public static func analyze(
        profile: BskyProfile,
        lastPostDate: Date? = nil,
        engagementScore: Double = 0,
        interactedRecently: Bool? = nil,
        activityReadState: ActivityReadState = .unknown,
        inactivityDays: Int = 90,
        now: Date = Date()
    ) -> AnalyzedAccount {
        let r = ratio(followers: profile.followersCount, following: profile.followsCount)
        let (botScoreVal, botFlags) = botScore(for: profile)
        let infScore = influenceScore(for: profile)
        let infTier = influenceTier(for: profile.followersCount)
        let completeness = profileCompleteness(for: profile)

        let ageDays: Int = {
            guard let date = profile.createdDate else { return 0 }
            return Int(now.timeIntervalSince(date) / 86_400)
        }()

        let postsPerDay: Double = ageDays > 0
            ? (Double(profile.postsCount) / Double(ageDays) * 100).rounded() / 100
            : 0

        let daysSinceLast: Int? = lastPostDate.map {
            Int(now.timeIntervalSince($0) / 86_400)
        }

        // `handle.invalid` means the handle is unverified. It does not
        // establish account deletion; no deletion signal is currently
        // available in the profile shape consumed by this analyzer.
        let isDeleted = false
        // Time-based inactivity (a stale last-post date) is only honest
        // when the activity read was reliable. When `activityReadState`
        // is `.unknown` (throttled / gated / errored), an empty or stale
        // last-post read is suppressed so a throttle can't masquerade as
        // inactivity. A profile-reported zero post count remains a
        // reliable, read-independent signal.
        let timeInactive = activityReadState == .read
            && (daysSinceLast.map { $0 > inactivityDays } ?? false)
        let isInactive: Bool = profile.postsCount == 0
            || timeInactive

        let isMutual = profile.viewer?.followedBy != nil

        return AnalyzedAccount(
            profile: profile,
            ratio: (r * 100).rounded() / 100,
            botScore: botScoreVal,
            botFlags: botFlags,
            influenceScore: infScore,
            influenceTier: infTier,
            accountAgeDays: ageDays,
            postsPerDay: postsPerDay,
            profileCompleteness: completeness,
            lastPostDate: lastPostDate,
            daysSinceLastPost: daysSinceLast,
            isInactive: isInactive,
            isDeleted: isDeleted,
            isMutual: isMutual,
            engagementScore: engagementScore,
            interactedRecently: interactedRecently,
            activityReadState: activityReadState
        )
    }

    /// Aggregate counters across an analyzed set.
    public static func summarize(_ accounts: [AnalyzedAccount]) -> ScanSummary {
        guard !accounts.isEmpty else { return ScanSummary() }

        // "Follows-heavy": follows far more than follow back (ratio < 0.1) —
        // the spam/mass-follow pattern worth culling. A *high* ratio (popular
        // accounts followed by many, following few) is not bad and is not a
        // cleanup target, so it's excluded. The followsCount guard drops the
        // 0/0 sentinel (ratio 0 but follows nobody).
        let badRatio = accounts.filter { $0.ratio < 0.1 && $0.profile.followsCount > 0 }.count
        let inactive = accounts.filter { $0.isInactive }.count
        let deleted = accounts.filter { $0.isDeleted }.count
        let bots = accounts.filter { $0.botScore >= 0.6 }.count
        let disengaged = accounts.filter { $0.interactedRecently == false }.count
        let mutuals = accounts.filter { $0.isMutual }.count

        let avgBot = ((accounts.reduce(0) { $0 + $1.botScore } / Double(accounts.count)) * 100).rounded() / 100
        let avgInf = ((accounts.reduce(0) { $0 + $1.influenceScore } / Double(accounts.count)) * 100).rounded() / 100

        return ScanSummary(
            totalAnalyzed: accounts.count,
            badRatio: badRatio,
            inactive: inactive,
            deleted: deleted,
            bots: bots,
            disengaged: disengaged,
            mutuals: mutuals,
            avgBotScore: avgBot,
            avgInfluenceScore: avgInf
        )
    }
}
