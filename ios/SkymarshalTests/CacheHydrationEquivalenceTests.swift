import XCTest
import SwiftData
@testable import SkymarshalCore

/// Proves predicate-scoped cache hydration returns the same row sets as the
/// legacy unbounded fetch + `filter { ownerHandle }` path in
/// `AppModel.hydrateFromCache()` (pre-`CacheHydration`).
@available(iOS 17, *)
final class CacheHydrationEquivalenceTests: XCTestCase {

    func test_predicateContentFetch_matchesLegacyFilter() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let ownerA = "alice.bsky.social"
        let ownerB = "bob.bsky.social"
        let now = Date()
        for i in 0..<30 {
            context.insert(
                ContentItemRecord(
                    uri: "at://\(ownerA)/app.bsky.feed.post/a\(i)",
                    cid: "a-\(i)",
                    contentType: .posts,
                    ownerHandle: ownerA,
                    scannedAt: now.addingTimeInterval(Double(-i))
                )
            )
        }
        for i in 0..<10 {
            context.insert(
                ContentItemRecord(
                    uri: "at://\(ownerB)/app.bsky.feed.post/b\(i)",
                    cid: "b-\(i)",
                    contentType: .posts,
                    ownerHandle: ownerB,
                    scannedAt: now.addingTimeInterval(Double(-100 - i))
                )
            )
        }
        try context.save()

        guard let latest = CacheHydration.latestOwnerHandle(from: context) else {
            XCTFail("expected latest owner")
            return
        }
        XCTAssertEqual(latest, ownerA)

        let predicateRows = CacheHydration.contentRecords(for: latest, context: context)
        let legacyRows = CacheHydration.contentRecordsLegacyUnbounded(
            for: latest,
            context: context
        )
        XCTAssertEqual(
            Set(predicateRows.map(\.compositeKey)),
            Set(legacyRows.map(\.compositeKey))
        )
    }

    func test_predicateAccountFetch_matchesLegacyFilter() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let owner = "scanner.bsky.social"
        let now = Date()
        for i in 0..<5 {
            let profile = BskyProfile(
                did: "did:plc:follow\(i)",
                handle: "user\(i).bsky.social",
                displayName: nil,
                description: nil,
                avatar: nil,
                banner: nil,
                followersCount: 10,
                followsCount: 10,
                postsCount: 1,
                createdAt: ISO8601DateFormatter().string(from: now),
                labels: nil,
                viewer: nil
            )
            let account = AnalyzedAccount(
                profile: profile,
                ratio: 1,
                botScore: 0.1,
                botFlags: [],
                influenceScore: 0,
                influenceTier: .nano,
                accountAgeDays: 100,
                postsPerDay: 1,
                profileCompleteness: 0.5,
                lastPostDate: nil,
                daysSinceLastPost: nil,
                isInactive: false,
                isDeleted: false,
                isMutual: false,
                engagementScore: 0,
                interactedRecently: nil
            )
            context.insert(AnalyzedAccountRecord(account: account, ownerHandle: owner, scannedAt: now))
        }
        try context.save()

        let predicateRows = CacheHydration.analyzedAccountRecords(for: owner, context: context)
        let legacyRows = CacheHydration.analyzedAccountRecordsLegacyUnbounded(
            for: owner,
            context: context
        )
        XCTAssertEqual(
            Set(predicateRows.map(\.compositeKey)),
            Set(legacyRows.map(\.compositeKey))
        )
    }
}
