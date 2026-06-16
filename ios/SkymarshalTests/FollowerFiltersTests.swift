import XCTest
@testable import SkymarshalCore

final class FollowerFiltersTests: XCTestCase {

    // MARK: - Helpers

    private func account(
        did: String,
        handle: String = "x.bsky.social",
        displayName: String = "X",
        followers: Int = 100,
        following: Int = 100,
        posts: Int = 50,
        ageDays: Int = 365,
        botScore: Double = 0.0,
        engagement: Double = 0.0,
        isMutual: Bool = false,
        isInactive: Bool = false,
        isDeleted: Bool = false,
        muted: Bool = false,
        blockedBy: Bool = false,
        avatar: String? = "https://x/y",
        description: String? = "bio",
        banner: String? = "https://x/b",
        labels: [BskyProfile.Label]? = nil,
        tier: InfluenceTier = .nano,
        completeness: Double = 1.0,
        ratio: Double = 1.0,
        postsPerDay: Double = 0.1,
        lastPostDate: Date? = nil,
        interactedRecently: Bool? = nil,
        activityReadState: ActivityReadState = .read
    ) -> AnalyzedAccount {
        let createdAt = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(-Double(ageDays) * 86_400)
        )
        let viewer: BskyProfile.ViewerState? = (muted || blockedBy || isMutual)
            ? .init(muted: muted ? true : nil,
                    blockedBy: blockedBy ? true : nil,
                    followedBy: isMutual ? "at://them/follow/123" : nil)
            : nil
        let profile = BskyProfile(
            did: did, handle: handle, displayName: displayName,
            description: description, avatar: avatar, banner: banner,
            followersCount: followers, followsCount: following, postsCount: posts,
            createdAt: createdAt, labels: labels, viewer: viewer
        )
        return AnalyzedAccount(
            profile: profile,
            ratio: ratio, botScore: botScore, botFlags: [],
            influenceScore: 1.0, influenceTier: tier,
            accountAgeDays: ageDays, postsPerDay: postsPerDay,
            profileCompleteness: completeness,
            lastPostDate: lastPostDate, daysSinceLastPost: nil,
            isInactive: isInactive, isDeleted: isDeleted,
            isMutual: isMutual,
            engagementScore: engagement, interactedRecently: interactedRecently,
            activityReadState: activityReadState
        )
    }

    private var sample: [AnalyzedAccount] {
        [
            account(did: "1", handle: "alice.bsky.social", displayName: "Alice",
                    botScore: 0.8, isMutual: true),
            account(did: "2", handle: "bob.spam.bot", displayName: "Bob",
                    botScore: 0.95),
            account(did: "3", handle: "carol.bsky.social", displayName: "Carol",
                    isInactive: true),
            account(did: "4", handle: "dead.user", displayName: "Dead",
                    isInactive: true, isDeleted: true),
            account(did: "5", handle: "eve.bsky.social", displayName: "Eve",
                    isMutual: true),
            account(did: "6", handle: "frank.bsky.social", displayName: "Frank",
                    followers: 50000, following: 5, tier: .macro, ratio: 10000),
        ]
    }

    // MARK: - Defaults

    func test_default_filters_passEverything_andSortByBotScoreDesc() {
        let f = FollowerFilters()
        let result = f.apply(to: sample)
        XCTAssertEqual(result.count, sample.count)
        // Default sort is botScore descending — Bob (0.95) first, then Alice (0.8)
        XCTAssertEqual(result.first?.handle, "bob.spam.bot")
        XCTAssertEqual(result[1].handle, "alice.bsky.social")
    }

    func test_default_hasActiveFilters_false() {
        XCTAssertFalse(FollowerFilters().hasActiveFilters)
    }

    func test_settingAnyFlag_makesHasActiveFiltersTrue() {
        var f = FollowerFilters()
        f.showBots = true
        XCTAssertTrue(f.hasActiveFilters)
    }

    // MARK: - Boolean toggles

    func test_showBots_keepsOnlyAccountsAtOrAbove06() {
        var f = FollowerFilters()
        f.showBots = true
        let result = f.apply(to: sample)
        XCTAssertEqual(Set(result.map(\.handle)), ["bob.spam.bot", "alice.bsky.social"])
    }

    func test_showInactive_filtersToInactiveOnly() {
        var f = FollowerFilters()
        f.showInactive = true
        let result = f.apply(to: sample)
        XCTAssertEqual(Set(result.map(\.handle)), ["carol.bsky.social", "dead.user"])
    }

    // MARK: - Fail-safe inactivity (throttle-safe reads)

    /// An account flagged inactive from a stale last-post date must NOT
    /// appear in the inactive bucket when the activity read was
    /// unreliable. This is the core fix: a throttled read looks empty,
    /// and an empty read must never masquerade as "inactive".
    func test_showInactive_excludesTimeInactive_whenReadStateUnknown() {
        let throttled = account(
            did: "u", handle: "throttled.bsky.social",
            posts: 200, isInactive: true, activityReadState: .unknown
        )
        var f = FollowerFilters()
        f.showInactive = true
        XCTAssertTrue(f.apply(to: [throttled]).isEmpty)
    }

    /// Time-based inactivity with a reliable read still surfaces — the
    /// guard suppresses only the untrustworthy case.
    func test_showInactive_includesTimeInactive_whenReadStateRead() {
        let inactive = account(
            did: "u", handle: "stale.bsky.social",
            posts: 200, isInactive: true, activityReadState: .read
        )
        var f = FollowerFilters()
        f.showInactive = true
        XCTAssertEqual(f.apply(to: [inactive]).map(\.handle), ["stale.bsky.social"])
    }

    /// `postsCount == 0` and deleted accounts are reliable signals that
    /// never depend on an AppView read, so they surface even when the
    /// read-state is `.unknown`.
    func test_showInactive_includesZeroPostsAndDeleted_evenWhenReadStateUnknown() {
        let zeroPosts = account(
            did: "z", handle: "zero.bsky.social",
            posts: 0, isInactive: true, activityReadState: .unknown
        )
        let deleted = account(
            did: "d", handle: "handle.invalid",
            isInactive: true, isDeleted: true, activityReadState: .unknown
        )
        var f = FollowerFilters()
        f.showInactive = true
        XCTAssertEqual(
            Set(f.apply(to: [zeroPosts, deleted]).map(\.handle)),
            ["zero.bsky.social", "handle.invalid"]
        )
    }

    /// Regression lock on the disengaged preset: `nil` (engagement
    /// unknown) must never count as disengaged — only a confirmed
    /// `false` qualifies.
    func test_showDisengaged_excludesEngagementUnknown() {
        let unknown = account(did: "n", handle: "nil.bsky.social", interactedRecently: nil)
        let disengaged = account(did: "f", handle: "false.bsky.social", interactedRecently: false)
        let engaged = account(did: "t", handle: "true.bsky.social", interactedRecently: true)
        var f = FollowerFilters()
        f.showDisengaged = true
        XCTAssertEqual(f.apply(to: [unknown, disengaged, engaged]).map(\.handle), ["false.bsky.social"])
    }

    func test_showDeleted_isStrictSubsetOfInactive() {
        var f = FollowerFilters()
        f.showDeleted = true
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["dead.user"])
    }

    func test_showMutualOnly_filtersToMutuals() {
        var f = FollowerFilters()
        f.showMutualOnly = true
        XCTAssertEqual(Set(f.apply(to: sample).map(\.handle)), ["alice.bsky.social", "eve.bsky.social"])
    }

    func test_showBadRatio_catchesFollowsHeavyOnly() {
        var f = FollowerFilters()
        f.showBadRatio = true
        // Follows-heavy is the cull-worthy spam side (ratio < 0.1). A *high*
        // ratio (Frank, 10000) is a popular account, not "bad" — it must NOT
        // match. The 0/0 sentinel (follows nobody) must also be excluded.
        let lowRatio = account(did: "7", handle: "lowratio.bsky.social", ratio: 0.05)
        let followsNobody = account(did: "8", handle: "lurker.bsky.social",
                                    following: 0, ratio: 0)
        XCTAssertEqual(Set(f.apply(to: sample + [lowRatio, followsNobody]).map(\.handle)),
                       ["lowratio.bsky.social"])
    }

    // MARK: - Numeric ranges

    func test_minBotScore_filtersBelowThreshold() {
        var f = FollowerFilters()
        f.minBotScore = 0.9
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["bob.spam.bot"])
    }

    func test_minMaxFollowers_combinatorial() {
        var f = FollowerFilters()
        f.minFollowers = 200
        f.maxFollowers = 60_000
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["frank.bsky.social"])
    }

    // MARK: - Search by handle / display name

    func test_search_byPartialHandle_caseInsensitive() {
        var f = FollowerFilters()
        f.search = "BOT"
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["bob.spam.bot"])
    }

    func test_search_byPartialDisplayName_caseInsensitive() {
        var f = FollowerFilters()
        f.search = "ali"
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["alice.bsky.social"])
    }

    // MARK: - Sort

    func test_sort_byHandle_ascending() {
        var f = FollowerFilters()
        f.sortField = .handle
        f.sortDirection = .asc
        let handles = f.apply(to: sample).map(\.handle)
        XCTAssertEqual(handles.first, "alice.bsky.social")
        XCTAssertEqual(handles.last, "frank.bsky.social")
    }

    func test_sort_byInfluence_descending_default() {
        var f = FollowerFilters()
        f.sortField = .followersCount
        f.sortDirection = .desc
        XCTAssertEqual(f.apply(to: sample).first?.handle, "frank.bsky.social")
    }

    // MARK: - Combinatorial AND

    func test_search_plus_botScore_intersect() {
        var f = FollowerFilters()
        f.search = "bsky"
        f.showBots = true
        // Only Alice — Bob has botScore but his handle doesn't contain "bsky".
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["alice.bsky.social"])
    }

    // MARK: - Profile-completeness toggles

    func test_hasAvatar_false_filtersToAvatarless() {
        var f = FollowerFilters()
        f.hasAvatar = false
        let extras = [account(did: "8", handle: "noavatar.bsky.social", avatar: nil)]
        XCTAssertEqual(f.apply(to: sample + extras).map(\.handle), ["noavatar.bsky.social"])
    }

    // MARK: - Influence tier

    func test_influenceTier_macro_filtersExactly() {
        var f = FollowerFilters()
        f.influenceTier = .macro
        XCTAssertEqual(f.apply(to: sample).map(\.handle), ["frank.bsky.social"])
    }

    // MARK: - User whitelist override

    /// A high-bot-score account that the user has marked "not an
    /// automated account" should NOT appear in the bots filter — that's
    /// the whole point of the dignity affordance.
    func test_whitelisted_account_excluded_from_bots_filter() {
        var f = FollowerFilters()
        f.showBots = true
        let normal = account(did: "1", handle: "alice", botScore: 0.85)
        let pardoned = account(did: "2", handle: "bob", botScore: 0.85)
            .withWhitelist(true)
        let result = f.apply(to: [normal, pardoned]).map(\.handle)
        XCTAssertEqual(result, ["alice"])
        XCTAssertFalse(result.contains("bob"))
    }

    /// Without the bots filter active, whitelist is invisible — both
    /// accounts pass through. Whitelist gates the bots filter, not the
    /// list at large.
    func test_whitelisted_account_still_visible_without_bots_filter() {
        let f = FollowerFilters()
        let normal = account(did: "1", handle: "alice", botScore: 0.85)
        let pardoned = account(did: "2", handle: "bob", botScore: 0.85)
            .withWhitelist(true)
        let result = f.apply(to: [normal, pardoned]).map(\.handle).sorted()
        XCTAssertEqual(result, ["alice", "bob"])
    }

    /// Low-score whitelist is a no-op (the bots filter would have
    /// excluded the row anyway). Sanity check that withWhitelist
    /// doesn't accidentally INCLUDE low-score rows.
    func test_lowScore_whitelisted_account_still_excluded_from_bots_filter() {
        var f = FollowerFilters()
        f.showBots = true
        let row = account(did: "1", handle: "carol", botScore: 0.15)
            .withWhitelist(true)
        XCTAssertTrue(f.apply(to: [row]).isEmpty)
    }

    /// withWhitelist(_:) returns a NEW struct rather than mutating.
    /// Confirms the immutable-struct convention holds.
    func test_withWhitelist_returnsNewStruct_originalUnchanged() {
        let original = account(did: "1", handle: "dan", botScore: 0.85)
        XCTAssertFalse(original.userWhitelisted)
        let pardoned = original.withWhitelist(true)
        XCTAssertFalse(original.userWhitelisted, "original should not have mutated")
        XCTAssertTrue(pardoned.userWhitelisted)
        XCTAssertEqual(original.did, pardoned.did, "identity preserved")
    }

    // MARK: - Bot sensitivity presets

    /// Default threshold (0.6 = Balanced) matches the historical
    /// hardcoded behavior — the 0.85 account passes, the 0.55 doesn't.
    func test_botThreshold_default_matchesHistoricalBehavior() {
        var f = FollowerFilters()
        f.showBots = true
        let high = account(did: "1", handle: "high", botScore: 0.85)
        let mid  = account(did: "2", handle: "mid",  botScore: 0.55)
        let low  = account(did: "3", handle: "low",  botScore: 0.20)
        let result = f.apply(to: [high, mid, low]).map(\.handle)
        XCTAssertEqual(result, ["high"])
    }

    /// Strict (0.8) shows fewer accounts; the 0.65 mid-range account
    /// passes Balanced but fails Strict.
    func test_botThreshold_strict_excludesMidRange() {
        var f = FollowerFilters()
        f.showBots = true
        f.botThreshold = 0.8
        let high = account(did: "1", handle: "high", botScore: 0.85)
        let mid  = account(did: "2", handle: "mid",  botScore: 0.65)
        let result = f.apply(to: [high, mid]).map(\.handle)
        XCTAssertEqual(result, ["high"])
    }

    /// Loose (0.4) includes accounts the Balanced threshold would drop.
    /// This is the slider-equivalent footgun the safety committee warned
    /// about — captured here so future regressions don't accidentally
    /// disable the threshold field.
    func test_botThreshold_loose_includesLowConfidence() {
        var f = FollowerFilters()
        f.showBots = true
        f.botThreshold = 0.4
        let high = account(did: "1", handle: "high", botScore: 0.85)
        let mid  = account(did: "2", handle: "mid",  botScore: 0.55)
        let lowMed = account(did: "3", handle: "lowMed", botScore: 0.45)
        let belowLoose = account(did: "4", handle: "belowLoose", botScore: 0.20)
        let result = Set(f.apply(to: [high, mid, lowMed, belowLoose]).map(\.handle))
        XCTAssertEqual(result, ["high", "mid", "lowMed"])
    }

    /// Whitelist still wins over Loose. The dignity affordance can't
    /// be defeated by lowering sensitivity.
    func test_botThreshold_loose_respectsWhitelist() {
        var f = FollowerFilters()
        f.showBots = true
        f.botThreshold = 0.4
        let scored = account(did: "1", handle: "scored", botScore: 0.5)
        let pardoned = account(did: "2", handle: "pardoned", botScore: 0.5)
            .withWhitelist(true)
        let result = f.apply(to: [scored, pardoned]).map(\.handle)
        XCTAssertEqual(result, ["scored"])
    }
}
