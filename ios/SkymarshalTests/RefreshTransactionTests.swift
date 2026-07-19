import XCTest
import SwiftData
@testable import SkymarshalCore

@available(iOS 17, *)
final class RefreshTransactionTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    func test_contentRefresh_failureRestoresMemoryAndCommittedCache() async throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let client = makeClient()
        await client.setSession(makeSession())
        let service = ContentService(client: client, container: container)
        let old = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/old",
            cid: "old-cid",
            contentType: .posts
        )
        await service.setLoadedContent([old])
        await service.applyBackupImport(items: [old], mode: .replaceAll, owner: "me.bsky.social")

        TestURLProtocol.handler = { request in
            if request.url?.absoluteString.contains("getAuthorFeed") == true {
                return (200, Self.feedJSON(rkey: "new"))
            }
            return (500, Data("{\"error\":\"failed\"}".utf8))
        }

        do {
            _ = try await service.ensureContentLoaded(forceRefresh: true)
            XCTFail("expected refresh failure")
        } catch {
            let snapshot = await service.loadedSnapshot
            XCTAssertEqual(snapshot.map(\.id), [old.id])
        }

        let committed = try committedItems(container: container, owner: "me.bsky.social")
        XCTAssertEqual(committed.map(\.itemID), [old.id])
        XCTAssertFalse(try stagingItems(container: container, owner: "me.bsky.social").isEmpty)
    }

    func test_contentRefresh_successAtomicallyReplacesCommittedCache() async throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let client = makeClient()
        await client.setSession(makeSession())
        let service = ContentService(client: client, container: container)
        let old = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/old",
            cid: "old-cid",
            contentType: .posts
        )
        await service.setLoadedContent([old])
        await service.applyBackupImport(items: [old], mode: .replaceAll, owner: "me.bsky.social")

        TestURLProtocol.handler = { request in
            if request.url?.absoluteString.contains("getAuthorFeed") == true {
                return (200, Self.feedJSON(rkey: "new"))
            }
            return (200, Data("{\"feed\":[]}".utf8))
        }

        let result = try await service.ensureContentLoaded(forceRefresh: true)
        let committed = try committedItems(container: container, owner: "me.bsky.social")

        XCTAssertEqual(result.map(\.uri), ["at://did:plc:me/app.bsky.feed.post/new"])
        XCTAssertEqual(committed.map(\.uri), ["at://did:plc:me/app.bsky.feed.post/new"])
        XCTAssertTrue(try stagingItems(container: container, owner: "me.bsky.social").isEmpty)
        XCTAssertTrue(try checkpoints(container: container, owner: "me.bsky.social").isEmpty)
    }

    func test_mostRecentRefresh_fetchesOnlyNewestPagesAndMergesWithExistingContent() async throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let client = makeClient()
        await client.setSession(makeSession())
        let service = ContentService(client: client, container: container)
        let old = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/old",
            cid: "old-cid",
            contentType: .posts,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        await service.setLoadedContent([old])
        await service.applyBackupImport(items: [old], mode: .replaceAll, owner: "me.bsky.social")

        let lock = NSLock()
        var requestedURLs: [URL] = []
        TestURLProtocol.handler = { request in
            lock.lock()
            if let url = request.url {
                requestedURLs.append(url)
            }
            lock.unlock()

            if request.url?.absoluteString.contains("getAuthorFeed") == true {
                return (200, Self.feedJSON(rkey: "new-post", cursor: "next-posts"))
            }
            if request.url?.absoluteString.contains("getActorLikes") == true {
                return (200, Self.feedJSON(
                    rkey: "new-like",
                    cursor: "next-likes",
                    viewerLike: "at://did:plc:me/app.bsky.feed.like/like-record"
                ))
            }
            return (500, Data("{\"error\":\"unexpected\"}".utf8))
        }

        let result = try await service.refreshMostRecentContent()

        lock.lock()
        let urls = requestedURLs
        lock.unlock()
        XCTAssertEqual(urls.filter { $0.absoluteString.contains("getAuthorFeed") }.count, 1)
        XCTAssertEqual(urls.filter { $0.absoluteString.contains("getActorLikes") }.count, 1)
        XCTAssertFalse(urls.contains { $0.query?.contains("cursor=") == true })
        XCTAssertEqual(Set(result.map(\.uri)), Set([
            "at://did:plc:me/app.bsky.feed.post/old",
            "at://did:plc:me/app.bsky.feed.post/new-post",
            "at://did:plc:me/app.bsky.feed.post/new-like",
        ]))

        let committed = try committedItems(container: container, owner: "me.bsky.social")
        XCTAssertEqual(Set(committed.map(\.uri)), Set(result.map(\.uri)))
        XCTAssertTrue(try stagingItems(container: container, owner: "me.bsky.social").isEmpty)
        XCTAssertTrue(try checkpoints(container: container, owner: "me.bsky.social").isEmpty)
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

    private static func feedJSON(
        rkey: String,
        cursor: String? = nil,
        viewerLike: String? = nil
    ) -> Data {
        let cursorField = cursor.map { ",\"cursor\":\"\($0)\"" } ?? ""
        let viewerField = viewerLike.map { ",\"viewer\":{\"like\":\"\($0)\"}" } ?? ""
        return Data("""
        {"feed":[{"post":{"uri":"at://did:plc:me/app.bsky.feed.post/\(rkey)","cid":"cid-\(rkey)","author":{"did":"did:plc:me","handle":"me.bsky.social"},"record":{"text":"new","createdAt":"2026-01-01T00:00:00Z"}\(viewerField)}}]\(cursorField)}
        """.utf8)
    }

    private func committedItems(container: ModelContainer, owner: String) throws -> [ContentItemRecord] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContentItemRecord>(
            predicate: #Predicate { $0.ownerHandle == owner },
            sortBy: [SortDescriptor(\.uri)]
        )
        return try context.fetch(descriptor)
    }

    private func stagingItems(container: ModelContainer, owner: String) throws -> [ContentRefreshStagingRecord] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContentRefreshStagingRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        return try context.fetch(descriptor)
    }

    private func checkpoints(container: ModelContainer, owner: String) throws -> [ArchiveLoadCheckpointRecord] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        return try context.fetch(descriptor)
    }
}
