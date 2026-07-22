import Foundation

/// Persists a conservative App Store review-prompt cadence.
///
/// The policy only becomes eligible after several meaningful successes and a
/// few days of use. It records prompt attempts so StoreKit is not called over
/// and over during the same release.
public struct ReviewPromptPolicy {
    public struct Configuration {
        public var minimumUsageDays: Int
        public var minimumSuccessfulActions: Int
        public var cooldownDays: Int

        public init(
            minimumUsageDays: Int = 3,
            minimumSuccessfulActions: Int = 3,
            cooldownDays: Int = 120
        ) {
            self.minimumUsageDays = minimumUsageDays
            self.minimumSuccessfulActions = minimumSuccessfulActions
            self.cooldownDays = cooldownDays
        }
    }

    private enum Key {
        static let firstUseDate = "sm.review.firstUseDate"
        static let successfulActions = "sm.review.successfulActions"
        static let lastRequestDate = "sm.review.lastRequestDate"
        static let lastRequestedVersion = "sm.review.lastRequestedVersion"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let configuration: Configuration

    public init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        configuration: Configuration = Configuration()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.configuration = configuration
    }

    /// Establishes the age-of-use clock without resetting returning users.
    public func noteAppOpened(at date: Date = Date()) {
        guard defaults.object(forKey: Key.firstUseDate) == nil else { return }
        defaults.set(date, forKey: Key.firstUseDate)
    }

    /// Records one completed, user-meaningful operation. Destructive actions
    /// accrue credit but pass `allowsPrompt: false`, keeping the rating sheet
    /// away from a potentially stressful moment. Eligibility remains pending
    /// until the UI records an actual StoreKit request attempt.
    @discardableResult
    public func registerSuccessfulAction(
        appVersion: String,
        allowsPrompt: Bool = true,
        at date: Date = Date()
    ) -> Bool {
        noteAppOpened(at: date)

        let successes = defaults.integer(forKey: Key.successfulActions) + 1
        defaults.set(successes, forKey: Key.successfulActions)

        return allowsPrompt && isEligible(appVersion: appVersion, at: date)
    }

    /// Checks persisted eligibility without consuming it. This lets the app
    /// retry after a covered, inactive, or interrupted presentation attempt.
    public func isEligible(appVersion: String, at date: Date = Date()) -> Bool {
        defaults.integer(forKey: Key.successfulActions) >= configuration.minimumSuccessfulActions
            && hasReachedMinimumUsageAge(at: date)
            && defaults.string(forKey: Key.lastRequestedVersion) != appVersion
            && hasClearedCooldown(at: date)
    }

    /// Records the moment the active UI hands the request to StoreKit.
    public func recordRequestAttempt(appVersion: String, at date: Date = Date()) {
        guard isEligible(appVersion: appVersion, at: date) else { return }
        defaults.set(date, forKey: Key.lastRequestDate)
        defaults.set(appVersion, forKey: Key.lastRequestedVersion)
        defaults.set(0, forKey: Key.successfulActions)
    }

    private func hasReachedMinimumUsageAge(at date: Date) -> Bool {
        guard let firstUseDate = defaults.object(forKey: Key.firstUseDate) as? Date,
              date >= firstUseDate,
              let eligibleDate = calendar.date(
                byAdding: .day,
                value: configuration.minimumUsageDays,
                to: firstUseDate
              ) else {
            return false
        }
        return date >= eligibleDate
    }

    private func hasClearedCooldown(at date: Date) -> Bool {
        guard let lastRequestDate = defaults.object(forKey: Key.lastRequestDate) as? Date else {
            return true
        }
        guard date >= lastRequestDate,
              let eligibleDate = calendar.date(
                byAdding: .day,
                value: configuration.cooldownDays,
                to: lastRequestDate
              ) else {
            return false
        }
        return date >= eligibleDate
    }
}
