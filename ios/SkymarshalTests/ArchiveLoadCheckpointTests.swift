import XCTest
import SwiftData
@testable import SkymarshalCore

@available(iOS 17, *)
final class ArchiveLoadCheckpointTests: XCTestCase {

    func test_archiveCheckpoint_scopeKey_roundTrips() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let owner = "alice.bsky.social"
        context.insert(ArchiveLoadCheckpointRecord(
            ownerHandle: owner,
            phaseRaw: "posts",
            cursor: "next-page-cursor",
            pagesFetched: 3
        ))
        try context.save()

        let key = "\(owner)|posts"
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.scopeKey == key }
        )
        let row = try XCTUnwrap(context.fetch(descriptor).first)
        XCTAssertEqual(row.ownerHandle, owner)
        XCTAssertEqual(row.phaseRaw, "posts")
        XCTAssertEqual(row.cursor, "next-page-cursor")
        XCTAssertEqual(row.pagesFetched, 3)
    }

    func test_applyBackupImport_replaceAll_clearsCheckpointsForOwner() async throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let owner = "alice.bsky.social"
        let other = "bob.bsky.social"
        context.insert(ArchiveLoadCheckpointRecord(
            ownerHandle: owner,
            phaseRaw: "posts",
            cursor: "c1",
            pagesFetched: 1
        ))
        context.insert(ArchiveLoadCheckpointRecord(
            ownerHandle: owner,
            phaseRaw: "likes",
            cursor: "c2",
            pagesFetched: 2
        ))
        context.insert(ArchiveLoadCheckpointRecord(
            ownerHandle: other,
            phaseRaw: "posts",
            cursor: "c3",
            pagesFetched: 1
        ))
        try context.save()

        let service = ContentService(container: container)
        await service.applyBackupImport(items: [], mode: .replaceAll, owner: owner)

        let aliceDescriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.ownerHandle == owner }
        )
        XCTAssertTrue(try context.fetch(aliceDescriptor).isEmpty)

        let bobDescriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.ownerHandle == other }
        )
        XCTAssertEqual(try context.fetch(bobDescriptor).count, 1)
    }

    func test_archiveCheckpoint_upsertSameScopeKey_updatesRow() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let owner = "carol.bsky.social"
        let a = ArchiveLoadCheckpointRecord(
            ownerHandle: owner,
            phaseRaw: "likes",
            cursor: "old",
            pagesFetched: 1
        )
        context.insert(a)
        try context.save()

        a.cursor = "new"
        a.pagesFetched = 5
        a.updatedAt = Date()
        try context.save()

        let key = "\(owner)|likes"
        let descriptor = FetchDescriptor<ArchiveLoadCheckpointRecord>(
            predicate: #Predicate { $0.scopeKey == key }
        )
        let rows = try context.fetch(descriptor)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].cursor, "new")
        XCTAssertEqual(rows[0].pagesFetched, 5)
    }
}
