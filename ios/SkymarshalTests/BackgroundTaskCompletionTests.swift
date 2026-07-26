import XCTest
import SkymarshalCore
@testable import Skymarshal

final class BackgroundTaskCompletionTests: XCTestCase {
    private final class SafeResults: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var values: [Bool] = []
        func append(_ value: Bool) {
            lock.lock()
            defer { lock.unlock() }
            values.append(value)
        }
    }

    func test_finish_invokesCompletionExactlyOnce() {
        let results = SafeResults()
        let completion = BackgroundTaskCompletion { success in
            results.append(success)
        }

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            completion.finish(success: index.isMultiple(of: 2))
        }

        XCTAssertEqual(results.values.count, 1)
    }

    /// Empty archive / no session must not throw or hang — just succeed empty.
    @available(iOS 17, *)
    func test_runBoundedGraphSync_emptyStoreSucceeds() async throws {
        // Smoke: constructing a container and resolving zero owners is the
        // common cold-install path for BGAppRefresh.
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        XCTAssertNotNil(container)
        // refresh with a nonexistent owner must not throw past the writer.
        try GraphSnapshotWriter.refreshPersistedSummariesFromCache(
            container: container,
            ownerHandle: "nobody.bsky.social",
            itemFetchLimit: 100
        )
    }
}
