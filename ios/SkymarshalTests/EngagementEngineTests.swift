import XCTest
@testable import SkymarshalCore

/// Coverage for the conservative follow-hygiene engine: engaged
/// audience, ghost detection, and reciprocity. Network-backed cases use
/// the shared `TestURLProtocol` stub (defined in
/// DestructiveActionConsistencyTests). Every assertion locks the
/// fail-safe contract: a throttled/gated read produces `.unknown` and
/// excludes the candidate from any destructive bucket.
@available(iOS 17, *)
final class EngagementEngineTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Pure: outbound + reciprocity

    func test_outboundEngagedDIDs_parsesLikesRepostsAndReplyParents() {
        let items = [
            ContentItem(uri: "at://did:plc:alice/app.bsky.feed.post/1", cid: "c", contentType: .likes),
            ContentItem(uri: "at://did:plc:bob/app.bsky.feed.post/2", cid: "c", contentType: .reposts),
            ContentItem(
                uri: "at://did:plc:me/app.bsky.feed.post/r", cid: "c",
                contentType: .replies,
                parentReplyURI: "at://did:plc:carol/app.bsky.feed.post/3"
            ),
            ContentItem(uri: "at://did:plc:me/app.bsky.feed.post/own", cid: "c", contentType: .posts),
        ]
        let dids = EngagementEngine.outboundEngagedDIDs(from: items)
        XCTAssertEqual(dids, ["did:plc:alice", "did:plc:bob", "did:plc:carol"])
    }

    func test_didFromURI_extractsRepoDID() {
        XCTAssertEqual(
            EngagementEngine.didFromURI("at://did:plc:xyz/app.bsky.feed.post/1"),
            "did:plc:xyz"
        )
        XCTAssertNil(EngagementEngine.didFromURI("not-a-uri"))
        XCTAssertNil(EngagementEngine.didFromURI("at://"))
    }

    func test_reciprocityGaps_flagsInboundWithoutOutbound() {
        let inbound = ["did:plc:fan": 5, "did:plc:mutual": 3, "did:plc:quiet": 1]
        let outbound: Set<String> = ["did:plc:mutual"]
        let gaps = EngagementEngine.reciprocityGaps(
            inbound: inbound, outboundDIDs: outbound, minInbound: 2
        )
        // fan: 5 inbound, not reciprocated → gap. mutual: reciprocated →
        // no gap. quiet: below minInbound → no gap.
        XCTAssertEqual(gaps.map(\.did), ["did:plc:fan"])
        XCTAssertEqual(gaps.first?.inboundCount, 5)
        XCTAssertFalse(gaps.first?.userReciprocates ?? true)
    }

    func test_reciprocityGaps_sortsByInboundDescending() {
        let inbound = ["a": 2, "b": 9, "c": 5]
        let gaps = EngagementEngine.reciprocityGaps(
            inbound: inbound, outboundDIDs: [], minInbound: 2
        )
        XCTAssertEqual(gaps.map(\.did), ["b", "c", "a"])
    }

    // MARK: - Engaged audience (network)

    func test_engagedAudience_aggregatesLikersAndReposters() async {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getLikes") {
                return (200, Data("""
                {"likes":[{"actor":{"did":"did:plc:liker","handle":"liker.bsky.social","followersCount":0,"followsCount":0,"postsCount":0,"createdAt":"2020-01-01T00:00:00Z"}}]}
                """.utf8))
            }
            if url.contains("getRepostedBy") {
                return (200, Data("""
                {"repostedBy":[{"did":"did:plc:reposter","handle":"reposter.bsky.social","followersCount":0,"followsCount":0,"postsCount":0,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let engine = EngagementEngine(client: client)
        let audience = await engine.engagedAudience(
            userPostURIs: ["at://did:plc:me/app.bsky.feed.post/p1"]
        )

        XCTAssertEqual(audience.readState, .read)
        XCTAssertEqual(audience.engagedDIDs, ["did:plc:liker", "did:plc:reposter"])
    }

    func test_engagedAudience_throttle_marksReadStateUnknown() async {
        let client = makeClient()
        await client.setSession(makeSession())
        let original = RateLimit.backoffSeconds
        RateLimit.backoffSeconds = []
        defer { RateLimit.backoffSeconds = original }

        TestURLProtocol.handler = { _ in
            (429, Data(#"{"error":"RateLimitExceeded"}"#.utf8))
        }

        let engine = EngagementEngine(client: client)
        let audience = await engine.engagedAudience(
            userPostURIs: ["at://did:plc:me/app.bsky.feed.post/p1"]
        )
        XCTAssertEqual(audience.readState, .unknown)
    }

    // MARK: - Ghost detection (network)

    func test_verifyGhost_inEngagedSet_shortCircuitsToEngaged() async {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { _ in
            XCTFail("network should not be reached for an engaged-set hit")
            return (200, Data("{}".utf8))
        }
        let engine = EngagementEngine(client: client)
        let verdict = await engine.verifyGhost(
            candidateDID: "did:plc:friend",
            engagedDIDs: ["did:plc:friend"],
            userPostURIPrefix: "at://did:plc:me/",
            candidatePostsCount: 100
        )
        XCTAssertEqual(verdict.classification, .engaged)
    }

    func test_verifyGhost_noHitsCleanRead_confirmedGhost() async {
        let client = makeClient()
        await client.setSession(makeSession())
        // The candidate has likes, but none point at the user → ghost.
        TestURLProtocol.handler = { _ in
            (200, Data("""
            {"feed":[{"post":{"uri":"at://did:plc:other/app.bsky.feed.post/x","cid":"c","author":{"did":"did:plc:other","handle":"other.bsky.social"},"record":{"text":"hi","createdAt":"2024-01-01T00:00:00Z"}}}]}
            """.utf8))
        }
        let engine = EngagementEngine(client: client)
        let verdict = await engine.verifyGhost(
            candidateDID: "did:plc:ghost",
            engagedDIDs: [],
            userPostURIPrefix: "at://did:plc:me/",
            candidatePostsCount: 100
        )
        XCTAssertEqual(verdict.classification, .confirmedGhost)
    }

    func test_verifyGhost_hitOnUserPost_engaged() async {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { _ in
            (200, Data("""
            {"feed":[{"post":{"uri":"at://did:plc:me/app.bsky.feed.post/p1","cid":"c","author":{"did":"did:plc:me","handle":"me.bsky.social"},"record":{"text":"hi","createdAt":"2024-01-01T00:00:00Z"}}}]}
            """.utf8))
        }
        let engine = EngagementEngine(client: client)
        let verdict = await engine.verifyGhost(
            candidateDID: "did:plc:fan",
            engagedDIDs: [],
            userPostURIPrefix: "at://did:plc:me/",
            candidatePostsCount: 100
        )
        XCTAssertEqual(verdict.classification, .engaged)
    }

    func test_verifyGhost_throttle_isUnknown_notGhost() async {
        let client = makeClient()
        await client.setSession(makeSession())
        let original = RateLimit.backoffSeconds
        RateLimit.backoffSeconds = []
        defer { RateLimit.backoffSeconds = original }

        TestURLProtocol.handler = { _ in
            (429, Data(#"{"error":"RateLimitExceeded"}"#.utf8))
        }
        let engine = EngagementEngine(client: client)
        let verdict = await engine.verifyGhost(
            candidateDID: "did:plc:maybe",
            engagedDIDs: [],
            userPostURIPrefix: "at://did:plc:me/",
            candidatePostsCount: 100
        )
        // Fail-safe: a throttled read is never a confirmed ghost.
        XCTAssertEqual(verdict.classification, .unknown)
    }

    func test_verifyGhost_emptyReadActiveAccount_isUnknown() async {
        let client = makeClient()
        await client.setSession(makeSession())
        // 200 + empty feed, but the candidate's profile says posts exist
        // → gate/throttle signature → unknown, not a confirmed ghost.
        TestURLProtocol.handler = { _ in (200, Data(#"{"feed":[]}"#.utf8)) }
        let engine = EngagementEngine(client: client)
        let verdict = await engine.verifyGhost(
            candidateDID: "did:plc:gated",
            engagedDIDs: [],
            userPostURIPrefix: "at://did:plc:me/",
            candidatePostsCount: 500
        )
        XCTAssertEqual(verdict.classification, .unknown)
    }

    // MARK: - Helpers

    private func makeClient() -> ATProtoClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return ATProtoClient(
            session: URLSession(configuration: configuration),
            persistSessionToKeychain: false
        )
    }

    private func makeSession() -> Session {
        Session(
            did: "did:plc:me",
            handle: "me.bsky.social",
            accessJwt: "access",
            refreshJwt: "refresh"
        )
    }
}
