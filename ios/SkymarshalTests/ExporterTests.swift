import XCTest
@testable import SkymarshalCore

final class ExporterTests: XCTestCase {

    // MARK: - Fixtures

    private func sampleItem(uri: String = "at://did:plc:x/app.bsky.feed.post/abc",
                            text: String = "hello world",
                            type: ContentType = .posts) -> ContentItem {
        ContentItem(
            uri: uri, cid: "cid-1", contentType: type,
            text: text, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            likeCount: 10, repostCount: 2, replyCount: 1
        )
    }

    private func sampleAccount() -> AnalyzedAccount {
        let createdAt = ISO8601DateFormatter().string(
            from: Date(timeIntervalSince1970: 1_650_000_000)
        )
        let profile = BskyProfile(
            did: "did:plc:test",
            handle: "alice.bsky.social",
            displayName: "Alice",
            description: "bio",
            avatar: "https://x/y",
            banner: "https://x/b",
            followersCount: 1500,
            followsCount: 300,
            postsCount: 800,
            createdAt: createdAt
        )
        return BluescreenAnalyzer.analyze(profile: profile)
    }

    // MARK: - Content JSON

    func test_contentJSON_roundTripsThroughJSONDecoder() throws {
        let payload = try Exporter.contentJSON(
            [sampleItem(), sampleItem(uri: "at://x/y/2", type: .replies)],
            handle: "luke.bsky.social"
        )
        XCTAssertEqual(payload.mimeType, "application/json")
        XCTAssertTrue(payload.suggestedFilename.hasSuffix(".json"))

        struct Envelope: Decodable {
            let handle: String?
            let exportedAt: String
            let itemCount: Int
            let items: [Row]
        }
        struct Row: Decodable {
            let uri: String
            let contentType: String
            let likeCount: Int
        }

        let env = try JSONDecoder().decode(Envelope.self, from: payload.data)
        XCTAssertEqual(env.handle, "luke.bsky.social")
        XCTAssertEqual(env.itemCount, 2)
        XCTAssertEqual(env.items.count, 2)
        XCTAssertEqual(env.items.first?.likeCount, 10)
    }

    func test_contentJSON_emptyInput_yieldsValidEmptyEnvelope() throws {
        let payload = try Exporter.contentJSON([], handle: nil)
        struct Envelope: Decodable { let itemCount: Int; let items: [Empty] }
        struct Empty: Decodable {}
        let env = try JSONDecoder().decode(Envelope.self, from: payload.data)
        XCTAssertEqual(env.itemCount, 0)
        XCTAssertTrue(env.items.isEmpty)
    }

    // MARK: - Content CSV

    func test_contentCSV_includesHeaderAndRow() {
        let payload = Exporter.contentCSV([sampleItem()])
        XCTAssertEqual(payload.mimeType, "text/csv")
        let csv = String(data: payload.data, encoding: .utf8) ?? ""
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertGreaterThanOrEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("uri"))
        XCTAssertTrue(lines[0].contains("contentType"))
        XCTAssertTrue(lines[0].contains("text"))
    }

    func test_contentCSV_escapesEmbeddedCommasQuotesNewlines() {
        let trickyItem = ContentItem(
            uri: "at://x/y/z",
            cid: "cid",
            contentType: .posts,
            text: "Line1, with comma\nLine2 with \"quotes\""
        )
        let payload = Exporter.contentCSV([trickyItem])
        let csv = String(data: payload.data, encoding: .utf8) ?? ""
        // The text field should be quoted and have its embedded quotes doubled.
        XCTAssertTrue(csv.contains("\"\"quotes\"\""),
                      "Embedded double-quotes must be doubled per RFC 4180")
        // The whole text should be wrapped in outer quotes since it contains
        // commas, quotes, and newlines.
        XCTAssertTrue(csv.contains("\"Line1, with comma"),
                      "Field with comma should be wrapped in quotes")
    }

    // MARK: - Followers

    func test_followersJSON_includesAccountCountAndScoredFields() throws {
        let payload = try Exporter.followersJSON([sampleAccount()], handle: "luke.bsky.social")
        XCTAssertEqual(payload.mimeType, "application/json")

        struct Envelope: Decodable {
            let handle: String?
            let accountCount: Int
            let accounts: [Row]
        }
        struct Row: Decodable {
            let did: String
            let handle: String
            let botScore: Double
            let isMutual: Bool
        }
        let env = try JSONDecoder().decode(Envelope.self, from: payload.data)
        XCTAssertEqual(env.handle, "luke.bsky.social")
        XCTAssertEqual(env.accountCount, 1)
        XCTAssertEqual(env.accounts.first?.handle, "alice.bsky.social")
    }

    func test_followersCSV_includesScoringColumns() {
        let payload = Exporter.followersCSV([sampleAccount()])
        let csv = String(data: payload.data, encoding: .utf8) ?? ""
        XCTAssertTrue(csv.contains("did,handle"))
        XCTAssertTrue(csv.contains("botScore"))
        XCTAssertTrue(csv.contains("isMutual"))
        XCTAssertTrue(csv.contains("alice.bsky.social"))
    }

    // MARK: - csvEscape unit

    func test_csvEscape_passThroughForPlainStrings() {
        XCTAssertEqual(Exporter.csvEscape("plain"), "plain")
    }

    func test_csvEscape_quotesCommaContainingStrings() {
        XCTAssertEqual(Exporter.csvEscape("a,b"), "\"a,b\"")
    }

    func test_csvEscape_doublesEmbeddedQuotes() {
        XCTAssertEqual(Exporter.csvEscape("she said \"hi\""), "\"she said \"\"hi\"\"\"")
    }
}
