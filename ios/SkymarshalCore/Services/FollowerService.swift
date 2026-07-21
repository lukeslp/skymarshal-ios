import Foundation
import SwiftData

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
    private let container: ModelContainer?
    private var loaded: [AnalyzedAccount] = []
    /// Session-scoped cache so re-opening the AccountDetailView for
    /// the same target doesn't re-fetch their follow list. Keyed by
    /// target DID; cleared on logout via clear().
    private var mutualFollowsCache: [String: MutualFollowResult] = [:]

    /// Session-scoped set of DIDs the *user* engages (likes/reposts/
    /// reply-parents), parsed once from the user's cached content. Pure,
    /// no network — the cheap short-circuit for the per-account ghost
    /// check. Reset on logout via clear().
    private var outboundEngagedDIDsCache: Set<String>?

    public init(client: ATProtoClient, container: ModelContainer? = nil) {
        self.client = client
        self.container = container
    }

    /// Lazily build (once per session) and return the set of DIDs the
    /// user engages, parsed from their cached content items. Pure: the
    /// caller passes the items; we cache the derived set so re-opening
    /// successive account details doesn't re-parse the whole archive.
    private func userOutboundEngagedDIDs(
        userItems: [ContentItem]
    ) -> Set<String> {
        if let cached = outboundEngagedDIDsCache { return cached }
        let dids = EngagementEngine.outboundEngagedDIDs(from: userItems)
        outboundEngagedDIDsCache = dids
        return dids
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
        // Capture the owner handle once for cache-key construction.
        // Falls back to DID if handle isn't set (shouldn't happen
        // post-login but defensive).
        let ownerHandle = await client.currentHandle ?? did

        let previousLoaded = loaded
        loaded = []
        do {

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
        // AND the read-state from the throttle-safe fetch — picks up the
        // inactive flag for accounts that haven't posted recently, but
        // only when the read was reliable. A throttled/gated read stamps
        // `.unknown` so the inactivity branch is suppressed (fail-safe).
        // Each callback tick re-snapshots so the UI's badges refresh as
        // activity data arrives.
        if checkLastPost {
            for index in 0..<loaded.count {
                try Task.checkCancellation()
                let did = loaded[index].did
                let probe = await fetchLastPostDate(
                    actor: did,
                    profilePostsCount: loaded[index].profile.postsCount
                )
                loaded[index] = BluescreenAnalyzer.analyze(
                    profile: loaded[index].profile,
                    lastPostDate: probe.date,
                    engagementScore: loaded[index].engagementScore,
                    interactedRecently: loaded[index].interactedRecently,
                    activityReadState: probe.readState,
                    inactivityDays: inactivityDays
                )
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

        loaded = applyingPersistedWhitelists(to: loaded, owner: ownerHandle)
        try replacePersistedScan(accounts: loaded, owner: ownerHandle)
        await progress?(ScanProgress(
            phase: .complete,
            current: loaded.count,
            total: loaded.count,
            message: "Done. \(loaded.count) analyzed."
        ))
        return loaded
        } catch {
            loaded = previousLoaded
            throw error
        }
    }

    public func applyFilters(_ filters: FollowerFilters) -> [AnalyzedAccount] {
        filters.apply(to: loaded)
    }

    /// Phase 4 — opt-in "Deep analyze". Computes the engaged-audience set
    /// from the user's recent posts and, for each loaded follow, stamps
    /// `interactedRecently` (are they in the engaged set?) and an
    /// `engagementScore` (hit count). Fail-safe throughout: if the
    /// audience read was throttled (`.unknown`), every account's
    /// engagement signal is left at its prior value (`interactedRecently`
    /// stays `nil`) and the read-state is marked `.unknown` so the
    /// disengaged preset refuses to act on them.
    ///
    /// Reuses the already-allowed `getLikes` / `getRepostedBy` endpoints
    /// via ``EngagementEngine`` — no new network surface. The unused
    /// `ScanProgress.Phase.interactions` is the progress hook.
    ///
    /// - Parameter userPostURIs: the user's recent post `at://` URIs
    ///   (cheapest source: the user's cached content items).
    @discardableResult
    public func enrichEngagement(
        userPostURIs: [String],
        progress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async -> [AnalyzedAccount] {
        guard !loaded.isEmpty else { return loaded }
        let owner = await client.currentHandle

        await progress?(ScanProgress(
            phase: .interactions,
            current: 0,
            total: loaded.count,
            message: "Reading your engaged audience…"
        ))

        let engine = EngagementEngine(client: client)
        let audience = await engine.engagedAudience(userPostURIs: userPostURIs)
        let engagedDIDs = audience.engagedDIDs

        // A throttled audience read can't tell "not engaged" from "we
        // didn't see it" — leave engagement signals untouched and mark
        // the read unreliable.
        let audienceUnknown = audience.readState == .unknown

        for index in 0..<loaded.count {
            let account = loaded[index]
            let hits = audience.countsByDID[account.did] ?? 0

            if audienceUnknown {
                loaded[index] = account.withActivityReadState(.unknown)
                continue
            }

            let interacted = engagedDIDs.contains(account.did)
            // Re-run analyze to fold in the engagement signal, preserving
            // the account's existing activity read-state (the last-post
            // phase already decided whether the inactivity signal is
            // trustworthy — engagement enrichment must not resurrect a
            // suppressed inactivity verdict).
            loaded[index] = BluescreenAnalyzer.analyze(
                profile: account.profile,
                lastPostDate: account.lastPostDate,
                engagementScore: Double(hits),
                interactedRecently: interacted,
                activityReadState: account.activityReadState,
                inactivityDays: 90
            )

            if index % 25 == 0 || index == loaded.count - 1 {
                await progress?(ScanProgress(
                    phase: .interactions,
                    current: index + 1,
                    total: loaded.count,
                    message: "Engagement check… \(index + 1) of \(loaded.count)"
                ))
            }
        }

        if let owner {
            loaded = applyingPersistedWhitelists(to: loaded, owner: owner)
            try? replacePersistedScan(accounts: loaded, owner: owner)
        }
        await progress?(ScanProgress(
            phase: .complete,
            current: loaded.count,
            total: loaded.count,
            message: "Deep analyze complete."
        ))
        return loaded
    }

    // MARK: - Per-account ghost / reciprocity (lazy)

    /// Lazily compute the ghost verdict + inbound reciprocity count for a
    /// **single** account, stamp it onto `loaded`, and persist it. This
    /// is the cheap user-initiated read the AccountDetailView fires when
    /// it opens and the account hasn't been checked yet.
    ///
    /// Cost is bounded to one capped `getActorLikes` sweep per account
    /// (≤ 2 PDS pages by default) plus a pure membership check against
    /// the session-cached outbound set — well under the 15-call/account
    /// budget. Never batched over the follow graph.
    ///
    /// Fail-safe: a throttled/gated read yields `.unknown`, which the UI
    /// renders as "couldn't read" and which is never a reason to
    /// unfollow. Returns the freshly-stamped account, or `nil` when the
    /// DID isn't in the loaded scan.
    @discardableResult
    public func computeGhostReciprocity(
        forDID did: String,
        userItems: [ContentItem]
    ) async -> AnalyzedAccount? {
        guard let idx = loaded.firstIndex(where: { $0.did == did }) else { return nil }
        let account = loaded[idx]
        guard let userDID = await client.currentDid else { return nil }
        let owner = await client.currentHandle

        let outbound = userOutboundEngagedDIDs(userItems: userItems)
        let engine = EngagementEngine(client: client)
        let (engineVerdict, inbound) = await engine.verifyGhostWithInbound(
            candidateDID: did,
            engagedDIDs: outbound,
            userPostURIPrefix: "at://\(userDID)/",
            candidatePostsCount: account.profile.postsCount
        )

        let stamped = account.withGhostReciprocity(
            verdict: GhostVerdict(engineVerdict.classification),
            inboundCount: inbound
        )
        // Re-find the index — the actor may have mutated `loaded` while
        // the await was suspended.
        if let liveIdx = loaded.firstIndex(where: { $0.did == did }) {
            loaded[liveIdx] = stamped
        }
        if let owner { persist([stamped], owner: owner) }
        return stamped
    }

    /// Whether the user's outbound engaged-DID set is already cached for
    /// this session (so the UI can skip passing the full item list when
    /// it's already been built).
    public var hasOutboundCache: Bool { outboundEngagedDIDsCache != nil }

    /// Opt-in capped batch: run the per-account ghost check over the
    /// **already-flagged disengaged candidates only** — accounts whose
    /// activity read was reliable and that the engaged-audience pass
    /// found disengaged (`interactedRecently == false`) or that score
    /// low. Capped at `cap` per run (default 100) so a single tap never
    /// spends minutes of the IP budget. Honors cancellation between
    /// accounts and streams progress.
    ///
    /// Never the full follow set: candidates are pre-filtered to the
    /// disengaged bucket before any network read happens.
    @discardableResult
    public func verifyFlaggedGhosts(
        userItems: [ContentItem],
        cap: Int = 100,
        progress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async -> Int {
        guard let userDID = await client.currentDid else { return 0 }
        let owner = await client.currentHandle
        let outbound = userOutboundEngagedDIDs(userItems: userItems)
        let engine = EngagementEngine(client: client)

        // Pre-filter to already-flagged disengaged candidates whose
        // activity we could read reliably, skipping ones already
        // checked. This is the bounded candidate set — never the graph.
        let candidates = loaded.filter { acc in
            acc.ghostVerdict == nil
                && acc.activityReadState == .read
                && acc.interactedRecently == false
        }.prefix(cap)

        var checked = 0
        let total = candidates.count
        for account in candidates {
            if Task.isCancelled { break }
            await progress?(ScanProgress(
                phase: .interactions,
                current: checked,
                total: total,
                message: "Verifying flagged ghosts… \(checked) of \(total)"
            ))
            let (engineVerdict, inbound) = await engine.verifyGhostWithInbound(
                candidateDID: account.did,
                engagedDIDs: outbound,
                userPostURIPrefix: "at://\(userDID)/",
                candidatePostsCount: account.profile.postsCount
            )
            let stamped = account.withGhostReciprocity(
                verdict: GhostVerdict(engineVerdict.classification),
                inboundCount: inbound
            )
            if let liveIdx = loaded.firstIndex(where: { $0.did == account.did }) {
                loaded[liveIdx] = stamped
            }
            if let owner { persist([stamped], owner: owner) }
            checked += 1
        }
        await progress?(ScanProgress(
            phase: .complete,
            current: checked,
            total: total,
            message: "Verified \(checked) flagged \(checked == 1 ? "account" : "accounts")."
        ))
        return checked
    }

    /// Bulk unfollow. The follow record URI is in `viewer.following` on
    /// each AnalyzedAccount's profile. Each real call goes through
    /// `RateLimit.withBackoff` inside ``ATProtoClient/deleteRecord(uri:)``
    /// — concurrent fan-out is intentionally avoided so we don't sprint
    /// past the per-account write budget.
    ///
    /// When `dryRun` is true, validates each DID and follow record but performs
    /// no XRPC writes and does not mutate `loaded`.
    ///
    /// When `requireKnownActivity` is true (the preset bulk paths pass
    /// it), accounts whose `activityReadState == .unknown` are skipped
    /// and reported rather than unfollowed. This is the defense-in-depth
    /// layer behind the filter guard: even if a `.unknown` account leaks
    /// into a selection, the destructive call itself refuses to act on an
    /// account whose activity we could not reliably read.
    public func unfollow(
        dids: [String],
        dryRun: Bool = false,
        requireKnownActivity: Bool = false
    ) async -> (done: Int, errors: [String]) {
        let owner = await client.currentHandle
        var done = 0
        var errors: [String] = []
        for did in dids {
            guard let acc = loaded.first(where: { $0.did == did }) else {
                errors.append("\(did): not in loaded scan")
                continue
            }
            if requireKnownActivity && acc.activityReadState == .unknown {
                errors.append("\(acc.handle): activity could not be read reliably — skipped for safety")
                continue
            }
            guard let followURI = acc.profile.viewer?.following else {
                errors.append("\(acc.handle): no follow record (already unfollowed?)")
                continue
            }
            if dryRun {
                done += 1
                continue
            }
            do {
                try await client.deleteRecord(
                    uri: followURI,
                    expectedCollection: .follow
                )
                done += 1
                loaded.removeAll { $0.did == did }
                if let owner { deletePersistedAccount(did: did, owner: owner) }
            } catch {
                errors.append("\(acc.handle): \(error.localizedDescription)")
            }
        }
        return (done, errors)
    }

    public func clear() {
        loaded = []
        mutualFollowsCache = [:]
        outboundEngagedDIDsCache = nil
    }

    /// Inject a snapshot from the SwiftData cache during cold-start
    /// hydration. Only used by AppModel.hydrateFromCache; never call
    /// from a UI code path during a session (it bypasses the scan
    /// progress callbacks the UI binds to).
    public func setLoaded(_ accounts: [AnalyzedAccount]) {
        self.loaded = accounts
    }

    /// Mark an account as user-whitelisted ("not an automated account").
    /// Swaps the matching struct in-place in `loaded` so SwiftUI rebuilds
    /// the AccountRow without that account wearing a bot stripe, and
    /// writes the override through to the SwiftData record so it
    /// survives the next scan. No-op when the account isn't in the
    /// current list.
    public func setWhitelist(
        did: String,
        to newValue: Bool,
        owner: String
    ) async {
        guard let idx = loaded.firstIndex(where: { $0.did == did }) else { return }
        loaded[idx] = loaded[idx].withWhitelist(newValue)
        await persistWhitelist(did: did, to: newValue, owner: owner)
    }

    private func persistWhitelist(did: String, to newValue: Bool, owner: String) async {
        guard let container else { return }
        let context = ModelContext(container)
        let key = "\(owner)|\(did)"
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.compositeKey == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.whitelisted = newValue
            try? context.save()
        }
    }

    /// Find accounts that BOTH the user and the target follow. One
    /// paginated `getFollows(actor: targetDID)` walk (capped at 5
    /// pages = 500 follows examined) intersected against the user's
    /// cached `loaded` follow list. Result is session-cached per
    /// target DID so reopening the AccountDetailView doesn't refetch.
    public func loadMutualFollows(
        withDID targetDID: String
    ) async throws -> MutualFollowResult {
        if let cached = mutualFollowsCache[targetDID] { return cached }

        let userDIDs = Set(loaded.map(\.did))
        guard !userDIDs.isEmpty else {
            return MutualFollowResult(matches: [], truncated: false)
        }

        let maxPages = 5  // 5 × 100 = 500 follows max
        let selfDID = await client.currentDid
        var cursor: String? = nil
        var page = 0
        var matches: [MutualFollow] = []
        var seenDIDs = Set<String>()

        repeat {
            try Task.checkCancellation()
            let response = try await client.getFollows(
                actor: targetDID, limit: 100, cursor: cursor
            )
            for profile in response.follows {
                guard !seenDIDs.contains(profile.did),
                      profile.did != selfDID,
                      userDIDs.contains(profile.did) else { continue }
                seenDIDs.insert(profile.did)
                matches.append(MutualFollow(
                    did: profile.did,
                    handle: profile.handle,
                    displayName: profile.displayName,
                    avatar: profile.avatar
                ))
            }
            cursor = response.cursor
            page += 1
        } while cursor != nil && page < maxPages

        let result = MutualFollowResult(
            matches: matches,
            truncated: cursor != nil
        )
        mutualFollowsCache[targetDID] = result
        return result
    }

    // MARK: - Persistence

    /// Upsert a slice of analyzed accounts into the SwiftData cache.
    /// Called once per phase-2 batch and per phase-3 update. Uses a
    /// fresh ModelContext per call — SwiftData contexts aren't actor-
    /// safe to share across save() calls in different scopes.
    private func persist(_ accounts: [AnalyzedAccount], owner: String) {
        guard let container else { return }
        let context = ModelContext(container)
        let now = Date()
        for acc in accounts {
            let key = "\(owner)|\(acc.did)"
            let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
                predicate: #Predicate { $0.compositeKey == key }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.update(from: acc, scannedAt: now)
            } else {
                context.insert(AnalyzedAccountRecord(
                    account: acc,
                    ownerHandle: owner,
                    scannedAt: now
                ))
            }
        }
        try? context.save()
    }

    /// Drop a single record after successful unfollow so the cache
    /// reflects current truth (otherwise the unfollowed account
    /// reappears on the next cold-start).
    private func deletePersistedAccount(did: String, owner: String) {
        guard let container else { return }
        let context = ModelContext(container)
        let key = "\(owner)|\(did)"
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.compositeKey == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    private func applyingPersistedWhitelists(
        to accounts: [AnalyzedAccount],
        owner: String
    ) -> [AnalyzedAccount] {
        guard let container else { return accounts }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        let whitelistedDIDs = Set(
            ((try? context.fetch(descriptor)) ?? [])
                .filter(\.whitelisted)
                .map(\.did)
        )
        return accounts.map { account in
            whitelistedDIDs.contains(account.did) ? account.withWhitelist(true) : account
        }
    }

    private func replacePersistedScan(accounts: [AnalyzedAccount], owner: String) throws {
        guard let container else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        let existingRows = (try? context.fetch(descriptor)) ?? []
        var existingByKey = Dictionary(
            uniqueKeysWithValues: existingRows.map { ($0.compositeKey, $0) }
        )
        let now = Date()

        for account in accounts {
            let key = "\(owner)|\(account.did)"
            if let existing = existingByKey.removeValue(forKey: key) {
                existing.update(from: account, scannedAt: now)
                if account.userWhitelisted {
                    existing.whitelisted = true
                }
            } else {
                context.insert(AnalyzedAccountRecord(
                    account: account,
                    ownerHandle: owner,
                    scannedAt: now
                ))
            }
        }
        for stale in existingByKey.values {
            context.delete(stale)
        }
        try context.save()
    }

    // MARK: - Internals

    /// Probe result for a throttle-safe last-post read.
    struct LastPostProbe: Sendable {
        let date: Date?
        let readState: ActivityReadState
    }

    /// Fetch the actor's most recent post date — one item, no replies —
    /// through `RateLimit.withBackoff` so a transient 429 retries instead
    /// of being misread as "no posts".
    ///
    /// Returns a tri-state read alongside the date:
    ///   - **throttle after the backoff ladder is exhausted** → `.unknown`.
    ///     Never let a rate-limit look like inactivity.
    ///   - **200 + empty feed for an account whose profile says
    ///     `postsCount > 0`** → `.unknown`. An active account with an
    ///     empty public feed is the signature of throttling or an
    ///     `!no-unauthenticated` gate, not genuine inactivity.
    ///   - **any other error** → `.unknown`. Fail safe on the read.
    ///   - **otherwise** (a real post, or a genuinely empty feed for an
    ///     account that reports zero posts) → `.read`.
    private func fetchLastPostDate(
        actor: String,
        profilePostsCount: Int
    ) async -> LastPostProbe {
        do {
            let response = try await RateLimit.withBackoff {
                try await self.client.getAuthorFeed(
                    actor: actor, limit: 1, cursor: nil, filter: "posts_no_replies"
                )
            }
            guard let view = response.feed.first else {
                // Empty feed. If the profile claims posts exist, the
                // empty read is almost certainly a throttle/gate, not
                // truth → fail safe to `.unknown`. A zero-post profile
                // with an empty feed is a consistent, trustworthy read.
                return LastPostProbe(
                    date: nil,
                    readState: profilePostsCount > 0 ? .unknown : .read
                )
            }
            return LastPostProbe(
                date: ATProtoDate.parse(view.post.record?.createdAt),
                readState: .read
            )
        } catch {
            // Throttle-after-retries or any other read failure: we did
            // not reliably read this account's activity.
            return LastPostProbe(date: nil, readState: .unknown)
        }
    }

    /// Replace the profile's handle/count fields and (if originally absent)
    /// any missing description / banner with values from the detailed profile.
    /// The detailed handle is authoritative for this scan: a basic
    /// getFollows row can carry stale `handle.invalid` identity data.
    private func mergeCounts(into base: BskyProfile, from detail: BskyProfile) -> BskyProfile {
        BskyProfile(
            did: base.did,
            handle: detail.handle,
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
