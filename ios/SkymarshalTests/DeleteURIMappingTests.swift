import XCTest
@testable import SkymarshalCore

/// Direct coverage on `ContentService.deletionURI(for:post:)` — the
/// pure URI-mapping function introduced by the deletion fix. The bug
/// it guards: for likes and reposts, the deletable URI is the viewer's
/// own record (`post.viewer.like` / `.repost`), not the subject post URI.
/// Passing the subject URI to `com.atproto.repo.deleteRecord` succeeds
/// against the caller's repo with zero rows changed (silent no-op).
@available(iOS 17, *)
final class DeleteURIMappingTests: XCTestCase {

    func test_post_returns_subject_uri() {
        let post = makePostView(uri: "at://did:plc:alice/app.bsky.feed.post/abc")
        XCTAssertEqual(
            ContentService.deletionURI(for: .posts, post: post),
            "at://did:plc:alice/app.bsky.feed.post/abc"
        )
    }

    func test_reply_returns_subject_uri() {
        let post = makePostView(uri: "at://did:plc:alice/app.bsky.feed.post/abc")
        XCTAssertEqual(
            ContentService.deletionURI(for: .replies, post: post),
            "at://did:plc:alice/app.bsky.feed.post/abc"
        )
    }

    func test_like_returns_viewer_like_uri_not_subject() {
        let post = makePostView(
            uri: "at://did:plc:alice/app.bsky.feed.post/abc",
            viewerLike: "at://did:plc:bob/app.bsky.feed.like/xyz"
        )
        XCTAssertEqual(
            ContentService.deletionURI(for: .likes, post: post),
            "at://did:plc:bob/app.bsky.feed.like/xyz"
        )
        XCTAssertNotEqual(
            ContentService.deletionURI(for: .likes, post: post),
            post.uri
        )
    }

    func test_repost_returns_viewer_repost_uri_not_subject() {
        let post = makePostView(
            uri: "at://did:plc:alice/app.bsky.feed.post/abc",
            viewerRepost: "at://did:plc:bob/app.bsky.feed.repost/xyz"
        )
        XCTAssertEqual(
            ContentService.deletionURI(for: .reposts, post: post),
            "at://did:plc:bob/app.bsky.feed.repost/xyz"
        )
        XCTAssertNotEqual(
            ContentService.deletionURI(for: .reposts, post: post),
            post.uri
        )
    }

    /// `viewer.like` is absent for posts deleted-by-author, blocked, or
    /// labeled. The call-site at `ContentService.delete(itemIDs:)` already
    /// guards `guard let deletionURI = item.deletionURI` and surfaces the
    /// skip in the errors array — this test pins the mapping itself.
    func test_like_with_nil_viewer_returns_nil() {
        let post = makePostView(
            uri: "at://did:plc:alice/app.bsky.feed.post/abc",
            viewerLike: nil
        )
        XCTAssertNil(ContentService.deletionURI(for: .likes, post: post))
    }

    func test_repost_with_nil_viewer_returns_nil() {
        let post = makePostView(
            uri: "at://did:plc:alice/app.bsky.feed.post/abc",
            viewerRepost: nil
        )
        XCTAssertNil(ContentService.deletionURI(for: .reposts, post: post))
    }

    // MARK: - Fixtures

    private func makePostView(
        uri: String,
        viewerLike: String? = nil,
        viewerRepost: String? = nil
    ) -> PostView {
        PostView(
            uri: uri,
            cid: "bafytestcid",
            author: ProfileViewBasic(
                did: "did:plc:alice",
                handle: "alice.bsky.social",
                displayName: nil
            ),
            record: nil,
            likeCount: 0,
            repostCount: 0,
            replyCount: 0,
            indexedAt: nil,
            embed: nil,
            viewer: PostViewerState(repost: viewerRepost, like: viewerLike)
        )
    }
}
