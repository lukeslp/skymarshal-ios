import Foundation

/// UserDefaults keys for gradual rollout of imported upstream-adjacent features.
///
/// **First-launch defaults** (when the key is absent in `UserDefaults`) are defined by
/// each call site’s `@AppStorage(..., default:)` or by passing an explicit `defaultValue`
/// to ``bool(for:default:)``. There is no single global default.
///
/// | Key | Typical first-launch default | Notes |
/// |-----|------------------------------|--------|
/// | `sm.feature.analyticsInsights` | on | Insights sheet from Content options |
/// | `sm.feature.savedSearchPresets` | on | Presets in Content options menu |
/// | `sm.feature.cleanupPresets` | on | Followers cleanup chips |
/// | `sm.feature.profileExplorer` | on | Account sheet explorer |
/// | `sm.feature.unfollowDryRun` | on | Dry-run unfollow preview |
/// | `sm.feature.advancedSearchGrammar` | **off** | Advanced builder + grammar |
/// | `sm.feature.visualizationHub` | **off** | Scope tab in root `TabView` |
/// | `sm.feature.wordPatterns` | **off** | Lexicon stats in Insights |
/// | `sm.feature.backupRestore` | **off** | About → backup import |
/// | `sm.ui.contentPowerToolsExpanded` | **off** | Content tab: full stats strip + empty-state filter chips |
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
    /// When `false`, Content tab hides the visible-count / avg-engagement strip and shows
    /// active filter chips only while filters are active (see `ContentListView`).
    public static let contentPowerToolsExpandedKey = "sm.ui.contentPowerToolsExpanded"

    /// - Parameters:
    ///   - key: A ``FeatureFlags`` key constant.
    ///   - defaultValue: Value returned when the key has never been set. Callers should pass
    ///     the same default their `@AppStorage` uses for that key (see table above).
    public static func bool(for key: String, default defaultValue: Bool = false) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    public static func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    /// Applies paired launch arguments of the form `-<UserDefaultsKey> <YES|NO|1|0>`
    /// for known feature keys. Used by XCUITest (`-sm.feature.*`) and local
    /// profiling so flags reach `@AppStorage` / ``bool(for:default:)``.
    ///
    /// Call **after** any `UITEST_RESET_FEATURE_DEFAULTS` bootstrap so explicit
    /// `-sm.feature.*` pairs win over the reset template.
    public static func applyLaunchArgumentOverrides(from arguments: [String] = ProcessInfo.processInfo.arguments) {
        let keys: Set<String> = [
            analyticsInsightsKey,
            savedSearchPresetsKey,
            cleanupPresetsKey,
            profileExplorerKey,
            unfollowDryRunKey,
            advancedSearchGrammarKey,
            visualizationHubKey,
            wordPatternsKey,
            backupRestoreKey,
            contentPowerToolsExpandedKey,
        ]
        for i in 0..<(arguments.count - 1) {
            let token = arguments[i]
            guard token.hasPrefix("-"), token.count > 1 else { continue }
            let candidateKey = String(token.dropFirst())
            guard keys.contains(candidateKey) else { continue }
            let raw = arguments[i + 1].uppercased()
            let on = raw == "YES" || raw == "1" || raw == "TRUE"
            UserDefaults.standard.set(on, forKey: candidateKey)
        }
    }
}
