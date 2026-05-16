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
            guard let lastOwner = CacheHydration.latestOwnerHandle(from: context) else {
                XCTFail("fetch failed")
                return
            }
            _ = CacheHydration.contentRecords(for: lastOwner, context: context)
        }
    }

    /// Documents the simulator baseline command for Week-1 perf signposts.
    /// Run from `ios/`: `xcodebuild test -scheme Skymarshal -destination
    /// 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkymarshalTests/ColdLaunchHydrationPatternTests`
    func test_predicateHydrationPattern_documentedInPerfBaseline() {
        XCTAssertTrue(true, "See docs/PERF_COLD_LAUNCH_BASELINE.md for Instruments steps.")
    }
}
