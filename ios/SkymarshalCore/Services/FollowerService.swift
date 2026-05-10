import Foundation

/// Orchestration boundary for follower / bot / inactive cleanup.
/// Mirrors ``ContentService`` shape: actor + five public methods.
///
/// The scan is expensive — for 1k follows it's ~1k getFollows hits +
/// 40 batched getProfiles + 1k optional getAuthorFeed-for-last-post.
/// The progress stream pattern (lifted from ContentService) lets the
/// UI render incrementally instead of waiting for everything.
public actor FollowerService {

    private let client: ATProtoClient
    private var loaded: [AnalyzedAccount] = []

    public init(client: ATProtoClient) {
        self.client = client
    }

    /// Snapshot of in-flight cache. UI pulls between progress ticks.
    public var loadedSnapshot: [AnalyzedAccount] { loaded }

    public var summary: ScanSummary {
        BluescreenAnalyzer.summarize(loaded)
    }

    /// Run the full scan. Streams ScanProgress; final value has
    /// `phase == .complete`. Cancellation honored between pages.
    ///
    /// - Parameters:
    ///   - checkLastPost: if true, fetch each profile's most-recent
    ///     post date (one extra getAuthorFeed call per account — slow
    ///     but produces accurate isInactive flags).
    ///   - inactivityDays: threshold for the inactive flag.
    ///   - maxFollowPages: defensive ceiling. 200 pages × 100 = 20k
    ///     follows, generous for the median power user.
    public func scan(
        checkLastPost: Bool = true,
        inactivityDays: Int = 90,
        maxFollowPages: Int = 200,
        progress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async throws -> [AnalyzedAccount] {
        guard let did = await client.currentDid else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }

        loaded = []

        // Phase 1 — paginated getFollows
        var follows: [BskyProfile] = []
        var cursor: String? = nil
        var page = 0
        repeat {
            try Task.checkCancellation()
            let response = try await client.getFollows(actor: did, limit: 100, cursor: cursor)
            follows.append(contentsOf: response.follows)
            cursor = response.cursor
            page += 1
            await progress?(ScanProgress(
                phase: .fetching,
                current: follows.count,
                total: follows.count + (cursor != nil ? 100 : 0),
                message: "Pulling follows… \(follows.count)"
            ))
        } while cursor != nil && page < maxFollowPages

        // Phase 2 — hydrate counts via getProfiles in batches of 25.
        // getFollows returns ProfileView which lacks count fields —
        // getProfiles returns ProfileViewDetailed which always has them.
        var hydrated = follows
        let batchSize = 25
        for index in stride(from: 0, to: hydrated.count, by: batchSize) {
            try Task.checkCancellation()
            let end = min(index + batchSize, hydrated.count)
            let dids = hydrated[index..<end].map { $0.did }
            let detail = try await client.getProfiles(actors: dids)
            let detailMap = Dictionary(uniqueKeysWithValues: detail.profiles.map { ($0.did, $0) })
            for i in index..<end {
                if let d = detailMap[hydrated[i].did] {
                    hydrated[i] = mergeCounts(into: hydrated[i], from: d)
                }
            }
            await progress?(ScanProgress(
                phase: .hydrating,
                current: end,
                total: hydrated.count,
                message: "Detail pass… \(end) of \(hydrated.count)"
            ))
        }

        // Phase 3 — optional last-post date per account.
        var lastPostDates: [String: Date] = [:]
        if checkLastPost {
            for (i, profile) in hydrated.enumerated() {
                try Task.checkCancellation()
                lastPostDates[profile.did] = try? await fetchLastPostDate(actor: profile.did)
                if i % 25 == 0 || i == hydrated.count - 1 {
                    await progress?(ScanProgress(
                        phase: .lastPosts,
                        current: i + 1,
                        total: hydrated.count,
                        message: "Activity check… \(i + 1) of \(hydrated.count)"
                    ))
                }
            }
        }

        // Phase 4 — analyze in one pass
        let analyzed = hydrated.map { profile in
            BluescreenAnalyzer.analyze(
                profile: profile,
                lastPostDate: lastPostDates[profile.did],
                inactivityDays: inactivityDays
            )
        }
        await progress?(ScanProgress(
            phase: .analyzing,
            current: analyzed.count,
            total: analyzed.count,
            message: "Scoring \(analyzed.count) accounts"
        ))

        loaded = analyzed
        await progress?(ScanProgress(
            phase: .complete,
            current: analyzed.count,
            total: analyzed.count,
            message: "Done. \(analyzed.count) analyzed."
        ))
        return analyzed
    }

    public func applyFilters(_ filters: FollowerFilters) -> [AnalyzedAccount] {
        filters.apply(to: loaded)
    }

    /// Bulk unfollow. The follow record URI is in `viewer.following` on
    /// each AnalyzedAccount's profile. Each call goes through
    /// `RateLimit.withBackoff` inside ``ATProtoClient/deleteRecord(uri:)``
    /// — concurrent fan-out is intentionally avoided so we don't sprint
    /// past the per-account write budget.
    public func unfollow(dids: [String]) async -> (done: Int, errors: [String]) {
        var done = 0
        var errors: [String] = []
        for did in dids {
            guard let acc = loaded.first(where: { $0.did == did }) else {
                errors.append("\(did): not in loaded scan")
                continue
            }
            guard let followURI = acc.profile.viewer?.following else {
                errors.append("\(acc.handle): no follow record (already unfollowed?)")
                continue
            }
            do {
                try await client.deleteRecord(uri: followURI)
                done += 1
                loaded.removeAll { $0.did == did }
            } catch {
                errors.append("\(acc.handle): \(error.localizedDescription)")
            }
        }
        return (done, errors)
    }

    public func clear() {
        loaded = []
    }

    // MARK: - Internals

    /// Fetch the actor's most recent post date — one item, no replies.
    /// Uses the public read endpoint via `getAuthorFeed`.
    private func fetchLastPostDate(actor: String) async throws -> Date? {
        let response = try await client.getAuthorFeed(
            actor: actor, limit: 1, cursor: nil, filter: "posts_no_replies"
        )
        guard let view = response.feed.first,
              let createdAt = view.post.record?.createdAt else { return nil }
        return ISO8601DateFormatter().date(from: createdAt)
    }

    /// Replace the profile's count fields and (if originally absent) any
    /// missing description / banner with values from the detailed profile.
    private func mergeCounts(into base: BskyProfile, from detail: BskyProfile) -> BskyProfile {
        BskyProfile(
            did: base.did,
            handle: base.handle,
            displayName: base.displayName ?? detail.displayName,
            description: base.description?.isEmpty == false ? base.description : detail.description,
            avatar: base.avatar ?? detail.avatar,
            banner: base.banner?.isEmpty == false ? base.banner : detail.banner,
            followersCount: detail.followersCount,
            followsCount: detail.followsCount,
            postsCount: detail.postsCount,
            createdAt: base.createdAt.isEmpty ? detail.createdAt : base.createdAt,
            labels: base.labels ?? detail.labels,
            viewer: base.viewer ?? detail.viewer
        )
    }
}
