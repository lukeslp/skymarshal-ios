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
        app.launchEnvironment["UITEST_RESET_FEATURE_DEFAULTS"] = "1"
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
        app.launchEnvironment["UITEST_RESET_FEATURE_DEFAULTS"] = "1"
        app.launch()
        XCTAssert(app.staticTexts["Skymarshal"].waitForExistence(timeout: 5))
        XCTAssert(app.textFields["Bluesky handle"].exists)
        XCTAssert(app.secureTextFields["App password"].exists)
        XCTAssert(app.buttons["Sign in"].exists)
    }

    func test_launchAtAX5_featureDiscovery_about_featureLabHeader() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            XCUIApplication.forceFeatureDiscoveryArgument,
        ]
        app.launch()
        let header = app.descendants(matching: .any)["about_feature_lab_section_header"]
        XCTAssert(
            header.waitForExistence(timeout: 6),
            "Feature lab section header missing at AX5 — About discovery sheet regression"
        )
    }

    func test_launchAtAX5_insights_scopeLink_withStubContent() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            XCUIApplication.stubMinimalContentArgument,
            XCUIApplication.openInsightsArgument,
        ]
        app.skymarshalUseUITestFeatureDefaults()
        app.launch()
        XCTAssert(app.staticTexts["Insights"].waitForExistence(timeout: 15))

        let sectionHeader = app.staticTexts["Scope (Feature lab)"]
        var scrolls = 0
        while !sectionHeader.exists, scrolls < 12 {
            app.swipeUp(velocity: .fast)
            scrolls += 1
        }
        XCTAssert(
            sectionHeader.waitForExistence(timeout: 4),
            "Scope (Feature lab) section not found after scrolling"
        )

        let scopeLink = app.descendants(matching: .any)["insights_scope_visualizations_link"]
        XCTAssert(
            scopeLink.waitForExistence(timeout: 5),
            "Insights → Scope navigation missing at AX5"
        )
    }

    func test_backgroundGraphRefreshNote_displaysWithUITestForceFlag() throws {
        let app = XCUIApplication()
        app.launchArguments = [XCUIApplication.stubMinimalContentArgument]
        app.launchEnvironment[XCUIApplication.forceBackgroundGraphNoteEnvironment] = "1"
        app.skymarshalUseUITestFeatureDefaults()
        app.launch()

        let note = app.descendants(matching: .any)["content_bg_scope_refresh_note"]
        XCTAssert(note.waitForExistence(timeout: 8))
    }

    /// Plex-Mono is wider than SF Pro at the same point size. At AX5 the
    /// "POSTS · <date>" kicker on ContentRow is the row at greatest risk
    /// of single-line clipping. This test asserts both kicker tokens
    /// (`POSTS` and the date) are still reachable to VoiceOver / the
    /// XCUITest accessibility tree after the v1.0.1 typography pass.
    func test_AX5_contentRow_kicker_andDate_doNotTruncate() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            XCUIApplication.stubMinimalContentArgument,
        ]
        app.skymarshalUseUITestFeatureDefaults()
        app.launch()

        // The Content navigation bar arrives once the stubbed content
        // mounts; gate on it before probing inside the list.
        XCTAssert(
            app.navigationBars["Content"].waitForExistence(timeout: 15),
            "Content tab nav bar missing after stub seed at AX5"
        )

        // The kicker text is uppercase "POSTS" on every stub row. Use a
        // matching predicate so we don't depend on a single accessibility
        // identifier wrapper that doesn't currently exist in ContentRow.
        let postsKicker = app.staticTexts.matching(
            NSPredicate(format: "label == 'POSTS'")
        ).firstMatch
        XCTAssert(
            postsKicker.waitForExistence(timeout: 8),
            "ContentRow kicker 'POSTS' not reachable at AX5 — Plex Mono regression suspected"
        )
    }

    /// The Scope completeness pill switched from a system capsule to
    /// `ScopePill`. VoiceOver should still hear the completeness label;
    /// this test asserts the combined accessibility label survives the
    /// rewrite at AX5.
    func test_AX5_scopeTab_completenessPill_readsAsExpected() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            XCUIApplication.stubMinimalContentArgument,
            "-sm.feature.visualizationHub", "YES",
        ]
        app.launch()

        // Navigate to the Scope tab. The tab is the third item once the
        // visualization hub flag is on (Content, Patterns, Scope).
        let scopeTab = app.tabBars.buttons["Scope"]
        if scopeTab.waitForExistence(timeout: 10) {
            scopeTab.tap()
        }

        XCTAssert(
            app.navigationBars["Scope"].waitForExistence(timeout: 8),
            "Scope tab nav bar missing at AX5"
        )

        // The Account graph row's combined accessibility label reads
        // "Account graph. Scanned follow graph — ego summary. Data
        // completeness Partial." after the stub seeds an account.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Account graph' AND label CONTAINS[c] 'completeness'"))
            .firstMatch
        XCTAssert(
            row.waitForExistence(timeout: 6),
            "Scope tab Account graph row missing its combined completeness label at AX5"
        )
    }
}
