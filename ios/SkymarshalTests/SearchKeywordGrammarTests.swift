import XCTest
@testable import SkymarshalCore

final class SearchKeywordGrammarTests: XCTestCase {

    func test_parse_plain_OR_twoTerms() throws {
        let c = try SearchKeywordGrammar.parse("hello world")
        XCTAssertEqual(c.count, 2)
        guard case .plain(let a) = c[0], case .plain(let b) = c[1] else {
            return XCTFail("expected two plain clauses")
        }
        XCTAssertEqual(a, "hello")
        XCTAssertEqual(b, "world")
        XCTAssertTrue(SearchKeywordGrammar.matches(haystack: "hello there", clauses: c))
        XCTAssertTrue(SearchKeywordGrammar.matches(haystack: "only world", clauses: c))
        XCTAssertFalse(SearchKeywordGrammar.matches(haystack: "neither", clauses: c))
    }

    func test_parse_required_and_excluded() throws {
        let c = try SearchKeywordGrammar.parse("+foo -bar")
        XCTAssertTrue(SearchKeywordGrammar.matches(haystack: "foo baz", clauses: c))
        XCTAssertFalse(SearchKeywordGrammar.matches(haystack: "foo bar", clauses: c))
        XCTAssertFalse(SearchKeywordGrammar.matches(haystack: "baz only", clauses: c))
    }

    func test_parse_phrase() throws {
        let c = try SearchKeywordGrammar.parse("\"hot take\"")
        guard case .phrase(let p) = c.first else { return XCTFail() }
        XCTAssertEqual(p, "hot take")
        XCTAssertTrue(SearchKeywordGrammar.matches(haystack: "my hot take here", clauses: c))
        XCTAssertFalse(SearchKeywordGrammar.matches(haystack: "hot and take", clauses: c))
    }

    func test_parse_unterminatedQuote_throws() {
        XCTAssertThrowsError(try SearchKeywordGrammar.parse("\"broken")) { error in
            XCTAssertEqual(error as? SearchKeywordGrammar.ParseError, .unterminatedQuote(0))
        }
    }

    func test_searchRequest_advancedGrammar_matches() throws {
        let item = ContentItem(uri: "a", cid: "1", contentType: .posts, text: "hello world cats")
        var req = SearchRequest()
        req.keyword = "+hello -dogs"
        req.advancedKeywordGrammar = true
        XCTAssertTrue(req.matches(item))
        let item2 = ContentItem(uri: "b", cid: "2", contentType: .posts, text: "hello dogs")
        XCTAssertFalse(req.matches(item2))
    }

    func test_searchRequest_subjectUriContains() {
        let like = ContentItem(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz",
            cid: "c",
            deletionURI: "at://me/app.bsky.feed.like/l1",
            contentType: .likes
        )
        var req = SearchRequest()
        req.subjectUriContains = "plc:abc123"
        XCTAssertTrue(req.matches(like))
        req.subjectUriContains = "other"
        XCTAssertFalse(req.matches(like))
    }

    func test_searchRequest_authorDid_inUri() {
        let post = ContentItem(uri: "at://did:plc:author/app.bsky.feed.post/rkey", cid: "c", contentType: .posts)
        var req = SearchRequest(authorDid: "plc:author")
        XCTAssertTrue(req.matches(post))
        req.authorDid = "plc:other"
        XCTAssertFalse(req.matches(post))
    }

    func test_wordBoundary_clause() throws {
        let c = try SearchKeywordGrammar.parse(#"\bcat\b"#)
        XCTAssertTrue(SearchKeywordGrammar.matches(haystack: "a cat here", clauses: c))
        XCTAssertFalse(SearchKeywordGrammar.matches(haystack: "concatenate", clauses: c))
    }
}
