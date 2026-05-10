import XCTest
@testable import Skymarshal

/// BotFlagSeverity is a severity classifier for the human-readable
/// flag strings BluescreenAnalyzer produces. Driven by substring
/// match (decoupled from analyzer's internal weights). These tests
/// guard against drift: if the analyzer adds a new flag string that
/// SHOULD be High or Medium but the classifier doesn't recognize it,
/// it falls to Low — these cases assert the classifier still
/// recognizes every known flag.
final class BotFlagSeverityTests: XCTestCase {

    // MARK: - High severity (confident bot signals)

    func test_massFollowing_isHigh() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Mass following, very low ratio"),
            .high
        )
    }

    func test_noPostsDespiteFollowing_isHigh() {
        XCTAssertEqual(
            BotFlagSeverity.classify("No posts despite following many"),
            .high
        )
    }

    func test_deletedAccount_isHigh() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Deleted account (handle.invalid)"),
            .high
        )
    }

    // MARK: - Medium severity (strong but not conclusive)

    func test_highFollowingLowRatio_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("High following, low ratio"),
            .medium
        )
    }

    func test_veryFewPosts_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Very few posts, high following"),
            .medium
        )
    }

    func test_newAccount_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("New account, aggressive following"),
            .medium
        )
    }

    func test_missingProfileBits_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Missing: display name, bio, avatar"),
            .medium
        )
    }

    // MARK: - Low severity (informational signals)

    func test_roundNumberFollowing_isLow() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Round number following count"),
            .low
        )
    }

    func test_suspiciouslyHighRatio_isLow() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Suspiciously high follower ratio"),
            .low
        )
    }

    func test_youngAccount_isMedium_viaHighFollowingMatch() {
        // "Young account, high following" hits the Medium bucket via the
        // "high following" substring — appropriate severity for a 1.5-weight
        // analyzer factor. The match is incidental but correct.
        XCTAssertEqual(
            BotFlagSeverity.classify("Young account, high following"),
            .medium
        )
    }

    // MARK: - Drift guard

    func test_unknownFlag_fallsToLow_notCrash() {
        XCTAssertEqual(BotFlagSeverity.classify(""), .low)
        XCTAssertEqual(
            BotFlagSeverity.classify("Some future flag string the analyzer might add"),
            .low
        )
    }

    // MARK: - Visual properties

    func test_severities_haveDistinctIconsAndColors() {
        XCTAssertNotEqual(BotFlagSeverity.high.iconName, BotFlagSeverity.medium.iconName)
        XCTAssertNotEqual(BotFlagSeverity.medium.iconName, BotFlagSeverity.low.iconName)
        XCTAssertEqual(BotFlagSeverity.high.label, "High")
        XCTAssertEqual(BotFlagSeverity.medium.label, "Medium")
        XCTAssertEqual(BotFlagSeverity.low.label, "Low")
    }
}
