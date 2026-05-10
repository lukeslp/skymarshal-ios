import Foundation

/// Orchestration boundary for follower / bot / inactive cleanup.
/// Mirrors ``ContentService`` shape: actor + five public methods.
///
/// The scan is expensive — for 1k follows it's ~1k getFollows hits +
/// 40 batched getProfiles + 1k optional getAuthorFeed-for-last-post.
/// The progress stream pattern (lifted from ContentService) lets the
/// UI render incrementally instead of waiting for everything.
@available(iOS 17, *)
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

        // Phase 1 — paginated getFollows. Result list isn't yet visible to
        // the UI — we don't surface accounts until phase 2 starts giving us
        // hydrated profiles (otherwise every score would be zero).
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
                message: "Pulling follow list… \(follows.count)"
            ))
        } while cursor != nil && page < maxFollowPages

        // Phase 2 — hydrate counts via getProfiles AND analyze + append
        // per batch so the UI list grows in real time. Each batch of 25
        // arrives, gets scored with the *real* counts, and is appended
        // to `loaded` — the AppModel snapshot pulls between batches and
        // the BluescreenView list populates row-by-row.
        let batchSize = 25
        for index in stride(from: 0, to: follows.count, by: batchSize) {
            try Task.checkCancellation()
            let end = min(index + batchSize, follows.count)
            let dids = follows[index..<end].map { $0.did }
            let detail = try await client.getProfiles(actors: dids)
            let detailMap = Dictionary(uniqueKeysWithValues: detail.profiles.map { ($0.did, $0) })

            var batchAnalyzed: [AnalyzedAccount] = []
            batchAnalyzed.reserveCapacity(end - index)
            for i in index..<end {
                var profile = follows[i]
                if let d = detailMap[profile.did] {
                    profile = mergeCounts(into: profile, from: d)
                }
                batchAnalyzed.append(BluescreenAnalyzer.analyze(
                    profile: profile,
                    inactivityDays: inactivityDays
                ))
            }
            loaded.append(contentsOf: batchAnalyzed)

            await progress?(ScanProgress(
                phase: .hydrating,
                current: end,
                total: follows.count,
                message: "Analyzing… \(end) of \(follows.count)"
            ))
        }

        // Phase 3 — optional last-post date per account. Updates loaded[i]
        // in place by re-running BluescreenAnalyzer with the lastPostDate
        // — picks up the inactive flag for accounts that haven't posted
        // recently. Each callback tick re-snapshots so the UI's badges
        // refresh as activity data arrives.
        if checkLastPost {
            for index in 0..<loaded.count {
                try Task.checkCancellation()
                let did = loaded[index].did
                let lastPost = try? await fetchLastPostDate(actor: did)
                if lastPost != nil {
                    loaded[index] = BluescreenAnalyzer.analyze(
                        profile: loaded[index].profile,
                        lastPostDate: lastPost,
                        engagementScore: loaded[index].engagementScore,
                        interactedRecently: loaded[index].interactedRecently,
                        inactivityDays: inactivityDays
                    )
                }
                if index % 25 == 0 || index == loaded.count - 1 {
                    await progress?(ScanProgress(
                        phase: .lastPosts,
                        current: index + 1,
                        total: loaded.count,
                        message: "Activity check… \(index + 1) of \(loaded.count)"
                    ))
                }
            }
        }

        await progress?(ScanProgress(
            phase: .complete,
            current: loaded.count,
            total: loaded.count,
            message: "Done. \(loaded.count) analyzed."
        ))
        return loaded
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
