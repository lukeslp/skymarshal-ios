import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Guided Mode Tier 1 — the access settings layer. See
/// `docs/GUIDED_MODE_SPEC.md` §4 for the design spec this implements.
///
/// This file holds the pure, testable pieces: the setting enums, their
/// `UserDefaults` keys/defaults, and any value math (e.g. the extended
/// arm-window multiplier). SwiftUI plumbing (the `EnvironmentKey`s) lives
/// in the app target's `GuidedModeEnvironment.swift`, mirroring the split
/// `ReduceMotion` already established — SkymarshalCore stays free of any
/// SwiftUI/UIKit dependency in this Standard.
@available(iOS 17, *)
public enum GuidedModeSettings {

    // MARK: - Target size floor

    /// Minimum tappable target size. `Standard` matches the app-wide HIG
    /// floor already in place (see `TypeChipsRow`/`ScanSummaryStrip`
    /// 44pt hit targets); `Large`/`Max` are guided-mode-oriented per
    /// spec §2.3 and §4.
    public enum TargetSizeFloor: String, CaseIterable, Identifiable, Codable, Sendable {
        case standard
        case large
        case max

        public var id: String { rawValue }

        /// Point value applied to `frame(minWidth:minHeight:)` /
        /// `contentShape` at consuming call sites.
        public var points: CGFloat {
            switch self {
            case .standard: return 44
            case .large: return 60
            case .max: return 88
            }
        }

        public var label: String {
            switch self {
            case .standard: return "Standard (44pt)"
            case .large: return "Large (60pt)"
            case .max: return "Max (88pt)"
            }
        }
    }

    public static let targetSizeFloorKey = "sm.guided.targetSizeFloor"
    public static let targetSizeFloorDefault: TargetSizeFloor = .standard

    /// Reads the stored floor, falling back to the default when absent
    /// or unparseable. Used by the environment key's default resolver.
    public static func targetSizeFloor(from defaults: UserDefaults = .standard) -> TargetSizeFloor {
        guard let raw = defaults.string(forKey: targetSizeFloorKey),
              let value = TargetSizeFloor(rawValue: raw) else {
            return targetSizeFloorDefault
        }
        return value
    }

    // MARK: - Max choices per screen

    /// Caps how many answer cells a guided screen (or a filter surface
    /// steered toward preset buttons) offers at once. `.full` means no
    /// cap — the standard UI's normal choice count.
    public enum MaxChoicesPerScreen: String, CaseIterable, Identifiable, Codable, Sendable {
        case full
        case six
        case four

        public var id: String { rawValue }

        /// `nil` means unbounded (the `.full` case).
        public var limit: Int? {
            switch self {
            case .full: return nil
            case .six: return 6
            case .four: return 4
            }
        }

        public var label: String {
            switch self {
            case .full: return "Full"
            case .six: return "6 max"
            case .four: return "4 max"
            }
        }
    }

    public static let maxChoicesPerScreenKey = "sm.guided.maxChoicesPerScreen"
    public static let maxChoicesPerScreenDefault: MaxChoicesPerScreen = .full

    public static func maxChoicesPerScreen(from defaults: UserDefaults = .standard) -> MaxChoicesPerScreen {
        guard let raw = defaults.string(forKey: maxChoicesPerScreenKey),
              let value = MaxChoicesPerScreen(rawValue: raw) else {
            return maxChoicesPerScreenDefault
        }
        return value
    }

    // MARK: - Confirmation style preference

    /// Explicit user override for which `TypedConfirmSheet` confirmation
    /// mechanism is offered. `.automatic` preserves today's behavior —
    /// detect active assistive technology and offer typed confirm plus
    /// the hold/two-step alternatives. A specific style pins the sheet
    /// to that single mechanism regardless of AT status.
    public enum ConfirmationStyle: String, CaseIterable, Identifiable, Codable, Sendable {
        case automatic
        case typed
        case twoStep
        case hold

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .typed: return "Typed word"
            case .twoStep: return "Two-step"
            case .hold: return "Hold to confirm"
            }
        }
    }

    public static let confirmationStyleKey = "sm.guided.confirmationStyle"
    public static let confirmationStyleDefault: ConfirmationStyle = .automatic

    public static func confirmationStyle(from defaults: UserDefaults = .standard) -> ConfirmationStyle {
        guard let raw = defaults.string(forKey: confirmationStyleKey),
              let value = ConfirmationStyle(rawValue: raw) else {
            return confirmationStyleDefault
        }
        return value
    }

    // MARK: - Extended timeouts

    /// When on, timed confirmation windows (two-step arm window,
    /// hold-to-confirm duration) run at 3x their base duration. Spec
    /// §4: "arming windows ×3, no short-lived UI."
    public static let extendedTimeoutsKey = "sm.guided.extendedTimeouts"
    public static let extendedTimeoutsDefault = false

    public static let extendedTimeoutsMultiplier: Double = 3

    public static func extendedTimeoutsEnabled(from defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: extendedTimeoutsKey) != nil else {
            return extendedTimeoutsDefault
        }
        return defaults.bool(forKey: extendedTimeoutsKey)
    }

    /// Applies the extended-timeouts multiplier to a base duration
    /// (seconds). Pure function so the ×3 math is unit-testable without
    /// touching `UserDefaults` or SwiftUI.
    public static func applyExtendedTimeouts(_ enabled: Bool, to baseSeconds: Double) -> Double {
        enabled ? baseSeconds * extendedTimeoutsMultiplier : baseSeconds
    }

    // MARK: - Dwell activation

    /// iOS defers to the system's built-in Dwell Control (Settings →
    /// Accessibility → Switch Control → Dwell Control) rather than
    /// shipping a custom dwell engine — see spec §4. This preference
    /// only stores the user's intended threshold for a future
    /// guided-mode dwell implementation; it does not currently drive
    /// any live interaction.
    public static let dwellActivationEnabledKey = "sm.guided.dwellActivationEnabled"
    public static let dwellActivationEnabledDefault = false

    public static let dwellThresholdKey = "sm.guided.dwellThreshold"
    public static let dwellThresholdDefault: Double = 1.2
    public static let dwellThresholdRange: ClosedRange<Double> = 0.8...3.0

    public static func dwellActivationEnabled(from defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: dwellActivationEnabledKey) != nil else {
            return dwellActivationEnabledDefault
        }
        return defaults.bool(forKey: dwellActivationEnabledKey)
    }

    public static func dwellThreshold(from defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: dwellThresholdKey) != nil else {
            return dwellThresholdDefault
        }
        let value = defaults.double(forKey: dwellThresholdKey)
        return dwellThresholdRange.contains(value) ? value : dwellThresholdDefault
    }
}
