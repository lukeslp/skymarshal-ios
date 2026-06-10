import XCTest
@testable import SkymarshalCore

final class ATProtoDateTests: XCTestCase {

    // MARK: - Parser

    func test_parse_fractionalSeconds() {
        // The official Bluesky clients write fractional seconds; a bare
        // ISO8601DateFormatter returns nil for these, which is how the
        // date-filter over-deletion bug happened.
        let date = ATProtoDate.parse("2024-03-01T18:22:47.123Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1_709_317_367.123, accuracy: 0.001)
    }

    func test_parse_wholeSeconds() {
        let date = ATProtoDate.parse("2024-03-01T18:22:47Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970, 1_709_317_367)
    }

    func test_parse_timezoneOffsetWithFractionalSeconds() {
        let date = ATProtoDate.parse("2024-03-01T18:22:47.500+02:00")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1_709_310_167.5, accuracy: 0.001)
    }

    func test_parse_garbageNilAndEmpty() {
        XCTAssertNil(ATProtoDate.parse("not a date"))
        XCTAssertNil(ATProtoDate.parse(""))
        XCTAssertNil(ATProtoDate.parse(nil))
        XCTAssertNil(ATProtoDate.parse("2024-13-45T99:99:99Z"))
    }

    // MARK: - Fail-closed date predicates

    private func item(uri: String, createdAt: Date?) -> ContentItem {
        ContentItem(uri: uri, cid: "c", contentType: .posts, createdAt: createdAt)
    }

    func test_dateFilter_excludesNilDatedItems() {
        // A nil createdAt must never satisfy an active date filter —
        // otherwise "delete before <date>" selects unparsed-date items too.
        let dated = item(uri: "dated", createdAt: Date(timeIntervalSince1970: 100))
        let undated = item(uri: "undated", createdAt: nil)

        let before = SearchRequest(endDate: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(before.apply(to: [dated, undated]).map(\.uri), ["dated"])

        let after = SearchRequest(startDate: Date(timeIntervalSince1970: 50))
        XCTAssertEqual(after.apply(to: [dated, undated]).map(\.uri), ["dated"])

        let range = SearchRequest(
            startDate: Date(timeIntervalSince1970: 50),
            endDate: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(range.apply(to: [dated, undated]).map(\.uri), ["dated"])
    }

    func test_noDateFilter_keepsNilDatedItems() {
        let undated = item(uri: "undated", createdAt: nil)
        let req = SearchRequest()
        XCTAssertEqual(req.apply(to: [undated]).map(\.uri), ["undated"])
    }

    func test_dateFilter_boundsAreInclusiveOfInRangeItems() {
        let inside = item(uri: "inside", createdAt: Date(timeIntervalSince1970: 300))
        let early = item(uri: "early", createdAt: Date(timeIntervalSince1970: 10))
        let late = item(uri: "late", createdAt: Date(timeIntervalSince1970: 900))
        let req = SearchRequest(
            startDate: Date(timeIntervalSince1970: 250),
            endDate: Date(timeIntervalSince1970: 350)
        )
        XCTAssertEqual(req.apply(to: [inside, early, late]).map(\.uri), ["inside"])
    }
}
