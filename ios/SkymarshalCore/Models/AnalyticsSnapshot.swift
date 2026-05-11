import Foundation

/// On-device analytics derived from the user's cached ``ContentItem`` list.
/// No network calls — mirrors high-value slices from upstream CLI/web analytics
/// without server aggregation.
@available(iOS 17, *)
public struct AnalyticsSnapshot: Sendable {
    /// Posts + replies only (excludes likes/reposts for engagement stats).
    public var postAndReplyCount: Int
    public var deadThreadCount: Int
    /// Engagement score at or above ``highEngagementThreshold``.
    public var highEngagementCount: Int
    public var highEngagementThreshold: Int

    /// Bucket counts for histogram (index 0 = bucket min score).
    public var engagementHistogram: [Int]
    public var engagementBucketWidth: Int

    /// Calendar hour 0...23 — counts of posts/replies created in that hour (local TZ).
    public var postsByHourLocal: [Int]
    /// Indices 0...6 — Sunday ... Saturday (`Calendar.Component.weekday` order).
    public var postsByWeekday: [Int]

    /// Normalized token -> count; capped list for UI.
    public var topTokens: [(token: String, count: Int)]

    public init(
        postAndReplyCount: Int = 0,
        deadThreadCount: Int = 0,
        highEngagementCount: Int = 0,
        highEngagementThreshold: Int = 20,
        engagementHistogram: [Int] = [],
        engagementBucketWidth: Int = 5,
        postsByHourLocal: [Int] = Array(repeating: 0, count: 24),
        postsByWeekday: [Int] = Array(repeating: 0, count: 7),
        topTokens: [(token: String, count: Int)] = []
    ) {
        self.postAndReplyCount = postAndReplyCount
        self.deadThreadCount = deadThreadCount
        self.highEngagementCount = highEngagementCount
        self.highEngagementThreshold = highEngagementThreshold
        self.engagementHistogram = engagementHistogram
        self.engagementBucketWidth = engagementBucketWidth
        self.postsByHourLocal = postsByHourLocal
        self.postsByWeekday = postsByWeekday
        self.topTokens = topTokens
    }
}
