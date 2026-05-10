import XCTest
@testable import SkymarshalCore

final class SmokeTests: XCTestCase {

    func testCoreFrameworkLoads() {
        XCTAssertEqual(SkymarshalCoreInfo.version, "0.1.0")
    }
}
