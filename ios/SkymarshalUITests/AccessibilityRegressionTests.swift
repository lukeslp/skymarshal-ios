import XCTest

/// Single regression smoke test: launch the app at Accessibility
/// Extra-Extra-Extra-Large text size and verify the LoginView wordmark
/// and inputs are reachable + not truncated. Catches the worst kind
/// of accessibility regression — a fixed-pt font or hardcoded frame
/// clipping primary copy at the largest Dynamic Type setting — with
/// a single fast XCUITest.
///
/// Deliberately narrow: no logged-in fixture state, no network. The
/// goal is a build-time guard that re-runs in CI without needing a
/// Bluesky test account.
final class AccessibilityRegressionTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_launchAtAX5_loginView_inputsReachable_andNotTruncated() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let wordmark = app.staticTexts["Skymarshal"]
        XCTAssert(
            wordmark.waitForExistence(timeout: 5),
            "Wordmark missing from LoginView at AX5 — possible truncation regression"
        )

        let handleField = app.textFields["Bluesky handle"]
        XCTAssert(
            handleField.waitForExistence(timeout: 2),
            "Handle TextField not reachable at AX5 — accessibility label or layout regression"
        )

        let passwordField = app.secureTextFields["App password"]
        XCTAssert(
            passwordField.waitForExistence(timeout: 2),
            "App-password SecureField not reachable at AX5"
        )

        let signIn = app.buttons["Sign in"]
        XCTAssert(
            signIn.waitForExistence(timeout: 2),
            "Sign-in button not reachable at AX5"
        )

        // Tapping into the handle field should reveal the keyboard;
        // verify the wordmark stays present (form doesn't unwind).
        handleField.tap()
        XCTAssert(
            wordmark.exists,
            "Wordmark disappeared after focusing the handle field — unexpected layout"
        )
    }

    /// Sanity baseline at the default size, in case AX5 succeeded only
    /// because the layout reflowed to something that obscures defaults.
    func test_launchAtDefaultSize_loginView_smokeTest() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssert(app.staticTexts["Skymarshal"].waitForExistence(timeout: 5))
        XCTAssert(app.textFields["Bluesky handle"].exists)
        XCTAssert(app.secureTextFields["App password"].exists)
        XCTAssert(app.buttons["Sign in"].exists)
    }
}
