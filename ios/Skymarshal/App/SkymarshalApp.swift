import SwiftUI
import SkymarshalCore

@main
struct SkymarshalApp: App {
    init() {
        ColdLaunchSignposts.event("app_init_entry")
        #if DEBUG
        // Crash early if a bundled font family failed to register. Catches
        // the "I forgot to add the OTF to Copy Bundle Resources" failure
        // mode before TestFlight. Release builds intentionally skip this.
        Theme.audit()
        #endif
        if ProcessInfo.processInfo.environment["UITEST_RESET_FEATURE_DEFAULTS"] == "1" {
            UserDefaults.standard.set(true, forKey: FeatureFlags.analyticsInsightsKey)
            UserDefaults.standard.set(false, forKey: FeatureFlags.visualizationHubKey)
        }
        FeatureFlags.applyLaunchArgumentOverrides()
        BackgroundTaskCoordinator.register()
        ColdLaunchSignposts.event("app_init_exit")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
