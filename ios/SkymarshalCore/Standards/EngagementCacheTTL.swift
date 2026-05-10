import Foundation

/// Engagement-cache TTL based on post age. Lifted from
/// `reference/python/engagement_cache.py:236-270`.
///
/// Engagement on a Bluesky post follows a power-law decay: most likes,
/// reposts, and replies arrive in the first day, and after ~3 months the
/// numbers are essentially fixed. The cache TTL tracks this curve.
public extension Date {

    func engagementCacheTTL(now: Date = Date()) -> TimeInterval {
        let ageDays = now.timeIntervalSince(self) / 86_400
        switch ageDays {
        case ..<7:    return 3_600       // 1 hour — engagement still active
        case ..<30:   return 21_600      // 6 hours — slowing down
        case ..<90:   return 86_400      // 24 hours — mostly stable
        default:      return 604_800     // 7 days — frozen
        }
    }
}
