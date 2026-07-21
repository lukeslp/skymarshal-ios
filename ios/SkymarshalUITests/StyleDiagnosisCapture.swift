// StyleDiagnosisCapture.swift
//
// Purpose: one-shot screenshot harness for the Move #1 style diagnosis.
// Captures the four primary surfaces (LoginView, Content tab,
// Followers tab, Scope tab) as XCTAttachment screenshots with
// `.keepAlways` lifetime so we can extract them from the .xcresult
// bundle and eyeball what reads as "default iOS chrome" vs the
// real Skymarshal visual identity (dot-matrix bird, scope motif,
// Theme tokens, Liquid Glass TabView).
//
// Not a regression test. Skip in CI. Run on-demand:
//   xcodebuild test -scheme Skymarshal \
//     -destination 'platform=iOS Simulator,name=iPhone 17' \
//     -only-testing:SkymarshalUITests/StyleDiagnosisCapture
//
// Inputs:   none (uses stub content + launch-arg UserDefaults overrides)
// Outputs:  4 PNG attachments on the .xcresult bundle, named 01..04.

import XCTest

final class StyleDiagnosisCapture: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 01: LoginView (signed-out cold start)

    func test_capture_01_loginView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_FEATURE_DEFAULTS"] = "1"
        app.launch()
        XCTAssert(
            app.staticTexts["Skymarshal"].waitForExistence(timeout: 8),
            "LoginView wordmark missing — bootstrap failed"
        )
        // Give the dot-matrix bird header a beat to settle past its appear animation.
        sleep(1)
        attachScreenshot(named: "01-LoginView", from: app)
    }

    // MARK: - 02: Content tab (stub fixture, Insights + sort visible)

    func test_capture_02_contentTab() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.stubMinimalContentArgument,
            // Force Scope ON so we can also reach it for screenshot 04
            // without a second build; arg domain overrides @AppStorage default.
            "-sm.feature.visualizationHub", "YES",
            "-sm.feature.analyticsInsights", "YES",
            "-sm.feature.savedSearchPresets", "YES",
        ]
        app.launch()
        let contentNav = app.navigationBars["Content"]
        XCTAssert(
            contentNav.waitForExistence(timeout: 15),
            "Content navigation bar didn't appear after stub-content launch"
        )
        sleep(1)
        attachScreenshot(named: "02-ContentTab", from: app)
    }

    // MARK: - 03: Followers tab (Bluescreen)

    func test_capture_03_followersTab() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.stubMinimalContentArgument,
            "-sm.feature.visualizationHub", "YES",
            "-sm.feature.analyticsInsights", "YES",
            "-sm.feature.savedSearchPresets", "YES",
        ]
        app.launch()
        XCTAssert(
            app.navigationBars["Content"].waitForExistence(timeout: 15),
            "Content nav bar required before tab navigation"
        )
        let followersTab = firstHittable(
            in: app,
            labels: ["Patterns"],
            preferTabBar: true
        )
        XCTAssertNotNil(followersTab, "Patterns tab button not reachable")
        followersTab?.tap()
        let bluescreenNav = app.navigationBars["Patterns"]
        XCTAssert(
            bluescreenNav.waitForExistence(timeout: 8),
            "Patterns nav bar didn't appear after tab tap"
        )
        sleep(1)
        attachScreenshot(named: "03-PatternsTab", from: app)
    }

    // MARK: - 04: Scope tab (VisualizationHubView)

    func test_capture_04_scopeTab() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.stubMinimalContentArgument,
            "-sm.feature.visualizationHub", "YES",
            "-sm.feature.analyticsInsights", "YES",
            "-sm.feature.savedSearchPresets", "YES",
        ]
        app.launch()
        XCTAssert(
            app.navigationBars["Content"].waitForExistence(timeout: 15),
            "Content nav bar required before tab navigation"
        )
        let scopeTab = firstHittable(in: app, labels: ["Scope"], preferTabBar: true)
        XCTAssertNotNil(
            scopeTab,
            "Scope tab button not reachable — feature flag override may not have applied"
        )
        scopeTab?.tap()
        let scopeNav = app.navigationBars["Scope"]
        XCTAssert(
            scopeNav.waitForExistence(timeout: 8),
            "Scope nav bar didn't appear after tab tap"
        )
        sleep(1)
        attachScreenshot(named: "04-ScopeTab", from: app)
    }

    // MARK: - Helpers

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// iOS 26 TabView uses a floating Liquid Glass pill that doesn't always
    /// expose a classic `tabBars` element. Probe both the tabBars subtree
    /// and the plain buttons collection for a label match, return the
    /// first hittable result.
    private func firstHittable(
        in app: XCUIApplication,
        labels: [String],
        preferTabBar: Bool
    ) -> XCUIElement? {
        if preferTabBar {
            for label in labels {
                let element = app.tabBars.buttons[label]
                if element.exists, element.isHittable { return element }
            }
        }
        for label in labels {
            let element = app.buttons[label]
            if element.exists, element.isHittable { return element }
        }
        for label in labels {
            // Last resort: any descendant matching the label.
            let element = app.descendants(matching: .any)[label]
            if element.exists, element.isHittable { return element }
        }
        return nil
    }
}
