import Foundation

// MARK: - File purpose
// Optional on-device text statistics: tiny static lexicon **word hits**
// (not sentiment analysis), word frequency, and high-vs-low engagement
// token contrast. Reuses ``AnalyticsService`` tokenization. No network.

/// Snapshot of lexicon hits and token stats derived from cached post/reply text.
@available(iOS 17, *)
public struct WordPatternsSnapshot: Sendable {
    /// Occurrences of words in a small affirmative English lexicon.
    public let affirmativeWordCount: Int
    /// Occurrences of words in a small critical English lexicon.
    public let criticalWordCount: Int
    /// Tokens counted that matched neither lexicon (length ≥ 3).
    public let otherWordApprox: Int
    public let topWords: [(word: String, count: Int)]
    public let highEngagementWords: [(word: String, avgScore: Double)]
    public let lowEngagementWords: [(word: String, avgScore: Double)]

    public init(
        affirmativeWordCount: Int,
        criticalWordCount: Int,
        otherWordApprox: Int,
        topWords: [(word: String, count: Int)],
        highEngagementWords: [(word: String, avgScore: Double)],
        lowEngagementWords: [(word: String, avgScore: Double)]
    ) {
        self.affirmativeWordCount = affirmativeWordCount
        self.criticalWordCount = criticalWordCount
        self.otherWordApprox = otherWordApprox
        self.topWords = topWords
        self.highEngagementWords = highEngagementWords
        self.lowEngagementWords = lowEngagementWords
    }
}

@available(iOS 17, *)
public enum WordPatternsService: Sendable {

    private static let affirmativeLexicon: Set<String> = [
        "love", "great", "good", "happy", "thanks", "beautiful", "excited", "hope", "best", "yes",
    ]
    private static let criticalLexicon: Set<String> = [
        "hate", "bad", "awful", "angry", "sad", "worst", "no", "never", "terrible", "annoyed",
    ]

    public static func buildSnapshot(from items: [ContentItem], topN: Int = 20) -> WordPatternsSnapshot {
        let pr = items.filter { $0.contentType == .posts || $0.contentType == .replies }
        var aff = 0, crit = 0, other = 0
        let tokens = AnalyticsService.tokenize(pr)

        for it in pr {
            guard let t = it.text?.lowercased(), !t.isEmpty else { continue }
            let words = t.split { !$0.isLetter }
            for w in words {
                let s = String(w)
                guard s.count >= 3 else { continue }
                if affirmativeLexicon.contains(s) { aff += 1 }
                else if criticalLexicon.contains(s) { crit += 1 }
                else { other += 1 }
            }
        }

        let sortedTokens = tokens.sorted { $0.value > $1.value }.prefix(topN).map { ($0.key, $0.value) }

        let scores = pr.map { (Int($0.engagementScore), AnalyticsService.tokenize([$0])) }
        guard !scores.isEmpty else {
            return WordPatternsSnapshot(
                affirmativeWordCount: aff,
                criticalWordCount: crit,
                otherWordApprox: other,
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

        return WordPatternsSnapshot(
            affirmativeWordCount: aff,
            criticalWordCount: crit,
            otherWordApprox: other,
            topWords: sortedTokens,
            highEngagementWords: Array(highList),
            lowEngagementWords: Array(lowList)
        )
    }
}
