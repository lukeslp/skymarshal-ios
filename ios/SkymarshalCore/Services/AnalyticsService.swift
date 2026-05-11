import Foundation

/// Computes ``AnalyticsSnapshot`` from in-memory content — pure, testable, no I/O.
@available(iOS 17, *)
public enum AnalyticsService {

    /// Default threshold aligned with upstream CLI “high engagement” bucket.
    public static let defaultHighEngagementThreshold = 20

    public static func buildSnapshot(
        from items: [ContentItem],
        highEngagementThreshold: Int = defaultHighEngagementThreshold,
        histogramBuckets: Int = 15,
        bucketWidth: Int = 5,
        topTokenLimit: Int = 24
    ) -> AnalyticsSnapshot {
        let pr = items.filter { $0.contentType == .posts || $0.contentType == .replies }

        var dead = 0
        var high = 0
        for it in pr {
            if it.likeCount == 0 && it.repostCount == 0 && it.replyCount == 0 {
                dead += 1
            }
            if Int(it.engagementScore) >= highEngagementThreshold {
                high += 1
            }
        }

        var histogram = Array(repeating: 0, count: max(histogramBuckets, 1))
        for it in pr {
            let s = Int(it.engagementScore)
            let idx = min(histogram.count - 1, s / max(bucketWidth, 1))
            histogram[idx] += 1
        }

        var hourBuckets = Array(repeating: 0, count: 24)
        var weekdayBuckets = Array(repeating: 0, count: 7)
        let cal = Calendar.current
        for it in pr {
            guard let d = it.createdAt else { continue }
            hourBuckets[cal.component(.hour, from: d)] += 1
            let wd = cal.component(.weekday, from: d)
            let idx = max(0, min(6, wd - 1))
            weekdayBuckets[idx] += 1
        }

        let tokens = tokenize(pr)
        let sorted = tokens.sorted { $0.value > $1.value }.prefix(topTokenLimit)
        let top: [(String, Int)] = sorted.map { ($0.key, $0.value) }

        return AnalyticsSnapshot(
            postAndReplyCount: pr.count,
            deadThreadCount: dead,
            highEngagementCount: high,
            highEngagementThreshold: highEngagementThreshold,
            engagementHistogram: histogram,
            engagementBucketWidth: bucketWidth,
            postsByHourLocal: hourBuckets,
            postsByWeekday: weekdayBuckets,
            topTokens: top
        )
    }

    /// Lowercase alphanumeric tokens, length >= 3; strips URLs and @handles fragments lightly.
    static func tokenize(_ items: [ContentItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        let separators = CharacterSet.alphanumerics.inverted
        for it in items {
            guard let t = it.text, !t.isEmpty else { continue }
            let lowered = t.lowercased()
            for word in lowered.components(separatedBy: separators) where word.count >= 3 {
                counts[word, default: 0] += 1
            }
        }
        return counts
    }
}
