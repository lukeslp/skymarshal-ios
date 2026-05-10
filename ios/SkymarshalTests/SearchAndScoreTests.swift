import XCTest
@testable import SkymarshalCore

final class SearchAndScoreTests: XCTestCase {

    // MARK: - Engagement score

    func test_engagementScore_usesPython25ReplyWeight() {
        // Python: 1×likes + 2×reposts + 2.5×replies. The TS port uses 1/2/3
        // — MIGRATION.md commits the Swift port to follow Python.
        XCTAssertEqual(EngagementScore.compute(likes: 0, reposts: 0, replies: 0), 0)
        XCTAssertEqual(EngagementScore.compute(likes: 10, reposts: 0, replies: 0), 10)
        XCTAssertEqual(EngagementScore.compute(likes: 0, reposts: 5, replies: 0), 10)
        XCTAssertEqual(EngagementScore.compute(likes: 0, reposts: 0, replies: 4), 10)
        XCTAssertEqual(EngagementScore.compute(likes: 1, reposts: 1, replies: 1), 5.5)
    }

    func test_contentItem_engagementScore_isComputedFromCounts() {
        let item = ContentItem(
            uri: "at://x/y/z",
            cid: "c",
            contentType: .posts,
            likeCount: 10,
            repostCount: 4,
            replyCount: 2
        )
        XCTAssertEqual(item.engagementScore, 10 + 8 + 5)
    }

    // MARK: - Media filter + alt text search

    func test_search_byMediaFilter_onlyMedia() {
        let withMedia = ContentItem(
            uri: "a", cid: "1", contentType: .posts,
            media: [MediaPreview(kind: .image, alt: "a cat")]
        )
        let noMedia = ContentItem(uri: "b", cid: "2", contentType: .posts)
        var req = SearchRequest()
        req.mediaFilter = .onlyMedia
        let out = req.apply(to: [withMedia, noMedia])
        XCTAssertEqual(out.map(\.uri), ["a"])
    }

    func test_search_byMediaFilter_noMedia() {
        let withMedia = ContentItem(
            uri: "a", cid: "1", contentType: .posts,
            media: [MediaPreview(kind: .image, alt: "a cat")]
        )
        let noMedia = ContentItem(uri: "b", cid: "2", contentType: .posts)
        var req = SearchRequest()
        req.mediaFilter = .noMedia
        let out = req.apply(to: [withMedia, noMedia])
        XCTAssertEqual(out.map(\.uri), ["b"])
    }

    func test_search_keyword_hitsAltText_whenIncludeAltTextOn() {
        let item = ContentItem(
            uri: "a", cid: "1", contentType: .posts,
            text: "look at this",
            media: [MediaPreview(kind: .image, alt: "a sleepy capybara in a hot spring")]
        )
        var req = SearchRequest(keyword: "capybara", includeAltTextInKeyword: true)
        XCTAssertEqual(req.apply(to: [item]).count, 1)
    }

    func test_search_keyword_skipsAltText_whenIncludeAltTextOff() {
        let item = ContentItem(
            uri: "a", cid: "1", contentType: .posts,
            text: "look at this",
            media: [MediaPreview(kind: .image, alt: "a sleepy capybara")]
        )
        var req = SearchRequest(keyword: "capybara", includeAltTextInKeyword: false)
        XCTAssertEqual(req.apply(to: [item]).count, 0)
    }

    func test_altText_concatenatesAcrossMultipleImages() {
        let item = ContentItem(
            uri: "a", cid: "1", contentType: .posts,
            media: [
                MediaPreview(kind: .image, alt: "first photo"),
                MediaPreview(kind: .image, alt: "second photo"),
                MediaPreview(kind: .image, alt: nil),
            ]
        )
        XCTAssertTrue(item.altText.contains("first photo"))
        XCTAssertTrue(item.altText.contains("second photo"))
    }

    func test_hasMedia_isDerivedFromMediaList() {
        XCTAssertFalse(ContentItem(uri: "a", cid: "1", contentType: .posts).hasMedia)
        XCTAssertTrue(ContentItem(
            uri: "a", cid: "1", contentType: .posts,
            media: [MediaPreview(kind: .image)]
        ).hasMedia)
    }

    // MARK: - SearchRequest filtering

