import Foundation

/// Pure mapping from the app's in-memory engine results to a
/// ``WidgetSnapshot``. No network, no I/O — the app calls this after a
/// scan / enrich completes, then hands the result to
/// ``WidgetSnapshotStore/write(_:)``.
///
/// Sourcing:
///  - hygiene counts come from the analyzed follower set + ``ScanSummary``
///  - "people to engage" are reciprocity-style fans: accounts that
///    engaged the user (``AnalyzedAccount/interactedRecently`` true or a
///    positive engagement score) that the user is not mutually engaging,
///    ranked by engagement intensity
///  - the top post is the user's highest-engagement own post
///  - follower history is appended one point per build (today's count),
///    capped and de-duplicated by day
@available(iOS 17, *)
public enum WidgetSnapshotBuilder {

    /// Max neglected fans to surface (largest widget shows a handful).
    public static let maxFans = 8
    /// Max follower-history points to retain.
    public static let maxHistory = 30

    /// Build a fresh snapshot from a completed scan + the user's content.
    ///
    /// - Parameters:
    ///   - accounts: the analyzed follower set (post-scan).
    ///   - summary: aggregate scan counts.
    ///   - items: the user's own cached content (for the top post).
    ///   - followerCount: the user's own follower count when known (from
    ///     their self profile). When nil, a best-effort value is derived
    ///     from the analyzed set so the ratio is never blank.
    ///   - previousHistory: prior follower-history points to extend.
    ///   - now: injection point for deterministic tests.
    public static func build(
        accounts: [AnalyzedAccount],
        summary: ScanSummary,
        items: [ContentItem],
        followerCount: Int? = nil,
        previousHistory: [WidgetSnapshot.FollowerPoint] = [],
        now: Date = Date()
    ) -> WidgetSnapshot {
        let hygiene = makeHygiene(
            accounts: accounts,
            summary: summary,
            followerCount: followerCount
        )
        let fans = makeFans(accounts: accounts)
        let post = makeTopPost(items: items)
        let history = makeHistory(
            previous: previousHistory,
            todayFollowers: hygiene.followers,
            now: now
        )
        return WidgetSnapshot(
            hygieneSummary: hygiene,
            peopleToEngage: fans,
            topPost: post,
            followerHistory: history,
            generatedAt: now
        )
    }

    // MARK: - Hygiene

    static func makeHygiene(
        accounts: [AnalyzedAccount],
        summary: ScanSummary,
        followerCount: Int?
    ) -> WidgetSnapshot.HygieneSummary {
        let follows = summary.totalAnalyzed
        // Prefer the real follower count from the user's own profile.
        // Fall back to a best-effort estimate (at least the mutual count)
        // so the ratio is never blank on the very first scan.
        let followers = followerCount ?? max(summary.mutuals, summary.totalAnalyzed)
        // Reciprocity gaps: accounts that engaged the user but are not
        // mutually followed back — the "you owe them a reply" set.
        let reciprocityGaps = accounts.filter {
            ($0.interactedRecently == true) && !$0.isMutual
        }.count
        let ratio = follows > 0
            ? (Double(followers) / Double(follows)).rounded(toPlaces: 2)
            : 0
        return WidgetSnapshot.HygieneSummary(
            ghosts: summary.disengaged,
            reciprocityGaps: reciprocityGaps,
            inactive: summary.inactive,
            follows: follows,
            followers: followers,
            ratio: ratio
        )
    }

    // MARK: - Fans to engage

    static func makeFans(accounts: [AnalyzedAccount]) -> [WidgetSnapshot.FanNudge] {
        // Candidates: accounts that paid attention to the user
        // (interactedRecently or a positive engagement score) that the
        // user is NOT mutually following — the "reply back?" set. Ranked
        // by engagement intensity, then recency of their last post.
        let candidates = accounts.filter { account in
            account.interactedRecently == true || account.engagementScore > 0
        }
        let ranked = candidates.sorted { lhs, rhs in
            if lhs.engagementScore != rhs.engagementScore {
                return lhs.engagementScore > rhs.engagementScore
            }
            let l = lhs.lastPostDate ?? .distantPast
            let r = rhs.lastPostDate ?? .distantPast
            return l > r
        }
        return ranked.prefix(maxFans).map { account in
            WidgetSnapshot.FanNudge(
                handle: account.handle,
                displayName: account.profile.displayName,
                theyEngagedYou: max(1, Int(account.engagementScore.rounded())),
                lastInteraction: account.lastPostDate
            )
        }
    }

    // MARK: - Top post

    static func makeTopPost(items: [ContentItem]) -> WidgetSnapshot.TopPost? {
        let posts = items.filter { $0.contentType == .posts }
        guard let best = posts.max(by: { $0.engagementScore < $1.engagementScore }),
              best.engagementScore > 0 else {
            return nil
        }
        return WidgetSnapshot.TopPost(
            text: best.text ?? "",
            likeCount: best.likeCount,
            repostCount: best.repostCount,
            replyCount: best.replyCount,
            indexedAt: best.createdAt ?? Date()
        )
    }

    // MARK: - Follower history

    static func makeHistory(
        previous: [WidgetSnapshot.FollowerPoint],
        todayFollowers: Int,
        now: Date
    ) -> [WidgetSnapshot.FollowerPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        // Drop any existing point for today, then append the fresh one.
        var points = previous.filter { cal.startOfDay(for: $0.date) != today }
        points.append(WidgetSnapshot.FollowerPoint(date: today, count: todayFollowers))
        points.sort { $0.date < $1.date }
        if points.count > maxHistory {
            points = Array(points.suffix(maxHistory))
        }
        return points
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
