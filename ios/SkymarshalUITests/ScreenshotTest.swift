import XCTest

/// App Store screenshot capture. Not part of the regression suite — run
/// explicitly with:
///   ios/scripts/capture_screenshots.sh "iPhone 17 Pro Max" iphone-6.9
///   ios/scripts/capture_screenshots.sh "iPad Pro 13-inch (M5)" ipad-13
/// The script boots the simulator, pins the 9:41 status bar, runs this test,
/// and exports the named attachments from the .xcresult.
///
/// The story needs a signed-in session with a populated archive. Two ways in:
///   1. A simulator whose keychain already holds a Skymarshal session
///      (the capture script does not manage this — see the script header).
///   2. `SKY_TEST_HANDLE` / `SKY_TEST_APP_PASSWORD` in the runner
///      environment (script passes them via TEST_RUNNER_*); the test types
///      them into the native login fields. Credentials are never hardcoded.
/// With neither, the test captures the welcome screen and fails loudly so
/// the missing-demo-account blocker is impossible to miss.
///
/// READ-ONLY GUARANTEE: the story is search, filters, and follower scoring
/// only. It never taps Delete, Unfollow, Refresh, or selection mode — the
/// demo session's archive is real and must come out untouched.
final class ScreenshotTest: XCTestCase {

    /// `XCUIScreen.main.screenshot()` returns the portrait framebuffer even
    /// when the device is in landscape; `app.screenshot()` honors the
    /// interface orientation.
    private func snap(_ name: String, of app: XCUIApplication) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// Failure forensics: the exported a11y hierarchy is the only view into
    /// what XCUITest actually saw on a headless run.
    private func attachHierarchy(of app: XCUIApplication, name: String) {
        let att = XCTAttachment(string: app.debugDescription)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// Dismiss the auto-presenting About / what's-new sheet if it is up.
    /// Identified by its "About" navigation bar + "Done" button.
    private func dismissAboutSheetIfPresent(in app: XCUIApplication) {
        let aboutNav = app.navigationBars["About"]
        if aboutNav.waitForExistence(timeout: 3) {
            let done = app.buttons["Done"].firstMatch
            if done.exists, done.isHittable {
                done.tap()
                _ = aboutNav.waitForNonExistence(timeout: 5)
            }
        }
    }

    func testCaptureScreenshots() {
        // Portrait only. A simulator left rotated by an earlier run corrupts
        // tap geometry; setting .portrait explicitly heals it.
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launch()

        // ── Gate: signed-in Content tab or the LoginView ──────────────────
        let contentNav = app.navigationBars["Content"]
        let signInButton = app.buttons["Sign in"]
        let gateDeadline = Date().addingTimeInterval(30)
        while !contentNav.exists && !signInButton.exists && Date() < gateDeadline {
            Thread.sleep(forTimeInterval: 1.0)
        }

        if !contentNav.exists {
            signIn(app: app, contentNav: contentNav)
        }

        XCTAssertTrue(contentNav.waitForExistence(timeout: 30),
                      "Content tab never rendered")

        // The "About" sheet auto-presents as a what's-new card after any
        // build change and sits modally over the whole UI — it eats every
        // tap (search focus, filter button) until dismissed. Close it first.
        dismissAboutSheetIfPresent(in: app)

        // Cached archive hydrates from SwiftData; give rows + chip counts a
        // beat to settle (39k items on the demo session).
        Thread.sleep(forTimeInterval: 4.0)

        // ── 1. Populated archive + live search ─────────────────────────────
        // The hero frame is the archive with a search active — type chips
        // with real counts, rows with media thumbnails. The populated list
        // alone is a strong frame, so search typing is best-effort: we only
        // type once the keyboard has actually attached (the signed-in account
        // auto-refreshes on launch and can drop focus mid-rebuild).
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 15),
                      "search field never appeared")
        let keyboard = app.keyboards.firstMatch
        var typedSearch = false
        for _ in 1...3 {
            searchField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if keyboard.waitForExistence(timeout: 4) {
                Thread.sleep(forTimeInterval: 0.5)
                searchField.typeText("language")
                Thread.sleep(forTimeInterval: 1.0)
                searchField.typeText("\n") // commit + dismiss the keyboard
                typedSearch = true
                break
            }
            Thread.sleep(forTimeInterval: 1.0)
        }
        if !typedSearch {
            attachHierarchy(of: app, name: "94-hierarchy-search-no-focus")
        }
        Thread.sleep(forTimeInterval: 2.0)
        snap("01-search", of: app)

        // ── 2. Filter sheet ────────────────────────────────────────────────
        // accessibilityLabel is "Filters" or "Filters, active" — match the
        // trailing 's' so the inner "Filter" text label can't shadow the
        // real button. Case-insensitive (UI text is styled).
        let filterButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'filters'")).firstMatch
        XCTAssertTrue(filterButton.waitForExistence(timeout: 10),
                      "Filter button not found")
        let filtersNav = app.navigationBars["Filters"]
        for _ in 1...3 {
            filterButton.tap()
            if filtersNav.waitForExistence(timeout: 4) { break }
        }
        XCTAssertTrue(filtersNav.exists, "filter sheet never opened")
        Thread.sleep(forTimeInterval: 1.0)

