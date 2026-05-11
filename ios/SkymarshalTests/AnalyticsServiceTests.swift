import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class AnalyticsServiceTests: XCTestCase {

    func testDeadThreadCountsZeros() {
        let dead = ContentItem(
            uri: "at://did/post/1",
            cid: "c1",
            contentType: .posts,
            text: "hello",
            likeCount: 0,
            repostCount: 0,
            replyCount: 0
        )
        let alive = ContentItem(
            uri: "at://did/post/2",
            cid: "c2",
            contentType: .posts,
            text: "world",
            likeCount: 1,
            repostCount: 0,
            replyCount: 0
        )
        let snap = AnalyticsService.buildSnapshot(from: [dead, alive])
        XCTAssertEqual(snap.postAndReplyCount, 2)
        XCTAssertEqual(snap.deadThreadCount, 1)
    }

    func testHighEngagementThreshold() {
        let hi = ContentItem(
            uri: "at://did/post/x",
            cid: "cx",
            contentType: .posts,
            likeCount: 25,
            repostCount: 0,
            replyCount: 0
        )
        let snap = AnalyticsService.buildSnapshot(from: [hi], highEngagementThreshold: 20)
        XCTAssertEqual(snap.highEngagementCount, 1)
    }

    func testTokenizeSkipsShortWords() {
        let it = ContentItem(
            uri: "at://did/post/t",
            cid: "ct",
            contentType: .posts,
            text: "aa bb capybara capybara",
            likeCount: 0,
            repostCount: 0,
            replyCount: 0
        )
        let snap = AnalyticsService.buildSnapshot(from: [it], topTokenLimit: 10)
        XCTAssertTrue(snap.topTokens.contains { $0.token == "capybara" && $0.count == 2 })
    }

    func testContentSortOrderNewest() {
        let old = ContentItem(
            uri: "at://a",
            cid: "1",
            contentType: .posts,
            createdAt: Date(timeIntervalSince1970: 100),
            likeCount: 0,
            repostCount: 0,
            replyCount: 0
        )
        let new = ContentItem(
            uri: "at://b",
            cid: "2",
            contentType: .posts,
            createdAt: Date(timeIntervalSince1970: 200),
            likeCount: 0,
            repostCount: 0,
            replyCount: 0
        )
        let sorted = ContentSortOrder.newestCreated.sort([old, new])
        XCTAssertEqual(sorted.first?.uri, new.uri)
    }
}
