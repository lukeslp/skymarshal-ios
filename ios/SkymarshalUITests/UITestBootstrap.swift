import XCTest

/// Centralizes launch flags understood by the Skymarshal app target
/// (`SkymarshalApp`, `RootView`, `ContentListView`, `AppModel`).
extension XCUIApplication {

    /// Forces Feature lab defaults suitable for Content-tab UI tests: Insights on, Scope tab off.
    func skymarshalUseUITestFeatureDefaults() {
        launchEnvironment["UITEST_RESET_FEATURE_DEFAULTS"] = "1"
    }

    /// Shows the post-update About sheet without bumping app version (pairs with `-uitestForceFeatureDiscovery`).
    static let forceFeatureDiscoveryArgument = "-uitestForceFeatureDiscovery"

    /// Injects a minimal cached post so TabView mounts without auth or network.
    static let stubMinimalContentArgument = "-uitestStubMinimalContent"

    /// Opens Insights shortly after Content appears (pairs with `.task` in ContentListView).
    static let openInsightsArgument = "-uitestOpenInsights"

    /// Forces the background-graph honesty banner (pairs with `UITEST_FORCE_BG_SCOPE_NOTE` env).
    static let forceBackgroundGraphNoteEnvironment = "UITEST_FORCE_BG_SCOPE_NOTE"
}
