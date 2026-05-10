import XCTest
@testable import SkymarshalCore

final class RateLimitTests: XCTestCase {

    // MARK: - The schedule itself

    func test_backoffSchedule_isExactlyTheKnownGoodSequence() {
        // The Python source — lifted verbatim from deletion.py:35.
        XCTAssertEqual(RateLimit.backoffSeconds, [1, 2, 4, 8, 15, 30, 60, 120])
    }

    func test_backoffSchedule_totalIs240Seconds() {
        XCTAssertEqual(RateLimit.backoffSeconds.reduce(0, +), 240)
    }

    // MARK: - 429 detection across signals

    func test_isRateLimit_matchesRateLimitExceededInMessage() {
        struct MyError: LocalizedError {
            var errorDescription: String? { "RateLimitExceeded: please wait" }
        }
        XCTAssertTrue(RateLimit.isRateLimit(MyError()))
    }

    func test_isRateLimit_matchesRateLimitInMessage_caseInsensitive() {
        struct MyError: LocalizedError {
            var errorDescription: String? { "Hit RATE LIMIT for repo writes" }
        }
        XCTAssertTrue(RateLimit.isRateLimit(MyError()))
    }

    func test_isRateLimit_matchesTooManyRequestsInMessage() {
        struct MyError: LocalizedError {
            var errorDescription: String? { "HTTP 429: too many requests" }
        }
        XCTAssertTrue(RateLimit.isRateLimit(MyError()))
    }

    func test_isRateLimit_matchesATProtoErrorStatus429() {
        let error = ATProtoError(status: 429, message: "rate limited")
        XCTAssertTrue(RateLimit.isRateLimit(error))
    }

    func test_isRateLimit_matchesNSErrorWithHTTPStatusCode429() {
        let nsError = NSError(
            domain: "test",
            code: 0,
            userInfo: ["HTTPStatusCode": 429]
        )
        XCTAssertTrue(RateLimit.isRateLimit(nsError))
    }

    // MARK: - Negative cases

    func test_isRateLimit_doesNotMatchUnrelatedErrors() {
        struct OtherError: Error {}
        XCTAssertFalse(RateLimit.isRateLimit(OtherError()))
    }

    func test_isRateLimit_doesNotMatchATProtoError400() {
        let error = ATProtoError(status: 400, message: "bad request")
        XCTAssertFalse(RateLimit.isRateLimit(error))
    }

    func test_isRateLimit_doesNotMatchNSError404() {
        let nsError = NSError(
            domain: "test",
            code: 0,
            userInfo: ["HTTPStatusCode": 404]
        )
        XCTAssertFalse(RateLimit.isRateLimit(nsError))
    }

    // MARK: - withBackoff behavior

    func test_withBackoff_returnsImmediatelyOnSuccess() async throws {
        let result = try await RateLimit.withBackoff { 42 }
        XCTAssertEqual(result, 42)
    }

    func test_withBackoff_reThrowsNonRateLimitErrorImmediately() async {
        struct OtherError: Error, Equatable {}
        var attempts = 0
        do {
            _ = try await RateLimit.withBackoff { () -> Int in
                attempts += 1
                throw OtherError()
            }
            XCTFail("Expected throw")
        } catch is OtherError {
            XCTAssertEqual(attempts, 1, "Non-429 must not retry")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_withBackoff_recoversWhenRateLimitClearsBeforeBudgetExhausted() async throws {
        // Use a very short conceptual schedule by faking the source: we
        // fail twice with 429, then succeed. The actual delays will fire
        // (1s + 2s = 3s real time), so this test takes ~3 seconds.
        var attempts = 0
        let result = try await RateLimit.withBackoff { () -> String in
            attempts += 1
            if attempts < 3 {
                throw ATProtoError(status: 429, message: "still throttled")
            }
            return "ok"
        }
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(attempts, 3)
    }
}
