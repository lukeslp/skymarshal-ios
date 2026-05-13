import XCTest
@testable import SkymarshalCore

final class ContentBackupImportTests: XCTestCase {

    func test_decode_skipsLikeWithoutDeletionURI() throws {
        let json = """
        {"handle":"alice.bsky.social","did":"did:plc:abc","exportedAt":"2020-01-01T00:00:00Z","itemCount":2,"items":[
          {"uri":"at://like/1","cid":"c1","contentType":"likes","text":null,"createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null},
          {"uri":"at://did:plc:abc/app.bsky.feed.post/r","cid":"c2","contentType":"posts","text":"hi","createdAt":null,"likeCount":1,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null,"deletionURI":null}
        ]}
        """.data(using: .utf8)!
        let out = try ContentBackupImport.decodeContentItems(
            from: json,
            expectedHandle: "alice.bsky.social",
            expectedDid: "did:plc:abc"
        )
        XCTAssertEqual(out.skippedLikeRepostWithoutDeletionURI, 1)
        XCTAssertEqual(out.items.count, 1)
        XCTAssertEqual(out.items.first?.contentType, .posts)
    }

    func test_decode_handleMismatch_throws() {
        let json = """
        {"handle":"other.bsky.social","items":[
          {"uri":"at://x","cid":"c","contentType":"posts","text":null,"createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null}
        ]}
        """.data(using: .utf8)!
        do {
            _ = try ContentBackupImport.decodeContentItems(
                from: json,
                expectedHandle: "alice.bsky.social",
                expectedDid: nil
            )
            XCTFail("expected error")
        } catch let e as ContentBackupImport.ImportError {
            if case .handleMismatch = e { return }
            XCTFail("wrong case \(e)")
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func test_restorePreview_countsSkips() {
        let cur = [ContentItem(uri: "a", cid: "1", contentType: .posts)]
        let imp = [
            ContentItem(uri: "a", cid: "1", contentType: .posts),
            ContentItem(uri: "b", cid: "2", contentType: .posts),
        ]
        let p = ContentBackupImport.restorePreview(
            currentItems: cur,
            importedItems: imp,
            skippedUnsafeLikeRepost: 3
        )
        XCTAssertEqual(p.skippedUnsafeLikeRepost, 3)
        XCTAssertEqual(p.onlyInImport, 1)
    }
}
