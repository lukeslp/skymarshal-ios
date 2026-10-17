import Foundation

/// Finds timely posts from people who already show up for the user.
/// Mirrors the proven Skyfeed idea: author affinity first, then live momentum.
@available(iOS 17, *)
public enum EngagementRecommendationService {
    public static let maxAuthors = 10
    public static let maxResults = 8

    public static func fetch(
        client: ATProtoClient,
        accounts: [AnalyzedAccount],
        now: Date = Date()
    ) async -> [WidgetSnapshot.RecommendedPost] {
        let authors = accounts
            .filter { $0.engagementScore > 0 || $0.interactedRecently == true }
            .sorted { $0.engagementScore > $1.engagementScore }
            .prefix(maxAuthors)

        var candidates: [WidgetSnapshot.RecommendedPost] = []
        await withTaskGroup(of: [WidgetSnapshot.RecommendedPost].self) { group in
            for account in authors {
                group.addTask {
                    guard let response = try? await client.getAuthorFeed(
                        actor: account.profile.did, limit: 6, filter: "posts_no_replies"
                    ) else { return [] }
                    return response.feed.compactMap { item in
                        guard item.reason == nil, item.post.record?.reply == nil,
                              let stamp = item.post.indexedAt ?? item.post.record?.createdAt,
                              // ATProtoDate, not a bare ISO8601DateFormatter:
                              // the AppView stamps indexedAt with fractional
                              // seconds, which the bare formatter rejects, and
                              // a nil date silently drops the post.
                              let date = ATProtoDate.parse(stamp),
                              now.timeIntervalSince(date) <= 72 * 3600 else { return nil }
                        let likes = item.post.likeCount ?? 0
                        let reposts = item.post.repostCount ?? 0
                        let replies = item.post.replyCount ?? 0
                        guard likes + reposts + replies > 0 else { return nil }
                        return WidgetSnapshot.RecommendedPost(
                            uri: item.post.uri,
                            handle: item.post.author.handle,
                            displayName: item.post.author.displayName,
                            text: item.post.record?.text ?? "",
                            likeCount: likes, repostCount: reposts, replyCount: replies,
                            indexedAt: date,
                            authorEngagement: max(1, Int(account.engagementScore.rounded()))
                        )
                    }
                }
            }
            for await posts in group { candidates.append(contentsOf: posts) }
        }
        return candidates.sorted {
            recommendationScore($0, now: now) > recommendationScore($1, now: now)
        }.prefix(maxResults).map { $0 }
    }

    public static func recommendationScore(
        _ post: WidgetSnapshot.RecommendedPost,
        now: Date = Date()
    ) -> Double {
        let ageHours = max(1, now.timeIntervalSince(post.indexedAt) / 3600)
        let momentum = Double(post.likeCount + post.repostCount * 2 + post.replyCount * 3)
            / pow(ageHours, 0.65)
        return log1p(Double(post.authorEngagement)) * momentum
    }
}
