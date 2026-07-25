import XCTest
@testable import SkymarshalCore

/// Coverage for duplicate-DID tolerance in `FollowerService.scan`.
///
/// `getFollows` pages purely by server cursor. A user who follows or
/// unfollows someone mid-scan shifts the cursor window, so the same
/// account can arrive on two consecutive pages. Nothing upstream
/// guarantees the follow list is a set.
///
/// A duplicate is not a cosmetic problem. It reaches two places that
/// both treat DIDs as unique keys:
///
///   1. `Dictionary(uniqueKeysWithValues:)` over the `getProfiles`
///      response — a hard trap on a repeated key.
///   2. `AnalyzedAccount.id` (the DID) backing the SwiftUI list, where
///      colliding identity crashes diffing when a sheet presentation
///      forces reconciliation.
///
/// The scan must therefore collapse duplicates before hydration.
@available(iOS 17, *)
final class FollowerScanDeduplicationTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    /// The same DID on two pages must yield exactly one analyzed
    /// account. Before deduplication this trapped in `getProfiles`
    /// hydration rather than failing an assertion.
    func test_scan_duplicateDidAcrossPages_yieldsSingleAccount() async throws {
        let client = makeClient()
        await client.setSession(makeSession())

        // Page 1 hands back a cursor; page 2 repeats did:plc:dupe.
        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getFollows") {
                if url.contains("cursor=page2") {
                    return (200, Data("""
                    {"follows":[{"did":"did:plc:dupe","handle":"dupe.bsky.social"},{"did":"did:plc:other","handle":"other.bsky.social"}]}
                    """.utf8))
                }
                return (200, Data("""
                {"follows":[{"did":"did:plc:dupe","handle":"dupe.bsky.social"}],"cursor":"page2"}
                """.utf8))
            }
            if url.contains("getProfiles") {
                return (200, Data("""
                {"profiles":[{"did":"did:plc:dupe","handle":"dupe.bsky.social","postsCount":10,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"},{"did":"did:plc:other","handle":"other.bsky.social","postsCount":5,"followersCount":3,"followsCount":3,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let service = FollowerService(client: client)
        let result = try await service.scan(checkLastPost: false)

        let dids = result.map(\.profile.did)
        XCTAssertEqual(Set(dids).count, dids.count,
                       "Scan results must not contain duplicate DIDs")
        XCTAssertEqual(dids.sorted(), ["did:plc:dupe", "did:plc:other"])
    }

    /// A duplicate landing inside a single hydration batch is the
    /// sharpest case: both copies go into one `getProfiles` call, so a
    /// repeated key reaches the dictionary build directly.
    func test_scan_duplicateDidWithinOneBatch_doesNotTrap() async throws {
        let client = makeClient()
        await client.setSession(makeSession())

        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getFollows") {
                return (200, Data("""
                {"follows":[{"did":"did:plc:twice","handle":"twice.bsky.social"},{"did":"did:plc:twice","handle":"twice.bsky.social"}]}
                """.utf8))
            }
            if url.contains("getProfiles") {
                return (200, Data("""
                {"profiles":[{"did":"did:plc:twice","handle":"twice.bsky.social","postsCount":10,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"},{"did":"did:plc:twice","handle":"twice.bsky.social","postsCount":10,"followersCount":10,"followsCount":10,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let service = FollowerService(client: client)
        let result = try await service.scan(checkLastPost: false)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.profile.did, "did:plc:twice")
    }

    /// Deduplication keeps the first occurrence and preserves the
    /// order the server returned — the scan surfaces accounts in
    /// follow order, and reshuffling them would churn the live list.
    func test_scan_deduplication_preservesFirstOccurrenceOrder() async throws {
        let client = makeClient()
        await client.setSession(makeSession())

        TestURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("getFollows") {
                return (200, Data("""
                {"follows":[{"did":"did:plc:a","handle":"a.bsky.social"},{"did":"did:plc:b","handle":"b.bsky.social"},{"did":"did:plc:a","handle":"a.bsky.social"},{"did":"did:plc:c","handle":"c.bsky.social"}]}
                """.utf8))
            }
            if url.contains("getProfiles") {
                return (200, Data("""
                {"profiles":[{"did":"did:plc:a","handle":"a.bsky.social","postsCount":1,"followersCount":1,"followsCount":1,"createdAt":"2020-01-01T00:00:00Z"},{"did":"did:plc:b","handle":"b.bsky.social","postsCount":2,"followersCount":2,"followsCount":2,"createdAt":"2020-01-01T00:00:00Z"},{"did":"did:plc:c","handle":"c.bsky.social","postsCount":3,"followersCount":3,"followsCount":3,"createdAt":"2020-01-01T00:00:00Z"}]}
                """.utf8))
            }
            return (200, Data("{}".utf8))
        }

        let service = FollowerService(client: client)
        let result = try await service.scan(checkLastPost: false)

        XCTAssertEqual(result.map(\.profile.did), ["did:plc:a", "did:plc:b", "did:plc:c"])
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
