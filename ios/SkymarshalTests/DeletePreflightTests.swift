import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class DeletePreflightTests: XCTestCase {

    func test_preflight_matches_delete_resolution_order() async throws {
        let service = try ContentService.inMemory()
        let post = ContentItem(uri: "at://u/app.bsky.feed.post/a", cid: "1", contentType: .posts, text: "hi")
        let like = ContentItem(
            uri: "at://other/app.bsky.feed.post/b",
            cid: "2",
            deletionURI: "at://me/app.bsky.feed.like/l1",
            contentType: .likes
        )
        await service.setLoadedContent([post, like])

        let ids = [post.id, like.uri, "missing"]
        let summary = await service.preflightDelete(itemIDs: ids)

        XCTAssertEqual(summary.itemsToDelete.count, 2)
        XCTAssertEqual(summary.resolutionErrors.count, 1)
        XCTAssertTrue(summary.resolutionErrors.first?.contains("missing") ?? false)
        XCTAssertEqual(summary.deletionURIs, [post.deletionURI!, like.deletionURI!])
        XCTAssertEqual(summary.countByContentType[.posts], 1)
        XCTAssertEqual(summary.countByContentType[.likes], 1)
    }

    func test_preflight_noDeletionURI_records_error() async throws {
        let service = try ContentService.inMemory()
        let badLike = ContentItem(
            uri: "at://x/app.bsky.feed.post/z",
            cid: "c",
            deletionURI: nil,
            contentType: .likes
        )
        await service.setLoadedContent([badLike])
        let summary = await service.preflightDelete(itemIDs: [badLike.id])
        XCTAssertTrue(summary.itemsToDelete.isEmpty)
        XCTAssertEqual(summary.resolutionErrors.count, 1)
    }
}
