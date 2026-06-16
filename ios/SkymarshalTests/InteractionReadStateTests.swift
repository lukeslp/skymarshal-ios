import XCTest
@testable import SkymarshalCore

/// Coverage for the incoming-sweep read-state in `InteractionService`.
///
/// The incoming direction walks the target's archive over the AppView.
/// A throttle or an `!no-unauthenticated` gate returns an empty result
/// that must NOT be read as "they never engaged you". These tests drive
/// a real `ATProtoClient` through the shared `TestURLProtocol` stub
/// (defined in DestructiveActionConsistencyTests) and lock the
/// `InteractionBundle.incomingReadState` verdict for the 429, gated-empty,
/// and clean-read cases.
@available(iOS 17, *)
final class InteractionReadStateTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    /// Both incoming sweeps return empty while the target reports
    /// `postsCount > 0` → `.unknown` (gated/throttled active account).
    func test_loadInteractions_emptySweepForActiveAccount_marksIncomingUnknown() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getProfile") {
                return (200, Data("""
                {"did":"did:plc:target","handle":"target.bsky.social","postsCount":500,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}
                """.utf8))
            }
            // getAuthorFeed + getActorLikes both empty
            return (200, Data(#"{"feed":[]}"#.utf8))
        }

        let bundle = try await makeService(client).loadInteractions(
            userDID: "did:plc:me",
            userItems: [],
            targetDID: "did:plc:target",
            targetHandle: "target.bsky.social"
        )

        XCTAssertEqual(bundle.incomingReadState, .unknown)
        XCTAssertTrue(bundle.incoming.isEmpty)
    }

    /// A 429 on the incoming feed sweep (after the backoff ladder is
    /// exhausted) taints the read-state to `.unknown` regardless of what
    /// the profile reports.
    func test_loadInteractions_throttledSweep_marksIncomingUnknown() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        let original = RateLimit.backoffSeconds
        RateLimit.backoffSeconds = []
        defer { RateLimit.backoffSeconds = original }

        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getProfile") {
                return (200, Data("""
                {"did":"did:plc:target","handle":"target.bsky.social","postsCount":0,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}
                """.utf8))
            }
            if url.contains("getAuthorFeed") || url.contains("getActorLikes") {
                return (429, Data(#"{"error":"RateLimitExceeded"}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let bundle = try await makeService(client).loadInteractions(
            userDID: "did:plc:me",
            userItems: [],
            targetDID: "did:plc:target",
            targetHandle: "target.bsky.social"
        )

        XCTAssertEqual(bundle.incomingReadState, .unknown)
    }

    /// A clean read that finds a real incoming interaction → `.read`.
    func test_loadInteractions_realIncoming_marksIncomingRead() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getProfile") {
                return (200, Data("""
                {"did":"did:plc:target","handle":"target.bsky.social","postsCount":50,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}
                """.utf8))
            }
            if url.contains("getAuthorFeed") {
                // A reply by the target pointing at the user's post.
                return (200, Data("""
                {"feed":[{"post":{"uri":"at://did:plc:target/app.bsky.feed.post/r1","cid":"c1","author":{"did":"did:plc:target","handle":"target.bsky.social"},"record":{"text":"reply","createdAt":"2024-01-01T00:00:00Z","reply":{"parent":{"uri":"at://did:plc:me/app.bsky.feed.post/p1","cid":"c2"}}}}}]}
                """.utf8))
            }
            if url.contains("getActorLikes") {
                return (200, Data(#"{"feed":[]}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let bundle = try await makeService(client).loadInteractions(
            userDID: "did:plc:me",
            userItems: [],
            targetDID: "did:plc:target",
            targetHandle: "target.bsky.social"
        )

        XCTAssertEqual(bundle.incomingReadState, .read)
        XCTAssertEqual(bundle.incoming.count, 1)
        XCTAssertEqual(bundle.incoming.first?.kind, .reply)
    }

    /// Recovery: a 429 on the first feed page that succeeds on retry
    /// reads cleanly (`.read`) — the backoff loop absorbs the transient
    /// throttle rather than tainting the verdict.
    func test_loadInteractions_throttleThenRecover_marksIncomingRead() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        let original = RateLimit.backoffSeconds
        RateLimit.backoffSeconds = [0]   // one fast retry
        defer { RateLimit.backoffSeconds = original }

        let feedAttempts = Attempts()
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getProfile") {
                return (200, Data("""
                {"did":"did:plc:target","handle":"target.bsky.social","postsCount":50,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}
                """.utf8))
            }
            if url.contains("getAuthorFeed") {
                if feedAttempts.next() == 0 {
                    return (429, Data(#"{"error":"RateLimitExceeded"}"#.utf8))
                }
                return (200, Data("""
                {"feed":[{"post":{"uri":"at://did:plc:target/app.bsky.feed.post/r1","cid":"c1","author":{"did":"did:plc:target","handle":"target.bsky.social"},"record":{"text":"reply","createdAt":"2024-01-01T00:00:00Z","reply":{"parent":{"uri":"at://did:plc:me/app.bsky.feed.post/p1","cid":"c2"}}}}}]}
                """.utf8))
            }
            if url.contains("getActorLikes") {
                return (200, Data(#"{"feed":[]}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let bundle = try await makeService(client).loadInteractions(
            userDID: "did:plc:me",
            userItems: [],
            targetDID: "did:plc:target",
            targetHandle: "target.bsky.social"
        )

        XCTAssertEqual(bundle.incomingReadState, .read)
        XCTAssertEqual(bundle.incoming.count, 1)
    }

    // MARK: - Helpers

    /// Thread-safe attempt counter for the recovery case.
    private final class Attempts: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func next() -> Int {
            lock.lock(); defer { lock.unlock() }
            defer { count += 1 }
            return count
        }
    }

    private func makeClient() -> ATProtoClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return ATProtoClient(
            session: URLSession(configuration: configuration),
            persistSessionToKeychain: false
        )
    }

    private func makeService(_ client: ATProtoClient) -> InteractionService {
        InteractionService(client: client)
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