        // Configure the sheet so the shot demonstrates depth: media-only +
        // alt-text search. Both are local draft state — Apply only changes
        // the on-device filter. Best-effort: the sheet alone still reads well.
        let mediaPicker = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'media'")).firstMatch
        if mediaPicker.waitForExistence(timeout: 5), mediaPicker.isHittable {
            mediaPicker.tap()
            let withMedia = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'with media'")).firstMatch
            if withMedia.waitForExistence(timeout: 5) {
                withMedia.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        let altToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'alt text'")).firstMatch
        if altToggle.exists, altToggle.isHittable {
            altToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        snap("02-filters", of: app)

        // ── 3. Filtered results (media thumbnails) ─────────────────────────
        let applyButton = app.buttons["Apply"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5), "Apply not found")
        applyButton.tap()
        Thread.sleep(forTimeInterval: 2.5)
        snap("03-media-results", of: app)

        // ── 4. Patterns scoring ────────────────────────────────────────────
        var followersTab = app.tabBars.buttons["Patterns"]
        if !followersTab.exists { followersTab = app.buttons["Patterns"].firstMatch }
        XCTAssertTrue(followersTab.waitForExistence(timeout: 10),
                      "Patterns tab not reachable")
        followersTab.tap()
        XCTAssertTrue(app.navigationBars["Patterns"].waitForExistence(timeout: 10),
                      "Patterns screen never appeared")

        // Fresh sessions land on the empty state; the scan reads the follow
        // list and scores it locally — no writes. Kicking it off is safe.
        let beginScan = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'begin scan'")).firstMatch
        if beginScan.waitForExistence(timeout: 5), beginScan.isHittable {
            beginScan.tap()
        }

        // Accounts stream in as the scan progresses. Wait for the list to
        // populate, then for the count to go quiet (scan finished) — network
        // bound, so the deadline is generous.
        let firstRow = app.cells.firstMatch
        let populateDeadline = Date().addingTimeInterval(300)
        while !firstRow.exists && Date() < populateDeadline {
            Thread.sleep(forTimeInterval: 3.0)
        }
        if !firstRow.exists {
            snap("91-debug-followers-timeout", of: app)
            attachHierarchy(of: app, name: "92-hierarchy-followers-timeout")
        }
        XCTAssertTrue(firstRow.exists, "follower scan never produced rows")

        var lastCount = -1
        var stableSince = Date()
        let scanDeadline = Date().addingTimeInterval(540)
        while Date() < scanDeadline {
            let count = app.cells.count
            if count != lastCount {
                lastCount = count
                stableSince = Date()
            } else if Date().timeIntervalSince(stableSince) > 30 {
                break // count quiet for 30s — scan settled
            }
            Thread.sleep(forTimeInterval: 5.0)
        }
        Thread.sleep(forTimeInterval: 2.0)
        snap("04-followers", of: app)

        // ── 5. Account detail (best-effort) ────────────────────────────────
        // Row tap opens a read-only detail sheet; we snap and Close. The
        // unfollow actions live behind explicit buttons we never touch.
        if firstRow.isHittable {
            firstRow.tap()
            let accountNav = app.navigationBars["Account"]
            if accountNav.waitForExistence(timeout: 10) {
                Thread.sleep(forTimeInterval: 2.0)
                snap("05-account-detail", of: app)
                let close = app.buttons["Close"].firstMatch
                if close.exists, close.isHittable { close.tap() }
            }
        }
    }

    /// Logged-out path: capture the welcome frame, then sign in with
    /// environment-injected credentials if present. Without credentials the
    /// welcome shot is the only honest capture — fail so the blocker shows.
    private func signIn(app: XCUIApplication, contentNav: XCUIElement) {
        Thread.sleep(forTimeInterval: 2.0) // dot-matrix header settles
        snap("01-welcome", of: app)

        let env = ProcessInfo.processInfo.environment
        guard let handle = env["SKY_TEST_HANDLE"], !handle.isEmpty,
              let password = env["SKY_TEST_APP_PASSWORD"], !password.isEmpty else {
            attachHierarchy(of: app, name: "93-hierarchy-logged-out")
            XCTFail("""
                Signed out and no demo credentials in the environment \
                (SKY_TEST_HANDLE / SKY_TEST_APP_PASSWORD). Only the welcome \
                screen was captured. Provide credentials via the capture \
                script to shoot the full signed-in story.
                """)
            return
        }

        let handleField = app.textFields.firstMatch
        XCTAssertTrue(handleField.waitForExistence(timeout: 10),
                      "handle field not found")
        handleField.tap()
        handleField.typeText(handle)

        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5),
                      "app-password field not found")
        passwordField.tap()
        passwordField.typeText(password)

        let signInButton = app.buttons["Sign in"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5), "Sign in not found")
        signInButton.tap()

        // First sync paginates the whole archive over the network — a big
        // account takes minutes. The nav bar appears as soon as auth lands;
        // the archive then streams in behind the progress banner.
        XCTAssertTrue(contentNav.waitForExistence(timeout: 600),
                      "sign-in never reached the Content tab (bad credentials or network)")
    }
}
