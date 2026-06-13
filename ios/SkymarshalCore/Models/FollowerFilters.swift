import Foundation

/// Filter + sort state for the bluescreen account list. Mirrors the
/// 25-axis FilterState in `reference/web/bluescreen/types.ts` (lifted
/// per the swarm plan). Every field is optional / default-off so a
/// fresh struct yields the full unfiltered list.
public struct FollowerFilters: Hashable, Sendable {
    public var search: String = ""

    // Boolean flag toggles
    public var showBadRatio: Bool = false
    public var showInactive: Bool = false
    public var showDeleted: Bool = false
    public var showBots: Bool = false
    public var showDisengaged: Bool = false
    public var showMutualOnly: Bool = false
    public var showNonMutualOnly: Bool = false
    public var showMuted: Bool = false
    public var showBlocked: Bool = false

    // Numeric range pairs (nil end = unbounded)
    public var minFollowers: Int? = nil
    public var maxFollowers: Int? = nil
    public var minFollowing: Int? = nil
    public var maxFollowing: Int? = nil
    public var minBotScore: Double? = nil
    public var maxBotScore: Double? = nil
    public var minAccountAgeDays: Int? = nil
    public var maxAccountAgeDays: Int? = nil
    public var minPostsPerDay: Double? = nil
    public var maxPostsPerDay: Double? = nil
    public var minProfileCompleteness: Double? = nil
    public var minEngagementScore: Double? = nil
    public var maxEngagementScore: Double? = nil

    // Profile bits
    public var hasAvatar: Bool? = nil
    public var hasDescription: Bool? = nil
    public var hasBanner: Bool? = nil
    public var hasLabels: Bool? = nil
    public var influenceTier: InfluenceTier? = nil

    // Sort
    public var sortField: SortField = .botScore
    public var sortDirection: SortDirection = .desc

    /// Score threshold that gates `showBots`. Default 0.6 matches the
    /// historical hardcoded behavior; UI presets in BluescreenView
    /// (Strict 0.8 / Balanced 0.6 / Loose 0.4) write through to this
    /// field. Loose mode triggers an extra confirmation step before
    /// destructive bulk actions — see BluescreenView.unfollowBinding.
    public var botThreshold: Double = 0.6

    public init() {}

