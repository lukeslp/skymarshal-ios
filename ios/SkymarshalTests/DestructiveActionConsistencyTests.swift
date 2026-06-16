import XCTest
import SwiftData
@testable import SkymarshalCore

final class TestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// Inside a `URLProtocol`, the loader has already converted `httpBody`
    /// to `httpBodyStream` — reading `httpBody` returns nil and any
    /// body-based stubbing silently matches nothing.
    var bodyString: String {
        if let body = httpBody {
            return String(data: body, encoding: .utf8) ?? ""
        }
        guard let stream = httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

@available(iOS 17, *)
final class DestructiveActionConsistencyTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    func test_deleteRecord_rejectsMismatchedRepositoryBeforeNetwork() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { _ in
            XCTFail("network should not be reached")
            return (200, Data("{}".utf8))
        }

        do {
            try await client.deleteRecord(
                uri: "at://did:plc:other/app.bsky.feed.post/p1",
                expectedCollection: .post
            )
            XCTFail("expected validation failure")
        } catch let error as ATProtoError {
            XCTAssertEqual(error.status, 400)
        }
    }

    func test_deleteRecord_rejectsWrongCollectionBeforeNetwork() async throws {
        let client = makeClient()
        await client.setSession(makeSession())

        do {
            try await client.deleteRecord(
                uri: "at://did:plc:me/app.bsky.feed.like/l1",
                expectedCollection: .post
            )
            XCTFail("expected validation failure")
        } catch let error as ATProtoError {
            XCTAssertEqual(error.status, 400)
        }
    }

    func test_contentDelete_mixedBatchKeepsFailedItem() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            return request.bodyString.contains("bad")
                ? (500, Data("{\"error\":\"failed\"}".utf8))
                : (200, Data("{}".utf8))
        }
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let service = ContentService(client: client, container: container)
        let good = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/good",
            cid: "1",
            contentType: .posts
        )
        let bad = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/bad",
            cid: "2",
            contentType: .posts
        )
        await service.setLoadedContent([good, bad])

        let result = await service.delete(itemIDs: [good.id, bad.id])
        let remaining = await service.loadedSnapshot

        XCTAssertEqual(result.deleted, 1)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(remaining.map(\.id), [bad.id])
    }

    func test_unfollow_mixedBatchKeepsFailedAccount() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            return request.bodyString.contains("bad")
                ? (500, Data("{\"error\":\"failed\"}".utf8))
                : (200, Data("{}".utf8))
        }
        let service = FollowerService(client: client)
        let good = makeAccount(did: "did:plc:good", rkey: "good")
        let bad = makeAccount(did: "did:plc:bad", rkey: "bad")
        await service.setLoaded([good, bad])

        let result = await service.unfollow(dids: [good.did, bad.did])
        let remaining = await service.loadedSnapshot

        XCTAssertEqual(result.done, 1)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(remaining.map(\.did), [bad.did])
    }

    /// Defense-in-depth: when a preset passes `requireKnownActivity:
    /// true`, an account whose activity read was unreliable (`.unknown`)
    /// is skipped and reported, never unfollowed — even though its
    /// follow record is valid and the network would accept the delete.
    func test_unfollow_requireKnownActivity_skipsUnknownReadState() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
        let service = FollowerService(client: client)
        let known = makeAccount(did: "did:plc:known", rkey: "known", activityReadState: .read)
        let unknown = makeAccount(did: "did:plc:unknown", rkey: "unknown", activityReadState: .unknown)
        await service.setLoaded([known, unknown])

        let result = await service.unfollow(
            dids: [known.did, unknown.did],
            requireKnownActivity: true
        )
        let remaining = await service.loadedSnapshot

        XCTAssertEqual(result.done, 1)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].contains("could not be read reliably"))
        // The unknown account survives the bulk action.
        XCTAssertEqual(remaining.map(\.did), [unknown.did])
    }

    /// Without the flag, the same `.unknown` account is unfollowed
    /// normally — the guard is opt-in per call site.
    func test_unfollow_withoutRequireKnownActivity_unfollowsUnknownReadState() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
        let service = FollowerService(client: client)
        let unknown = makeAccount(did: "did:plc:unknown", rkey: "unknown", activityReadState: .unknown)
        await service.setLoaded([unknown])

        let result = await service.unfollow(dids: [unknown.did])
        XCTAssertEqual(result.done, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func test_followerScan_failureRestoresPreviousMemorySnapshot() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        let service = FollowerService(client: client)
        let old = makeAccount(did: "did:plc:old", rkey: "old")
        await service.setLoaded([old])
        TestURLProtocol.handler = { request in
            if request.url?.absoluteString.contains("getFollows") == true {
                return (200, Data("""
                {"follows":[{"did":"did:plc:new","handle":"new.bsky.social"}]}
                """.utf8))
            }
            return (500, Data("{\"error\":\"failed\"}".utf8))
        }

        do {
            _ = try await service.scan(checkLastPost: false)
            XCTFail("expected scan failure")
        } catch {
            let snapshot = await service.loadedSnapshot
            XCTAssertEqual(snapshot.map(\.did), [old.did])
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

    private func makeSession() -> Session {
        Session(
            did: "did:plc:me",
            handle: "me.bsky.social",
            accessJwt: "access",
            refreshJwt: "refresh"
        )
    }

    private func makeAccount(
        did: String,
        rkey: String,
        activityReadState: ActivityReadState = .read
    ) -> AnalyzedAccount {
        let profile = BskyProfile(
            did: did,
            handle: "\(rkey).bsky.social",
            createdAt: "2020-01-01T00:00:00Z",
            viewer: .init(following: "at://did:plc:me/app.bsky.graph.follow/\(rkey)")
        )
        return BluescreenAnalyzer.analyze(profile: profile)
            .withActivityReadState(activityReadState)
    }
}
