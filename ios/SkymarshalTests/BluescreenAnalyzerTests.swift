import XCTest
@testable import SkymarshalCore

final class BluescreenAnalyzerTests: XCTestCase {

    // MARK: - Helpers

    private func profile(
        handle: String = "test.bsky.social",
        displayName: String? = "Test User",
        description: String? = "A bio",
        avatar: String? = "https://x/y",
        banner: String? = "https://x/b",
        followers: Int = 100,
        following: Int = 100,
        posts: Int = 50,
        ageDays: Int = 365
    ) -> BskyProfile {
        let createdAt = ISO8601DateFormatter().string(
            from: Date(timeIntervalSince1970: Date().timeIntervalSince1970 - Double(ageDays) * 86_400)
        )
        return BskyProfile(
            did: "did:plc:test",
            handle: handle,
            displayName: displayName,
            description: description,
            avatar: avatar,
            banner: banner,
            followersCount: followers,
            followsCount: following,
            postsCount: posts,
            createdAt: createdAt
        )
    }

    // MARK: - ratio

    func test_ratio_zeroFollowing_zeroFollowers_returnsZero() {
        XCTAssertEqual(BluescreenAnalyzer.ratio(followers: 0, following: 0), 0)
    }

    func test_ratio_zeroFollowing_someFollowers_returnsSentinel() {
        XCTAssertEqual(BluescreenAnalyzer.ratio(followers: 5, following: 0), 999)
    }

    func test_ratio_normal() {
        XCTAssertEqual(BluescreenAnalyzer.ratio(followers: 100, following: 50), 2.0)
    }

    // MARK: - botScore

    func test_botScore_handleInvalid_short_circuits_to_one() {
        let p = profile(handle: "handle.invalid")
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertEqual(result.score, 1.0)
        XCTAssertEqual(result.flags, ["Deleted account (handle.invalid)"])
    }

    func test_botScore_massFollowing_veryLowRatio_scoresHigh() {
        let p = profile(followers: 30, following: 1000)
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertGreaterThanOrEqual(result.score, 0.6)
        XCTAssertTrue(result.flags.contains { $0.contains("Mass following") })
    }

    func test_botScore_zeroPosts_highFollowing_flagsAndScores() {
        let p = profile(followers: 100, following: 200, posts: 0)
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertGreaterThanOrEqual(result.score, 0.6)
        XCTAssertTrue(result.flags.contains { $0.contains("No posts") })
    }

    func test_botScore_missingThreeProfileFields_addsFactor() {
        let p = profile(displayName: nil, description: nil, avatar: nil)
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertGreaterThan(result.score, 0)
        XCTAssertTrue(result.flags.contains { $0.contains("Missing") })
    }

    func test_botScore_roundNumberFollowing_addsLowWeightFactor() {
        // Exactly 200 follows, normal ratio, full profile — only the
        // "round number following" factor should fire (low weight).
        let p = profile(followers: 200, following: 200)
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertGreaterThan(result.score, 0)
        XCTAssertTrue(result.flags.contains { $0.contains("Round number") })
    }

    func test_botScore_newAccountAggressiveFollowing_flags() {
        let p = profile(following: 200, ageDays: 5)
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertGreaterThan(result.score, 0)
        XCTAssertTrue(result.flags.contains { $0.contains("New account") })
    }

    func test_botScore_normalUser_isZero() {
        // following=183 deliberately non-round to avoid the round-number
        // factor (which fires on multiples of 50 above 50, of 100 above 100).
        let p = profile(followers: 234, following: 183, posts: 87)
        XCTAssertEqual(BluescreenAnalyzer.botScore(for: p).score, 0)
    }

    func test_botScore_unknownAge_doesNotFireNewAccountFactor() {
        // REGRESSION: when getFollows returns ProfileView without a
        // createdAt field, BskyProfile.createdAt defaults to "" and
        // createdDate returns nil. Earlier versions treated that as
        // ageDays=0 and falsely fired "New account, aggressive following"
        // for every account with > 100 follows. With ~1300 follows a
        // user might have, that gave a 95+% false-positive bot rate.
        // Fix: skip age-based factors entirely when age is unknown.
        let p = BskyProfile(
            did: "did:plc:x",
            handle: "real-user.bsky.social",
            displayName: "Real User",
            description: "real bio",
            avatar: "https://x/y",
            banner: "https://x/b",
            followersCount: 15_195,    // nicky-woolf-shaped real account
            followsCount: 3_122,
            postsCount: 1_000,
            createdAt: ""              // ← the bug case: missing date
        )
        let result = BluescreenAnalyzer.botScore(for: p)
        XCTAssertEqual(result.score, 0,
                       "Real-shaped accounts with unknown age must not score as bots")
        XCTAssertFalse(result.flags.contains { $0.contains("New account") })
        XCTAssertFalse(result.flags.contains { $0.contains("Young account") })
    }

    // MARK: - influence

    func test_influenceScore_largerFollower_higherScore() {
        let small = profile(followers: 50, following: 100)
        let big   = profile(followers: 50_000, following: 100)
        XCTAssertGreaterThan(
            BluescreenAnalyzer.influenceScore(for: big),
            BluescreenAnalyzer.influenceScore(for: small)
        )
    }

