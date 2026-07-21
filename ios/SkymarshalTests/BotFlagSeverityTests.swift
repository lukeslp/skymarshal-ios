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
            BotFlagSeverity.classify("Follows far more accounts than follow it back"),
            .high
        )
    }

    func test_noPostsDespiteFollowing_isHigh() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Has never posted but follows many accounts"),
            .high
        )
    }

    // MARK: - Medium severity (strong but not conclusive)

    func test_highFollowingLowRatio_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Follows many accounts with few following back"),
            .medium
        )
    }

    func test_veryFewPosts_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Hardly ever posts but follows many accounts"),
            .medium
        )
    }

    func test_newAccount_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Brand-new account already following many accounts"),
            .medium
        )
    }

    func test_missingProfileBits_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Profile is missing its display name, bio, avatar"),
            .medium
        )
    }

    // MARK: - Low severity (informational signals)

    func test_roundNumberFollowing_isLow() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Follows an exactly round number of accounts, common for automation"),
            .low
        )
        XCTAssertEqual(
            BotFlagSeverity.classify("Following count lands on a round number, which automation sometimes produces"),
            .low
        )
    }

    func test_veryHighFollowerRatio_isLow() {
        // "Has far more followers than accounts it follows" must NOT trip
        // the High bucket's "far more accounts than follow" keyword —
        // direction matters (followers-heavy is informational, not spam).
        XCTAssertEqual(
            BotFlagSeverity.classify("Has far more followers than accounts it follows"),
            .low
        )
    }

    func test_mildFollowsHeavyRatio_isLow() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Follows somewhat more accounts than follow back"),
            .low
        )
    }

    func test_youngAccount_isMedium() {
        XCTAssertEqual(
            BotFlagSeverity.classify("Account only weeks old and follows hundreds of accounts"),
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
