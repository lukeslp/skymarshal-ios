import XCTest
@testable import SkymarshalCore

/// AppPasswordFormat backs the login-failure hint: when the submitted
/// password doesn't look like a Bluesky app password
/// (`xxxx-xxxx-xxxx-xxxx`), AppModel prefixes the error with a pointer
/// to Settings → App Passwords. These tests pin the shape check.
final class AppPasswordFormatTests: XCTestCase {

    func test_canonicalAppPassword_matches() {
        XCTAssertTrue(AppPasswordFormat.looksLikeAppPassword("abcd-1234-wxyz-9876"))
    }

    func test_uppercase_matches_caseInsensitive() {
        XCTAssertTrue(AppPasswordFormat.looksLikeAppPassword("ABCD-1234-WXYZ-9876"))
        XCTAssertTrue(AppPasswordFormat.looksLikeAppPassword("AbCd-12eF-wXyZ-98Gh"))
    }

    func test_mainAccountPassword_doesNotMatch() {
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("hunter2!secret"))
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("correct horse battery staple"))
    }

    func test_emptyString_doesNotMatch() {
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword(""))
    }

    func test_wrongGroupCount_doesNotMatch() {
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("abcd-1234-wxyz"))
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("abcd-1234-wxyz-9876-zzzz"))
    }

    func test_wrongGroupLength_doesNotMatch() {
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("abc-1234-wxyz-9876"))
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("abcde-1234-wxyz-9876"))
    }

    func test_nonAlphanumericCharacters_doNotMatch() {
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("ab!d-1234-wxyz-9876"))
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword("abcd_1234_wxyz_9876"))
    }

    func test_surroundingWhitespace_doesNotMatch() {
        // The regex is anchored — trimming is the caller's job.
        XCTAssertFalse(AppPasswordFormat.looksLikeAppPassword(" abcd-1234-wxyz-9876 "))
    }
}
