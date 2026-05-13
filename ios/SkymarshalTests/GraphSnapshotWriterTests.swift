import XCTest
import SwiftData
@testable import SkymarshalCore

final class GraphSnapshotWriterTests: XCTestCase {

    @available(iOS 17, *)
    func test_syncLocalSummaries_writesRows() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let ctx = ModelContext(container)
        let items = [
            ContentItem(uri: "u1", cid: "c", contentType: .posts, text: "x"),
            ContentItem(uri: "u2", cid: "c2", deletionURI: "at://like/x", contentType: .likes),
        ]
        try GraphSnapshotWriter.syncLocalSummaries(
            context: ctx,
            ownerHandle: "alice.bsky.social",
            items: items,
            accounts: []
        )
        let rows = try ctx.fetch(FetchDescriptor<GraphSnapshotRecord>())
        XCTAssertGreaterThanOrEqual(rows.count, 3)
        XCTAssertTrue(rows.contains { $0.kind == .interactionGraph })
    }
}
