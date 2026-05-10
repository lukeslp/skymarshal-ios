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
        lastPostDate: Date? = nil
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
            engagementScore: engagement, interactedRecently: nil
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

    func test_showBadRatio_catchesBothExtremes() {
        var f = FollowerFilters()
        f.showBadRatio = true
        // Frank has ratio 10000 (>50). Carol has ratio 1.0 (in safe range).
        // Add a low-ratio account to verify both sides catch.
        let extras = [account(did: "7", handle: "lowratio.bsky.social", ratio: 0.05)]
        XCTAssertEqual(Set(f.apply(to: sample + extras).map(\.handle)),
                       ["frank.bsky.social", "lowratio.bsky.social"])
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
}
