import XCTest
import SwiftData
@testable import SkymarshalCore

/// Coverage for the throttle-safe last-post read in `FollowerService`.
///
/// These tests drive a real `ATProtoClient` through the shared
/// `TestURLProtocol` stub (defined in DestructiveActionConsistencyTests)
/// so the full request/response/backoff path runs. They lock the
/// tri-state read verdict that keeps a throttled or gated read from
/// masquerading as account inactivity — the bulk-unfollow-of-active-
/// accounts bug this branch exists to prevent.
@available(iOS 17, *)
final class FollowerServiceActivityTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Scan phase-3 read-state

    /// A 200 + empty author feed for an account whose profile reports
    /// `postsCount > 0` is the throttle/gate signature: the scan must
    /// stamp `.unknown` and must NOT flag the account inactive.
    func test_scan_emptyFeedForActiveAccount_marksReadStateUnknown_andNotInactive() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getFollows") {
                return (200, Data("""
                {"follows":[{"did":"did:plc:active","handle":"active.bsky.social"}]}
                """.utf8))
            }
            if url.contains("getProfiles") {
                // Active account: 200 posts, but the feed read will be empty.
                return (200, Data("""
                {"profiles":[{"did":"did:plc:active","handle":"active.bsky.social","postsCount":200,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            if url.contains("getAuthorFeed") {
                return (200, Data(#"{"feed":[]}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let service = FollowerService(client: client)
        let result = try await service.scan(checkLastPost: true)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].activityReadState, .unknown)
        XCTAssertFalse(result[0].isInactive,
                       "An active account with an empty (throttled) feed must not be flagged inactive")
    }

    /// A genuine last post inside the window yields `.read` and a
    /// non-inactive verdict.
    func test_scan_realLastPost_marksReadStateRead() async throws {
        let recent = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86_400))
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getFollows") {
                return (200, Data("""
                {"follows":[{"did":"did:plc:live","handle":"live.bsky.social"}]}
                """.utf8))
            }
            if url.contains("getProfiles") {
                return (200, Data("""
                {"profiles":[{"did":"did:plc:live","handle":"live.bsky.social","postsCount":50,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            if url.contains("getAuthorFeed") {
                return (200, Data("""
                {"feed":[{"post":{"uri":"at://did:plc:live/app.bsky.feed.post/p1","cid":"c1","author":{"did":"did:plc:live","handle":"live.bsky.social"},"record":{"text":"hi","createdAt":"\(recent)"}}}]}
                """.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let service = FollowerService(client: client)
        let result = try await service.scan(checkLastPost: true)

        XCTAssertEqual(result[0].activityReadState, .read)
        XCTAssertFalse(result[0].isInactive)
    }

    /// A throttled feed read (429 on every attempt) ends in `.unknown`
    /// after the backoff ladder is exhausted, not a false-inactive
    /// verdict. The backoff schedule is overridden to a single fast
    /// attempt so the test doesn't sleep through the 240s ladder.
    func test_scan_throttledFeed_marksReadStateUnknown() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        let original = RateLimit.backoffSeconds
        RateLimit.backoffSeconds = []
        defer { RateLimit.backoffSeconds = original }

        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getFollows") {
                return (200, Data("""
                {"follows":[{"did":"did:plc:busy","handle":"busy.bsky.social"}]}
                """.utf8))
            }
            if url.contains("getProfiles") {
                return (200, Data("""
                {"profiles":[{"did":"did:plc:busy","handle":"busy.bsky.social","postsCount":300,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            if url.contains("getAuthorFeed") {
                return (429, Data(#"{"error":"RateLimitExceeded"}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let service = FollowerService(client: client)
        let result = try await service.scan(checkLastPost: true)

        XCTAssertEqual(result[0].activityReadState, .unknown)
        XCTAssertFalse(result[0].isInactive)
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
