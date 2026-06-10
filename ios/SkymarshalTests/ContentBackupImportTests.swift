import XCTest
@testable import SkymarshalCore

final class ContentBackupImportTests: XCTestCase {

    func test_decode_rejectsLikeWithoutDeletionURI() throws {
        let json = """
        {"handle":"alice.bsky.social","did":"did:plc:abc","items":[
          {"uri":"at://did:plc:other/app.bsky.feed.post/subject","cid":"c1","contentType":"likes","text":null,"createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null}
        ]}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try ContentBackupImport.decodeContentItems(
            from: json,
            expectedHandle: "alice.bsky.social",
            expectedDid: "did:plc:abc"
        )) { error in
            guard case ContentBackupImport.ImportError.unsafeDeletionURI = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func test_decode_handleMismatch_throws() {
        let json = """
        {"handle":"other.bsky.social","did":"did:plc:abc","items":[
          {"uri":"at://did:plc:abc/app.bsky.feed.post/x","cid":"c","contentType":"posts","text":null,"createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null}
        ]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try ContentBackupImport.decodeContentItems(
            from: json,
            expectedHandle: "alice.bsky.social",
            expectedDid: "did:plc:abc"
        )) { error in
            guard case ContentBackupImport.ImportError.handleMismatch = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func test_decode_missingEnvelopeDid_throws() {
        let json = """
        {"handle":"alice.bsky.social","items":[]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try ContentBackupImport.decodeContentItems(
            from: json,
            expectedHandle: "alice.bsky.social",
            expectedDid: "did:plc:abc"
        )) { error in
            XCTAssertEqual(
                error as? ContentBackupImport.ImportError,
                .missingEnvelopeIdentity(field: "DID")
            )
        }
    }

    func test_decode_rejectsDeletionURIFromAnotherRepository() {
        let json = """
        {"handle":"alice.bsky.social","did":"did:plc:abc","items":[
          {"uri":"at://did:plc:subject/app.bsky.feed.post/x","cid":"c","contentType":"likes","text":null,"createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null,"deletionURI":"at://did:plc:other/app.bsky.feed.like/l1"}
        ]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try ContentBackupImport.decodeContentItems(
            from: json,
            expectedHandle: "alice.bsky.social",
            expectedDid: "did:plc:abc"
        )) { error in
            guard case ContentBackupImport.ImportError.unsafeDeletionURI = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func test_decode_acceptsValidDeletionTargets() throws {
        let json = """
        {"handle":"alice.bsky.social","did":"did:plc:abc","items":[
          {"uri":"at://did:plc:abc/app.bsky.feed.post/p1","cid":"c1","contentType":"posts","text":"post","createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null},
          {"uri":"at://did:plc:subject/app.bsky.feed.post/p2","cid":"c2","contentType":"reposts","text":null,"createdAt":null,"likeCount":0,"repostCount":0,"replyCount":0,"hasMedia":false,"altText":null,"deletionURI":"at://did:plc:abc/app.bsky.feed.repost/r1"}
        ]}
        """.data(using: .utf8)!
        let result = try ContentBackupImport.decodeContentItems(
            from: json,
            expectedHandle: "alice.bsky.social",
            expectedDid: "did:plc:abc"
        )
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.skippedLikeRepostWithoutDeletionURI, 0)
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
