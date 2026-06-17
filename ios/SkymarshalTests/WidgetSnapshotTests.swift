import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class WidgetSnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func profile(
        did: String,
        handle: String,
        displayName: String? = nil,
        followers: Int = 100,
        following: Int = 100
    ) -> BskyProfile {
        BskyProfile(
            did: did,
            handle: handle,
            displayName: displayName,
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: followers,
            followsCount: following,
            postsCount: 10,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            labels: nil,
            viewer: nil
        )
    }

    private func account(
        did: String,
        handle: String,
        displayName: String? = nil,
        engagementScore: Double = 0,
        interactedRecently: Bool? = nil,
        isMutual: Bool = false,
        lastPostDate: Date? = nil
    ) -> AnalyzedAccount {
        AnalyzedAccount(
            profile: profile(did: did, handle: handle, displayName: displayName),
            ratio: 1.0,
            botScore: 0,
            botFlags: [],
            influenceScore: 0,
            influenceTier: .nano,
            accountAgeDays: 100,
            postsPerDay: 1,
            profileCompleteness: 1,
            lastPostDate: lastPostDate,
            daysSinceLastPost: nil,
            isInactive: false,
            isDeleted: false,
            isMutual: isMutual,
            engagementScore: engagementScore,
            interactedRecently: interactedRecently
        )
    }

    private func contentItem(
        uri: String,
        text: String,
        likes: Int,
        reposts: Int,
        replies: Int,
        type: ContentType = .posts
    ) -> ContentItem {
        ContentItem(
            uri: uri,
            cid: "cid-\(uri)",
            deletionURI: nil,
            contentType: type,
            text: text,
            createdAt: Date(),
            likeCount: likes,
            repostCount: reposts,
            replyCount: replies,
            media: [],
            linkCard: nil,
            textLinks: [],
            parentReplyURI: nil,
            subjectAuthorHandle: nil
        )
    }

    // MARK: - Codec round-trip

    func testWidgetSnapshotCodecRoundTrip() throws {
        let original = WidgetSnapshot.placeholder
        let restored = try WidgetSnapshotStore.roundTrip(original)
        XCTAssertEqual(original, restored)
    }

    func testEmptySnapshotRoundTrips() throws {
        let original = WidgetSnapshot.empty
        let restored = try WidgetSnapshotStore.roundTrip(original)
        XCTAssertEqual(original.hygieneSummary, restored.hygieneSummary)
        XCTAssertTrue(restored.peopleToEngage.isEmpty)
        XCTAssertNil(restored.topPost)
    }

    // MARK: - Builder

    func testBuilderRanksFansByEngagement() {
        let accounts = [
            account(did: "did:a", handle: "low.bsky.social", engagementScore: 1, interactedRecently: true),
            account(did: "did:b", handle: "high.bsky.social", displayName: "High", engagementScore: 9, interactedRecently: true),
            account(did: "did:c", handle: "mutual.bsky.social", engagementScore: 20, interactedRecently: true, isMutual: true)
        ]
        let summary = ScanSummary(totalAnalyzed: 3, inactive: 1, disengaged: 1, mutuals: 1)
        let snapshot = WidgetSnapshotBuilder.build(
            accounts: accounts, summary: summary, items: [], followerCount: 200
        )
        // Mutual is excluded; highest engagement first.
        XCTAssertEqual(snapshot.peopleToEngage.map(\.handle), ["high.bsky.social", "low.bsky.social"])
        XCTAssertEqual(snapshot.peopleToEngage.first?.theyEngagedYou, 9)
    }

    func testBuilderPicksTopPost() {
        let items = [
            contentItem(uri: "at://x/1", text: "small", likes: 1, reposts: 0, replies: 0),
            contentItem(uri: "at://x/2", text: "big", likes: 50, reposts: 10, replies: 5),
            contentItem(uri: "at://x/3", text: "a like", likes: 0, reposts: 0, replies: 0, type: .likes)
        ]
        let snapshot = WidgetSnapshotBuilder.build(
            accounts: [], summary: ScanSummary(), items: items, followerCount: 0
        )
        XCTAssertEqual(snapshot.topPost?.text, "big")
        XCTAssertEqual(snapshot.topPost?.likeCount, 50)
    }

    func testBuilderHygieneUsesExplicitFollowerCount() {
        let summary = ScanSummary(totalAnalyzed: 100, inactive: 20, disengaged: 30, mutuals: 40)
        let snapshot = WidgetSnapshotBuilder.build(
            accounts: [], summary: summary, items: [], followerCount: 250
        )
        XCTAssertEqual(snapshot.hygieneSummary.follows, 100)
        XCTAssertEqual(snapshot.hygieneSummary.followers, 250)
        XCTAssertEqual(snapshot.hygieneSummary.ghosts, 30)
        XCTAssertEqual(snapshot.hygieneSummary.inactive, 20)
        XCTAssertEqual(snapshot.hygieneSummary.ratio, 2.5, accuracy: 0.001)
    }

    func testBuilderHistoryAppendsOnePerDayDeduped() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let previous = [
            WidgetSnapshot.FollowerPoint(date: yesterday, count: 100),
            WidgetSnapshot.FollowerPoint(date: today, count: 110) // stale today point
        ]
        let summary = ScanSummary(totalAnalyzed: 50, mutuals: 10)
        let snapshot = WidgetSnapshotBuilder.build(
            accounts: [], summary: summary, items: [],
            followerCount: 125, previousHistory: previous
        )
        // Yesterday kept, today replaced with the fresh 125.
        XCTAssertEqual(snapshot.followerHistory.count, 2)
        XCTAssertEqual(snapshot.followerHistory.last?.count, 125)
    }
}
