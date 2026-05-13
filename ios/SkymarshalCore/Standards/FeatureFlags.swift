import Foundation

/// UserDefaults keys for gradual rollout of imported upstream-adjacent features.
/// Defaults are **on** so shipping builds expose capability unless explicitly gated off.
@available(iOS 17, *)
public enum FeatureFlags {
    public static let analyticsInsightsKey = "sm.feature.analyticsInsights"
    public static let savedSearchPresetsKey = "sm.feature.savedSearchPresets"
    public static let cleanupPresetsKey = "sm.feature.cleanupPresets"
    public static let profileExplorerKey = "sm.feature.profileExplorer"
    public static let unfollowDryRunKey = "sm.feature.unfollowDryRun"
    public static let advancedSearchGrammarKey = "sm.feature.advancedSearchGrammar"
    public static let visualizationHubKey = "sm.feature.visualizationHub"
    public static let wordPatternsKey = "sm.feature.wordPatterns"
    public static let backupRestoreKey = "sm.feature.backupRestore"

    public static func bool(for key: String, default defaultValue: Bool = true) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    public static func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
