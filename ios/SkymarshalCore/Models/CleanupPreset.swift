import Foundation

/// One-tap cleanup bundles mirroring upstream “quality / inactive / bot” workflows.
@available(iOS 17, *)
public enum CleanupPreset: String, CaseIterable, Identifiable, Sendable {
    case inactive
    case botHeavy
    case disengaged
    case ratioSkew

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .inactive:    return "Inactive"
        case .botHeavy:    return "Automation signals"
        case .disengaged:  return "Disengaged"
        case .ratioSkew:   return "Follower skew"
        }
    }

    public var detail: String {
        switch self {
        case .inactive:
            return "Accounts with no recent posts (scan metadata)."
        case .botHeavy:
            return "Accounts above your bot sensitivity threshold."
        case .disengaged:
            return "Follows that show no recent interaction with you."
        case .ratioSkew:
            return "Very high or very low follower ratios."
        }
    }

    /// Builds filter state; caller supplies live `botThreshold` from Bluescreen UI.
    public func filters(botThreshold: Double) -> FollowerFilters {
        var f = FollowerFilters()
        f.botThreshold = botThreshold
        switch self {
        case .inactive:
            f.showInactive = true
            f.sortField = .lastPostDate
            f.sortDirection = .asc
        case .botHeavy:
            f.showBots = true
            f.sortField = .botScore
            f.sortDirection = .desc
        case .disengaged:
            f.showDisengaged = true
            f.sortField = .engagementScore
            f.sortDirection = .asc
        case .ratioSkew:
            f.showBadRatio = true
            f.sortField = .ratio
            // Ascending: most extreme follows-heavy (lowest ratio) leads —
            // those are the strongest unfollow candidates.
            f.sortDirection = .asc
        }
        return f
    }
}
