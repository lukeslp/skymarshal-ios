import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class InteractionFilterTests: XCTestCase {

    private let aliceDID = "did:plc:alice"
    private let bobDID = "did:plc:bob"

    private func item(
        uri: String,
        type: ContentType,
        text: String? = nil,
        parent: String? = nil
    ) -> ContentItem {
        ContentItem(
            uri: uri, cid: "cid", contentType: type,
            text: text, createdAt: Date(),
            parentReplyURI: parent
        )
    }

    // MARK: - Out-direction filtering

    func test_outgoing_likeOnTargetPost_isCaught() {
        let items = [item(uri: "at://\(aliceDID)/app.bsky.feed.post/abc", type: .likes)]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .like)
        XCTAssertEqual(result.first?.direction, .outgoing)
    }

    func test_outgoing_likeOnNonTargetPost_isIgnored() {
        let items = [item(uri: "at://\(bobDID)/app.bsky.feed.post/xyz", type: .likes)]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertTrue(result.isEmpty)
    }

    func test_outgoing_repostOfTargetPost_isCaught() {
        let items = [item(uri: "at://\(aliceDID)/app.bsky.feed.post/abc", type: .reposts)]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertEqual(result.first?.kind, .repost)
    }

    func test_outgoing_replyToTargetPost_isCaught() {
        let items = [item(
            uri: "at://did:plc:me/app.bsky.feed.post/myreply",
            type: .replies,
            text: "great point",
            parent: "at://\(aliceDID)/app.bsky.feed.post/abc"
        )]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .reply)
        // The subject (what we replied to) is the parent's URI
        XCTAssertEqual(result.first?.subjectURI, "at://\(aliceDID)/app.bsky.feed.post/abc")
        // The actor record (our reply) is preserved for "view on Bluesky"
        XCTAssertEqual(result.first?.actorRecordURI, "at://did:plc:me/app.bsky.feed.post/myreply")
    }

    func test_outgoing_replyMissingParent_isIgnored() {
        let items = [item(uri: "at://me/post/x", type: .replies, parent: nil)]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertTrue(result.isEmpty)
    }

    func test_outgoing_replyToNonTarget_isIgnored() {
        let items = [item(
            uri: "at://me/post/x", type: .replies,
            parent: "at://\(bobDID)/post/y"
        )]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertTrue(result.isEmpty)
    }

    func test_outgoing_originalPosts_areIgnored() {
        // User's own posts (.posts) shouldn't appear as interactions —
        // an "interaction" requires the OTHER account on the other side.
        let items = [item(uri: "at://me/post/x", type: .posts)]
        XCTAssertTrue(
            InteractionService.filterOutgoing(items: items, targetDID: aliceDID).isEmpty
        )
    }

    func test_outgoing_allKindsTogether_returnsCorrectCount() {
        let items = [
            item(uri: "at://\(aliceDID)/post/1", type: .likes),
            item(uri: "at://\(aliceDID)/post/2", type: .reposts),
            item(uri: "at://me/post/3", type: .replies, parent: "at://\(aliceDID)/post/4"),
            item(uri: "at://\(bobDID)/post/5", type: .likes),  // ignored
            item(uri: "at://me/post/6", type: .posts),         // ignored
        ]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertEqual(result.count, 3)
        let kinds = Set(result.map(\.kind))
        XCTAssertEqual(kinds, [.like, .repost, .reply])
    }

    func test_outgoing_carriesSubjectText() {
        let items = [item(
            uri: "at://\(aliceDID)/post/1",
            type: .likes,
            text: "their post text"
        )]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertEqual(result.first?.subjectText, "their post text")
    }

    func test_outgoing_carriesTimestamp() {
        let items = [item(uri: "at://\(aliceDID)/post/1", type: .likes)]
        let result = InteractionService.filterOutgoing(items: items, targetDID: aliceDID)
        XCTAssertNotNil(result.first?.timestamp)
    }
}
