import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class ReduceMotionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ReduceMotion.overrideKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ReduceMotion.overrideKey)
        super.tearDown()
    }

    /// Truth table for the OR semantics.
    ///
    /// | system | override | shouldReduce |
    /// |--------|----------|--------------|
    /// | off    | off      | off          |
    /// | off    | on       | on           |
    /// | on     | off      | on           |
    /// | on     | on       | on           |
    func test_shouldReduce_truthTable() {
        // both off
        UserDefaults.standard.set(false, forKey: ReduceMotion.overrideKey)
        XCTAssertFalse(ReduceMotion.shouldReduce(systemReduceMotion: false))

        // override only
        UserDefaults.standard.set(true, forKey: ReduceMotion.overrideKey)
        XCTAssertTrue(ReduceMotion.shouldReduce(systemReduceMotion: false))

        // system only
        UserDefaults.standard.set(false, forKey: ReduceMotion.overrideKey)
        XCTAssertTrue(ReduceMotion.shouldReduce(systemReduceMotion: true))

        // both on
        UserDefaults.standard.set(true, forKey: ReduceMotion.overrideKey)
        XCTAssertTrue(ReduceMotion.shouldReduce(systemReduceMotion: true))
    }

    /// Missing key reads as false (UserDefaults.bool default). System
    /// state alone still drives the result.
    func test_missingOverrideKey_defaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: ReduceMotion.overrideKey)
        XCTAssertFalse(ReduceMotion.shouldReduce(systemReduceMotion: false))
        XCTAssertTrue(ReduceMotion.shouldReduce(systemReduceMotion: true))
    }
}
