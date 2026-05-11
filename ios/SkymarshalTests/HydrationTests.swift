import XCTest
import SwiftData
@testable import SkymarshalCore

@available(iOS 17, *)
final class HydrationTests: XCTestCase {

    /// Seed N analyzed accounts under one owner, then fetch them back
    /// the same way AppModel.hydrateFromCache does. Exercises the
    /// SwiftData read path end-to-end with the composite-key isolation.
    func test_hydrateAccounts_returnsRowsForMostRecentOwner() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let baseProfile = makeProfile(handle: "alice.bsky.social")
        let analyzed = BluescreenAnalyzer.analyze(profile: baseProfile)

        // Seed 3 accounts under alice scanned just now
        let now = Date()
        for i in 0..<3 {
            var p = baseProfile
            p = BskyProfile(
                did: "did:plc:alice-\(i)", handle: p.handle,
                displayName: p.displayName, description: p.description,
                avatar: p.avatar, banner: p.banner,
                followersCount: p.followersCount,
                followsCount: p.followsCount,
                postsCount: p.postsCount,
                createdAt: p.createdAt
            )
            let scored = BluescreenAnalyzer.analyze(profile: p)
            context.insert(AnalyzedAccountRecord(
                account: scored,
                ownerHandle: "alice.bsky.social",
                scannedAt: now
            ))
        }

        // And one stale row under bob
        context.insert(AnalyzedAccountRecord(
            account: analyzed,
            ownerHandle: "bob.bsky.social",
            scannedAt: now.addingTimeInterval(-3600)
        ))

        try context.save()

        // Mirror AppModel.hydrateFromCache: most-recent-scannedAt
        // ownerHandle wins.
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 4)

        let lastOwner = all.first?.ownerHandle
        XCTAssertEqual(lastOwner, "alice.bsky.social")

        let mine = all.filter { $0.ownerHandle == lastOwner }
        XCTAssertEqual(mine.count, 3)
    }

    /// Switching to a brand-new handle gives an empty hydration set.
    /// (Effectively: AppModel.hydrateFromCache skips when no matching
    /// records exist for the active owner.)
    func test_hydrateAccounts_unknownOwner_returnsEmpty() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.ownerHandle == "never-scanned.bsky.social" }
        )
        let result = try context.fetch(descriptor)
        XCTAssertTrue(result.isEmpty)
    }

    /// ContentItemRecord with scannedAt round-trips through the
    /// container — guards the lightweight migration that added
    /// scannedAt didn't break existing serialization.
    func test_contentItem_scannedAt_persistsAndRetrieves() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let now = Date()

        context.insert(ContentItemRecord(
            uri: "at://x/post/1",
            cid: "cid-1",
            contentType: .posts,
            text: "hello",
            createdAt: now,
            likeCount: 5,
            repostCount: 2,
            replyCount: 1,
            hasMedia: false,
            ownerHandle: "owner.bsky.social",
            scannedAt: now
        ))
        try context.save()

        let descriptor = FetchDescriptor<ContentItemRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(
            fetched.first?.scannedAt.timeIntervalSince1970 ?? 0,
            now.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_contentItem_compositeKey_isOwnerAndTypeScoped() throws {
        let post = ContentItemRecord(
            uri: "at://subject/app.bsky.feed.post/1",
            cid: "cid-1",
            contentType: .posts,
            ownerHandle: "alice.bsky.social"
        )
        let like = ContentItemRecord(
            uri: "at://subject/app.bsky.feed.post/1",
            cid: "cid-1",
            deletionURI: "at://alice/app.bsky.feed.like/abc",
            contentType: .likes,
            ownerHandle: "alice.bsky.social"
        )
        let otherOwner = ContentItemRecord(
            uri: "at://subject/app.bsky.feed.post/1",
            cid: "cid-1",
            contentType: .posts,
            ownerHandle: "bob.bsky.social"
        )

        XCTAssertNotEqual(post.compositeKey, like.compositeKey)
        XCTAssertNotEqual(post.compositeKey, otherOwner.compositeKey)
        XCTAssertEqual(like.itemID, "likes|at://subject/app.bsky.feed.post/1")
        XCTAssertEqual(like.deletionURI, "at://alice/app.bsky.feed.like/abc")
    }

    // MARK: - Helpers

    private func makeProfile(
        handle: String,
        followers: Int = 1500,
        following: Int = 300,
        posts: Int = 800
    ) -> BskyProfile {
        let createdAt = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(-365 * 86_400)
        )
        return BskyProfile(
            did: "did:plc:\(handle)",
            handle: handle,
            displayName: "Test User",
            description: "bio",
            avatar: "https://x/avatar",
            banner: "https://x/banner",
            followersCount: followers,
            followsCount: following,
            postsCount: posts,
            createdAt: createdAt
        )
    }
}