    func test_influenceTier_thresholds() {
        XCTAssertEqual(BluescreenAnalyzer.influenceTier(for: 200_000), .mega)
        XCTAssertEqual(BluescreenAnalyzer.influenceTier(for: 50_000), .macro)
        XCTAssertEqual(BluescreenAnalyzer.influenceTier(for: 5_000), .micro)
        XCTAssertEqual(BluescreenAnalyzer.influenceTier(for: 50), .nano)
    }

    // MARK: - completeness

    func test_completeness_fullProfile_isOne() {
        XCTAssertEqual(BluescreenAnalyzer.profileCompleteness(for: profile()), 1.0)
    }

    func test_completeness_emptyProfile_isZero() {
        let p = profile(displayName: "", description: "", avatar: nil, banner: nil, posts: 0)
        XCTAssertEqual(BluescreenAnalyzer.profileCompleteness(for: p), 0)
    }

    func test_completeness_missingBannerAndPosts_is_075() {
        let p = profile(banner: nil, posts: 0)
        XCTAssertEqual(BluescreenAnalyzer.profileCompleteness(for: p), 0.75)
    }

    // MARK: - analyze + summarize

    func test_analyze_inactiveByZeroPosts() {
        let p = profile(posts: 0)
        let acc = BluescreenAnalyzer.analyze(profile: p)
        XCTAssertTrue(acc.isInactive)
    }

    func test_analyze_inactiveByLastPostBeyondThreshold() {
        let p = profile()
        let lastPost = Date().addingTimeInterval(-100 * 86_400)
        let acc = BluescreenAnalyzer.analyze(profile: p, lastPostDate: lastPost, inactivityDays: 90)
        XCTAssertTrue(acc.isInactive)
        XCTAssertEqual(acc.daysSinceLastPost, 100)
    }

    func test_analyze_mutualFromViewerFollowedBy() {
        var p = profile()
        p = BskyProfile(
            did: p.did, handle: p.handle, displayName: p.displayName,
            description: p.description, avatar: p.avatar, banner: p.banner,
            followersCount: p.followersCount, followsCount: p.followsCount,
            postsCount: p.postsCount, createdAt: p.createdAt,
            viewer: .init(followedBy: "at://them/follow/123")
        )
        XCTAssertTrue(BluescreenAnalyzer.analyze(profile: p).isMutual)
    }

    func test_summary_botsCount_uses06Threshold() {
        let bot = BluescreenAnalyzer.analyze(profile: profile(handle: "handle.invalid"))
        let normal = BluescreenAnalyzer.analyze(profile: profile())
        let s = BluescreenAnalyzer.summarize([bot, bot, normal])
        XCTAssertEqual(s.bots, 2)
        XCTAssertEqual(s.deleted, 2)
        XCTAssertEqual(s.totalAnalyzed, 3)
    }

    func test_summary_emptyInputReturnsZeroes() {
        let s = BluescreenAnalyzer.summarize([])
        XCTAssertEqual(s.totalAnalyzed, 0)
        XCTAssertEqual(s.avgBotScore, 0)
    }

    // MARK: - BskyProfile decode tolerance (regression for empty-scan bug)

    func test_bskyProfile_decodes_when_count_fields_missing() throws {
        // ProfileView from app.bsky.graph.getFollows lacks the *Count
        // fields and createdAt — they only appear on ProfileViewDetailed
        // from getProfiles. Without decode tolerance, the WHOLE follow
        // list fails to decode and the scan silently dies.
        let json = #"{"did":"did:plc:x","handle":"alice.bsky.social","displayName":"Alice"}"#
        let profile = try JSONDecoder().decode(BskyProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.handle, "alice.bsky.social")
        XCTAssertEqual(profile.followersCount, 0)
        XCTAssertEqual(profile.followsCount, 0)
        XCTAssertEqual(profile.postsCount, 0)
        XCTAssertEqual(profile.createdAt, "")
    }

    func test_bskyProfile_decodes_full_detailed_shape() throws {
        // ProfileViewDetailed shape with all the count fields.
        let json = """
        {"did":"did:plc:x","handle":"bob.bsky.social","displayName":"Bob",
         "followersCount":100,"followsCount":50,"postsCount":12,
         "createdAt":"2024-01-15T00:00:00Z"}
        """
        let profile = try JSONDecoder().decode(BskyProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.followersCount, 100)
        XCTAssertEqual(profile.followsCount, 50)
        XCTAssertEqual(profile.postsCount, 12)
        XCTAssertEqual(profile.createdAt, "2024-01-15T00:00:00Z")
    }

    func test_getFollowsResponse_decodes_array_of_basic_profiles() throws {
        let json = """
        {"follows":[
          {"did":"did:plc:1","handle":"a.bsky.social"},
          {"did":"did:plc:2","handle":"b.bsky.social","displayName":"B"}
        ],"cursor":"abc123"}
        """
        let response = try JSONDecoder().decode(GetFollowsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.follows.count, 2)
        XCTAssertEqual(response.cursor, "abc123")
        XCTAssertEqual(response.follows[1].displayName, "B")
    }
}
