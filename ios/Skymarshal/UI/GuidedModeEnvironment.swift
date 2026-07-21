import SwiftUI
import SkymarshalCore

/// SwiftUI environment plumbing for Guided Mode Tier 1 settings
/// (`docs/GUIDED_MODE_SPEC.md` §4). Mirrors how `ReduceMotion` is
/// threaded: the pure enum/default logic lives in
/// `SkymarshalCore/Standards/GuidedModeSettings.swift`, and this file
/// is the thin SwiftUI-only layer that exposes it as
/// `@Environment(\.targetSizeFloor)` / `\.maxChoicesPerScreen`.
///
/// `RootView` (or any ancestor) sets these once near the root from the
/// `@AppStorage`-backed settings screen; any descendant view reads them
/// without needing its own `@AppStorage` wiring.
@available(iOS 17, *)
private struct TargetSizeFloorKey: EnvironmentKey {
    static let defaultValue: GuidedModeSettings.TargetSizeFloor = GuidedModeSettings.targetSizeFloorDefault
}

/// Not yet consumed by any guided flow (none exist yet in Tier 1) — the
/// value is here so filter surfaces and the future `GuidedShell` grid
/// can read `@Environment(\.maxChoicesPerScreen)` once they exist,
/// per spec §4/§5. Reserved, wired, unused by design.
@available(iOS 17, *)
private struct MaxChoicesPerScreenKey: EnvironmentKey {
    static let defaultValue: GuidedModeSettings.MaxChoicesPerScreen = GuidedModeSettings.maxChoicesPerScreenDefault
}

@available(iOS 17, *)
extension EnvironmentValues {
    var targetSizeFloor: GuidedModeSettings.TargetSizeFloor {
        get { self[TargetSizeFloorKey.self] }
        set { self[TargetSizeFloorKey.self] = newValue }
    }

    var maxChoicesPerScreen: GuidedModeSettings.MaxChoicesPerScreen {
        get { self[MaxChoicesPerScreenKey.self] }
        set { self[MaxChoicesPerScreenKey.self] = newValue }
    }
}

/// Applies the persisted Guided Mode settings to the environment for
/// everything beneath the receiver. Installed once at the app root
/// (`RootView`) so descendants read `@Environment(\.targetSizeFloor)`
/// etc. without re-reading `UserDefaults` themselves.
@available(iOS 17, *)
struct GuidedModeEnvironmentModifier: ViewModifier {
    @AppStorage(GuidedModeSettings.targetSizeFloorKey) private var targetSizeFloorRaw: String =
        GuidedModeSettings.targetSizeFloorDefault.rawValue
    @AppStorage(GuidedModeSettings.maxChoicesPerScreenKey) private var maxChoicesPerScreenRaw: String =
        GuidedModeSettings.maxChoicesPerScreenDefault.rawValue

    func body(content: Content) -> some View {
        content
            .environment(\.targetSizeFloor, GuidedModeSettings.TargetSizeFloor(rawValue: targetSizeFloorRaw) ?? GuidedModeSettings.targetSizeFloorDefault)
            .environment(\.maxChoicesPerScreen, GuidedModeSettings.MaxChoicesPerScreen(rawValue: maxChoicesPerScreenRaw) ?? GuidedModeSettings.maxChoicesPerScreenDefault)
    }
}

@available(iOS 17, *)
extension View {
    /// Threads the persisted Guided Mode Tier 1 settings into the
    /// environment for this view and its descendants. Call once, near
    /// the root (see `RootView`).
    func guidedModeEnvironment() -> some View {
        modifier(GuidedModeEnvironmentModifier())
    }
}
