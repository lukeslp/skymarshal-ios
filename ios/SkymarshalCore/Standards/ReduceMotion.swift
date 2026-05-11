import Foundation

/// Single source of truth for "should this animation run?". Composes
/// the system reduce-motion preference (read by SwiftUI via
/// `@Environment(\.accessibilityReduceMotion)`) with an in-app
/// override toggle persisted under `sm.reduceMotionOverride`. Either
/// being true short-circuits motion.
///
/// Call sites pass the system value in (they get it from the env)
/// instead of this module reading it directly — keeps SkymarshalCore
/// free of any SwiftUI / UIKit dependency in this Standard.
@available(iOS 17, *)
public enum ReduceMotion {
    /// UserDefaults key for the user-facing override. Mirrors the
    /// @AppStorage key in AboutView so a write from the toggle is
    /// picked up here on the next read.
    public static let overrideKey = "sm.reduceMotionOverride"

    /// True when motion should be suppressed — either the system
    /// preference is on, or the user's in-app override is on.
    public static func shouldReduce(systemReduceMotion: Bool) -> Bool {
        if systemReduceMotion { return true }
        return UserDefaults.standard.bool(forKey: overrideKey)
    }
}
