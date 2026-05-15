import XCTest
import SwiftData
@testable import SkymarshalCore

/// Mirrors the SwiftData read path in `AppModel.hydrateFromCache()` for
/// content rows: unbounded fetch sorted by `scannedAt`, then in-memory
/// `filter` by `ownerHandle`. Used as a **local** wall-clock sanity check
/// for cold-launch perf docs — not a substitute for Instruments on device.
@available(iOS 17, *)
final class ColdLaunchHydrationPatternTests: XCTestCase {

    func test_measure_hydrationFetchPattern_wallClock() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let owner = "perf.owner.bsky.social"
        let now = Date()
        let n = 400
        for i in 0..<n {
            context.insert(
                ContentItemRecord(
                    uri: "at://\(owner)/app.bsky.feed.post/p\(i)",
                    cid: "cid-\(i)",
                    contentType: .posts,
                    text: "post \(i)",
                    createdAt: now,
                    likeCount: 0,
                    repostCount: 0,
                    replyCount: 0,
                    hasMedia: false,
                    ownerHandle: owner,
                    scannedAt: now.addingTimeInterval(Double(-i))
                )
            )
        }
        try context.save()

        measure {
            let descriptor = FetchDescriptor<ContentItemRecord>(
                sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
            )
            guard let allItems = try? context.fetch(descriptor),
                  let lastOwner = allItems.first?.ownerHandle else {
                XCTFail("fetch failed")
                return
            }
            _ = allItems.filter { $0.ownerHandle == lastOwner }
        }
    }
}
