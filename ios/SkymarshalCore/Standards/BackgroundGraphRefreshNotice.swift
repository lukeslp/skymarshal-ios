import Foundation

/// UserDefaults key set when a background graph snapshot refresh completes
/// so the Content tab can show a one-line honesty banner (cleared on read).
@available(iOS 17, *)
public enum BackgroundGraphRefreshNotice: Sendable {
    public static let pendingUserDefaultsKey = "sm.pendingBackgroundGraphRefreshNotice"
}
