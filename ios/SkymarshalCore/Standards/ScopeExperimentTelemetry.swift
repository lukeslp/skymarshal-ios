import Foundation

/// On-device counters for the Scope navigation experiment (tab vs
/// Insights entry). **Never leaves the device** — read via
/// ``summary()`` for TestFlight notes or `defaults read` during betas.
@available(iOS 17, *)
public enum ScopeExperimentTelemetry: Sendable {
    private static let hubAppearancesKey = "sm.telemetry.scopeHubAppearances"
    private static let insightsPathOpensKey = "sm.telemetry.scopeOpenedFromInsights"
    private static let insightsOfferShownKey = "sm.telemetry.scopeInsightsOfferImpressions"

    public static func recordScopeHubAppearance() {
        increment(hubAppearancesKey)
    }

    public static func recordScopeOpenedFromInsightsPath() {
        increment(insightsPathOpensKey)
    }

    public static func recordInsightsScopeEntryOfferDisplayed() {
        increment(insightsOfferShownKey)
    }

    public static func summary() -> [String: Int] {
        let d = UserDefaults.standard
        return [
            "scopeHubAppearances": d.integer(forKey: hubAppearancesKey),
            "scopeOpenedFromInsights": d.integer(forKey: insightsPathOpensKey),
            "scopeInsightsOfferImpressions": d.integer(forKey: insightsOfferShownKey),
        ]
    }

    private static func increment(_ key: String) {
        let d = UserDefaults.standard
        let n = d.integer(forKey: key)
        d.set(n + 1, forKey: key)
    }
}
