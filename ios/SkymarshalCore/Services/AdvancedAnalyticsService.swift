import Foundation

// MARK: - File purpose
// Optional on-device analytics beyond ``AnalyticsService``: tiny lexicon
// sentiment, word frequency (reuses tokenization shape), and a lightweight
// high-vs-low engagement word contrast. No network.

/// Extended analytics for power users — all derived from cached text.
@available(iOS 17, *)
public struct AdvancedAnalyticsSnapshot: Sendable {
    public let positiveHits: Int
    public let negativeHits: Int
    public let neutralApprox: Int
    public let topWords: [(word: String, count: Int)]
    public let highEngagementWords: [(word: String, avgScore: Double)]
    public let lowEngagementWords: [(word: String, avgScore: Double)]

    public init(
        positiveHits: Int,
        negativeHits: Int,
        neutralApprox: Int,
        topWords: [(word: String, count: Int)],
        highEngagementWords: [(word: String, avgScore: Double)],
        lowEngagementWords: [(word: String, avgScore: Double)]
    ) {
        self.positiveHits = positiveHits
        self.negativeHits = negativeHits
        self.neutralApprox = neutralApprox
        self.topWords = topWords
        self.highEngagementWords = highEngagementWords
        self.lowEngagementWords = lowEngagementWords
    }
}

@available(iOS 17, *)
public enum AdvancedAnalyticsService: Sendable {

    /// Small static lexicons — not clinical sentiment analysis; copy must say "word hits".
    private static let positiveWords: Set<String> = [
        "love", "great", "good", "happy", "thanks", "beautiful", "excited", "hope", "best", "yes",
    ]
    private static let negativeWords: Set<String> = [
        "hate", "bad", "awful", "angry", "sad", "worst", "no", "never", "terrible", "annoyed",
    ]

    public static func buildSnapshot(from items: [ContentItem], topN: Int = 20) -> AdvancedAnalyticsSnapshot {
        let pr = items.filter { $0.contentType == .posts || $0.contentType == .replies }
        var pos = 0, neg = 0, neutral = 0
        let tokens = AnalyticsService.tokenize(pr)

        for it in pr {
            guard let t = it.text?.lowercased(), !t.isEmpty else { continue }
            let words = t.split { !$0.isLetter }
            for w in words {
                let s = String(w)
                guard s.count >= 3 else { continue }
                if positiveWords.contains(s) { pos += 1 }
                else if negativeWords.contains(s) { neg += 1 }
                else { neutral += 1 }
            }
        }

        let sortedTokens = tokens.sorted { $0.value > $1.value }.prefix(topN).map { ($0.key, $0.value) }

        let scores = pr.map { (Int($0.engagementScore), AnalyticsService.tokenize([$0])) }
        guard !scores.isEmpty else {
            return AdvancedAnalyticsSnapshot(
                positiveHits: pos,
                negativeHits: neg,
                neutralApprox: neutral,
                topWords: sortedTokens,
                highEngagementWords: [],
                lowEngagementWords: []
            )
        }
        let median = scores.map(\.0).sorted()[scores.count / 2]
        var highWordScores: [String: (sum: Double, n: Int)] = [:]
        var lowWordScores: [String: (sum: Double, n: Int)] = [:]
        for (score, toks) in scores {
            for (w, _) in toks where w.count >= 4 {
                if score >= median {
                    var e = highWordScores[w] ?? (0, 0)
                    e.sum += Double(score)
                    e.n += 1
                    highWordScores[w] = e
                } else {
                    var e = lowWordScores[w] ?? (0, 0)
                    e.sum += Double(score)
                    e.n += 1
                    lowWordScores[w] = e
                }
            }
        }
        let highList = highWordScores
            .map { (word: $0.key, avgScore: $0.value.n > 0 ? $0.value.sum / Double($0.value.n) : 0) }
            .filter { $0.avgScore > 0 }
            .sorted { $0.avgScore > $1.avgScore }
            .prefix(12)
        let lowList = lowWordScores
            .map { (word: $0.key, avgScore: $0.value.n > 0 ? $0.value.sum / Double($0.value.n) : 0) }
            .filter { $0.avgScore > 0 }
            .sorted { $0.avgScore < $1.avgScore }
            .prefix(12)

        return AdvancedAnalyticsSnapshot(
            positiveHits: pos,
            negativeHits: neg,
            neutralApprox: neutral,
            topWords: sortedTokens,
            highEngagementWords: Array(highList),
            lowEngagementWords: Array(lowList)
        )
    }
}