    private func sampleItems() -> [ContentItem] {
        return [
            ContentItem(uri: "at://a/post/1", cid: "1", contentType: .posts,
                        text: "hello world", createdAt: Date(timeIntervalSince1970: 100),
                        likeCount: 1, repostCount: 0, replyCount: 0),
            ContentItem(uri: "at://a/post/2", cid: "2", contentType: .posts,
                        text: "FOOBAR is great", createdAt: Date(timeIntervalSince1970: 200),
                        likeCount: 50, repostCount: 5, replyCount: 2),
            ContentItem(uri: "at://a/post/3", cid: "3", contentType: .replies,
                        text: "reply text", createdAt: Date(timeIntervalSince1970: 300),
                        likeCount: 0, repostCount: 0, replyCount: 0),
            ContentItem(uri: "at://a/post/4", cid: "4", contentType: .reposts,
                        text: nil, createdAt: Date(timeIntervalSince1970: 400),
                        likeCount: 0, repostCount: 0, replyCount: 0),
            ContentItem(uri: "at://a/post/5", cid: "5", contentType: .likes,
                        text: nil, createdAt: Date(timeIntervalSince1970: 500),
                        likeCount: 0, repostCount: 0, replyCount: 0),
        ]
    }

    func test_search_byKeyword_isCaseInsensitive() {
        var req = SearchRequest()
        req.keyword = "FOObar"
        let results = req.apply(to: sampleItems())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.uri, "at://a/post/2")
    }

    func test_search_byContentType_filtersToSubset() {
        var req = SearchRequest()
        req.contentTypes = [.posts]
        let results = req.apply(to: sampleItems())
        XCTAssertEqual(results.count, 2)
    }

    func test_search_byContentType_allBypasses() {
        var req = SearchRequest()
        req.contentTypes = [.all]
        XCTAssertEqual(req.apply(to: sampleItems()).count, sampleItems().count)
    }

    func test_search_byEngagementBounds() {
        var req = SearchRequest()
        req.likes = 10...100
        let results = req.apply(to: sampleItems())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.uri, "at://a/post/2")
    }

    func test_search_byDateRange() {
        var req = SearchRequest()
        req.startDate = Date(timeIntervalSince1970: 250)
        req.endDate = Date(timeIntervalSince1970: 350)
        let results = req.apply(to: sampleItems())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.uri, "at://a/post/3")
    }

    func test_search_byExcludedUris() {
        var req = SearchRequest()
        req.excludedUris = ["at://a/post/1", "at://a/post/2"]
        let uris = req.apply(to: sampleItems()).map(\.uri)
        XCTAssertFalse(uris.contains("at://a/post/1"))
        XCTAssertFalse(uris.contains("at://a/post/2"))
        XCTAssertEqual(uris.count, 3)
    }

    func test_search_filtersAndIsCombinatorial() {
        var req = SearchRequest()
        req.keyword = "great"
        req.contentTypes = [.posts]
        req.likes = 10...100
        let results = req.apply(to: sampleItems())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.uri, "at://a/post/2")
    }

    func test_search_respectsLimit() {
        var req = SearchRequest(limit: 2)
        XCTAssertEqual(req.apply(to: sampleItems()).count, 2)
    }

    func test_hasActiveFilters_falseWhenAllNil() {
        XCTAssertFalse(SearchRequest().hasActiveFilters)
    }

    func test_hasActiveFilters_trueWhenAnythingSet() {
        var req = SearchRequest()
        req.keyword = "x"
        XCTAssertTrue(req.hasActiveFilters)
    }

    // MARK: - Engagement cache TTL tiers

    func test_engagementCacheTTL_tiersFollowPython() {
        // From reference/python/engagement_cache.py:236-270
        let now = Date(timeIntervalSince1970: 100_000_000)
        let day: TimeInterval = 86_400

        XCTAssertEqual(now.addingTimeInterval(-1 * day).engagementCacheTTL(now: now), 3_600)
        XCTAssertEqual(now.addingTimeInterval(-10 * day).engagementCacheTTL(now: now), 21_600)
        XCTAssertEqual(now.addingTimeInterval(-50 * day).engagementCacheTTL(now: now), 86_400)
        XCTAssertEqual(now.addingTimeInterval(-100 * day).engagementCacheTTL(now: now), 604_800)
    }

    // MARK: - Handle normalization

    func test_normalizeHandle_addsBskySocialIfMissingDot() {
        XCTAssertEqual(ContentService.normalizeHandle("alice"), "alice.bsky.social")
    }

    func test_normalizeHandle_stripsAtSign() {
        XCTAssertEqual(ContentService.normalizeHandle("@bob.bsky.social"), "bob.bsky.social")
    }

    func test_normalizeHandle_lowercasesAndTrims() {
        XCTAssertEqual(ContentService.normalizeHandle("  ALICE.BSKY.SOCIAL  "), "alice.bsky.social")
    }

    func test_normalizeHandle_keepsFullDomainAsIs() {
        XCTAssertEqual(ContentService.normalizeHandle("luke.example.com"), "luke.example.com")
    }
}
