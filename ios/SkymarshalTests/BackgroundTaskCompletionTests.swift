import XCTest
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
}
