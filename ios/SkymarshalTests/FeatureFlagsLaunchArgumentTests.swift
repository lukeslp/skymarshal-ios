import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class FeatureFlagsLaunchArgumentTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: FeatureFlags.visualizationHubKey)
        UserDefaults.standard.removeObject(forKey: FeatureFlags.analyticsInsightsKey)
    }

    func test_applyLaunchArgumentOverrides_visualizationHub_yes() {
        UserDefaults.standard.set(false, forKey: FeatureFlags.visualizationHubKey)
        FeatureFlags.applyLaunchArgumentOverrides(from: [
            "/path/to/app",
            "-sm.feature.visualizationHub", "YES",
        ])
        XCTAssertTrue(UserDefaults.standard.bool(forKey: FeatureFlags.visualizationHubKey))
    }

    func test_applyLaunchArgumentOverrides_skips_unknown_flags() {
        UserDefaults.standard.set(false, forKey: FeatureFlags.visualizationHubKey)
        FeatureFlags.applyLaunchArgumentOverrides(from: [
            "/path",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryLarge",
            "-sm.feature.visualizationHub", "1",
        ])
        XCTAssertTrue(UserDefaults.standard.bool(forKey: FeatureFlags.visualizationHubKey))
    }
}
