import SwiftUI
import SkymarshalCore

@main
struct SkymarshalApp: App {
    init() {
        if ProcessInfo.processInfo.environment["UITEST_RESET_FEATURE_DEFAULTS"] == "1" {
            UserDefaults.standard.set(true, forKey: FeatureFlags.analyticsInsightsKey)
            UserDefaults.standard.set(false, forKey: FeatureFlags.visualizationHubKey)
        }
        BackgroundTaskCoordinator.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