    public enum SortField: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
        case handle, ratio, botScore, influenceScore
        case followersCount, followsCount, postsCount
        case accountAgeDays, postsPerDay, lastPostDate
        case engagementScore, profileCompleteness

        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .handle:              return "Handle"
            case .ratio:               return "Follower ratio"
            case .botScore:            return "Bot score"
            case .influenceScore:      return "Influence"
            case .followersCount:      return "Followers"
            case .followsCount:        return "Following"
            case .postsCount:          return "Posts"
            case .accountAgeDays:      return "Account age"
            case .postsPerDay:         return "Posts / day"
            case .lastPostDate:        return "Last post"
            case .engagementScore:     return "Engagement"
            case .profileCompleteness: return "Profile completeness"
            }
        }
    }

    public enum SortDirection: String, Sendable, Hashable, Codable, CaseIterable {
        case asc, desc
    }

    /// True when at least one filter (excluding default sort) is set.
    public var hasActiveFilters: Bool {
        !search.isEmpty
            || showBadRatio || showInactive || showDeleted || showBots
            || showDisengaged || showMutualOnly || showNonMutualOnly
            || showMuted || showBlocked
            || minFollowers != nil || maxFollowers != nil
            || minFollowing != nil || maxFollowing != nil
            || minBotScore != nil || maxBotScore != nil
            || minAccountAgeDays != nil || maxAccountAgeDays != nil
            || minPostsPerDay != nil || maxPostsPerDay != nil
            || minProfileCompleteness != nil
            || minEngagementScore != nil || maxEngagementScore != nil
            || hasAvatar != nil || hasDescription != nil || hasBanner != nil
            || hasLabels != nil || influenceTier != nil
    }

    /// Apply this filter set to an analyzed-account list.
    public func apply(to accounts: [AnalyzedAccount]) -> [AnalyzedAccount] {
        let filtered = accounts.filter(matches)
        return sort(filtered)
    }

    public func matches(_ a: AnalyzedAccount) -> Bool {
        if !search.isEmpty {
            let needle = search.lowercased()
            let inHandle = a.handle.lowercased().contains(needle)
            let inName = a.profile.displayName?.lowercased().contains(needle) ?? false
            if !inHandle && !inName { return false }
        }
        // Follows-heavy only (ratio < 0.1, follows someone). High-ratio
        // popular accounts are not "bad" and are not cull candidates.
        if showBadRatio && !(a.ratio < 0.1 && a.profile.followsCount > 0) { return false }
        if showInactive && !a.isInactive { return false }
        if showDeleted && !a.isDeleted { return false }
        // User whitelist short-circuit: a manual "not an automated
        // account" override pins this row out of the bots filter even
        // when the score is above threshold.
        if showBots && (a.botScore < botThreshold || a.userWhitelisted) { return false }
        if showDisengaged && a.interactedRecently != false { return false }
        if showMutualOnly && !a.isMutual { return false }
        if showNonMutualOnly && a.isMutual { return false }
        if showMuted && a.profile.viewer?.muted != true { return false }
        if showBlocked && a.profile.viewer?.blockedBy != true { return false }

        if let v = minFollowers, a.profile.followersCount < v { return false }
        if let v = maxFollowers, a.profile.followersCount > v { return false }
        if let v = minFollowing, a.profile.followsCount < v { return false }
        if let v = maxFollowing, a.profile.followsCount > v { return false }
        if let v = minBotScore, a.botScore < v { return false }
        if let v = maxBotScore, a.botScore > v { return false }
        if let v = minAccountAgeDays, a.accountAgeDays < v { return false }
        if let v = maxAccountAgeDays, a.accountAgeDays > v { return false }
        if let v = minPostsPerDay, a.postsPerDay < v { return false }
        if let v = maxPostsPerDay, a.postsPerDay > v { return false }
        if let v = minProfileCompleteness, a.profileCompleteness < v { return false }
        if let v = minEngagementScore, a.engagementScore < v { return false }
        if let v = maxEngagementScore, a.engagementScore > v { return false }

        if let want = hasAvatar, (a.profile.avatar?.isEmpty == false) != want { return false }
        if let want = hasDescription, (a.profile.description?.isEmpty == false) != want { return false }
        if let want = hasBanner, (a.profile.banner?.isEmpty == false) != want { return false }
        if let want = hasLabels, (a.profile.labels?.isEmpty == false) != want { return false }
        if let tier = influenceTier, a.influenceTier != tier { return false }
        return true
    }

    private func sort(_ accounts: [AnalyzedAccount]) -> [AnalyzedAccount] {
        let asc = sortDirection == .asc
        return accounts.sorted { a, b in
            switch sortField {
            case .handle:              return asc ? a.handle < b.handle : a.handle > b.handle
            case .ratio:               return asc ? a.ratio < b.ratio : a.ratio > b.ratio
            case .botScore:            return asc ? a.botScore < b.botScore : a.botScore > b.botScore
            case .influenceScore:      return asc ? a.influenceScore < b.influenceScore : a.influenceScore > b.influenceScore
            case .followersCount:      return asc ? a.profile.followersCount < b.profile.followersCount : a.profile.followersCount > b.profile.followersCount
            case .followsCount:        return asc ? a.profile.followsCount < b.profile.followsCount : a.profile.followsCount > b.profile.followsCount
            case .postsCount:          return asc ? a.profile.postsCount < b.profile.postsCount : a.profile.postsCount > b.profile.postsCount
            case .accountAgeDays:      return asc ? a.accountAgeDays < b.accountAgeDays : a.accountAgeDays > b.accountAgeDays
            case .postsPerDay:         return asc ? a.postsPerDay < b.postsPerDay : a.postsPerDay > b.postsPerDay
            case .lastPostDate:
                let av = a.lastPostDate ?? .distantPast
                let bv = b.lastPostDate ?? .distantPast
                return asc ? av < bv : av > bv
            case .engagementScore:     return asc ? a.engagementScore < b.engagementScore : a.engagementScore > b.engagementScore
            case .profileCompleteness: return asc ? a.profileCompleteness < b.profileCompleteness : a.profileCompleteness > b.profileCompleteness
            }
        }
    }
}
