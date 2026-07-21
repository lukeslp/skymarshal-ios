import SwiftUI
import SkymarshalCore

/// Guided Mode Tier 1 — the access settings screen (`docs/GUIDED_MODE_SPEC.md`
/// §4). Reached from About → Accessibility → Guided Mode. Every control here
/// is itself held to an exemplary accessibility standard: labeled Pickers,
/// Toggles, and a Slider with explicit VoiceOver hints, since this surface is
/// the one users open specifically to make the app work for their access
/// needs.
///
/// These settings are stored in `UserDefaults` under `GuidedModeSettings`'
/// keys and read app-wide via `@Environment(\.targetSizeFloor)` etc. (see
/// `GuidedModeEnvironment.swift`) and directly by `TypedConfirmSheet`.
@available(iOS 17, *)
struct GuidedModeSettingsView: View {
    @Environment(\.openURL) private var openURL

    @AppStorage(GuidedModeSettings.targetSizeFloorKey) private var targetSizeFloorRaw: String =
        GuidedModeSettings.targetSizeFloorDefault.rawValue
    @AppStorage(GuidedModeSettings.maxChoicesPerScreenKey) private var maxChoicesRaw: String =
        GuidedModeSettings.maxChoicesPerScreenDefault.rawValue
    @AppStorage(GuidedModeSettings.confirmationStyleKey) private var confirmationStyleRaw: String =
        GuidedModeSettings.confirmationStyleDefault.rawValue
    @AppStorage(GuidedModeSettings.extendedTimeoutsKey) private var extendedTimeouts: Bool =
        GuidedModeSettings.extendedTimeoutsDefault
    @AppStorage(GuidedModeSettings.dwellActivationEnabledKey) private var dwellEnabled: Bool =
        GuidedModeSettings.dwellActivationEnabledDefault
    @AppStorage(GuidedModeSettings.dwellThresholdKey) private var dwellThreshold: Double =
        GuidedModeSettings.dwellThresholdDefault

    // MARK: - Enum bindings (stored as raw strings)

    private var targetSizeFloor: Binding<GuidedModeSettings.TargetSizeFloor> {
        Binding(
            get: { GuidedModeSettings.TargetSizeFloor(rawValue: targetSizeFloorRaw) ?? GuidedModeSettings.targetSizeFloorDefault },
            set: { targetSizeFloorRaw = $0.rawValue }
        )
    }

    private var maxChoices: Binding<GuidedModeSettings.MaxChoicesPerScreen> {
        Binding(
            get: { GuidedModeSettings.MaxChoicesPerScreen(rawValue: maxChoicesRaw) ?? GuidedModeSettings.maxChoicesPerScreenDefault },
            set: { maxChoicesRaw = $0.rawValue }
        )
    }

    private var confirmationStyle: Binding<GuidedModeSettings.ConfirmationStyle> {
        Binding(
            get: { GuidedModeSettings.ConfirmationStyle(rawValue: confirmationStyleRaw) ?? GuidedModeSettings.confirmationStyleDefault },
            set: { confirmationStyleRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            targetsSection
            confirmationSection
            dwellSection
        }
        .cinematicListChrome()
        .navigationTitle("Guided Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Targets & layout

    private var targetsSection: some View {
        Section {
            Picker(selection: targetSizeFloor) {
                ForEach(GuidedModeSettings.TargetSizeFloor.allCases) { floor in
                    Text(floor.label).tag(floor)
                }
            } label: {
                Text("Minimum target size")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Sets the smallest tappable size for buttons and chips. Larger sizes are easier to hit with tremor, switch scanning, or dwell.")

            Picker(selection: maxChoices) {
                ForEach(GuidedModeSettings.MaxChoicesPerScreen.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            } label: {
                Text("Choices per screen")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Limits how many options guided screens present at once. Fewer choices lower reading and decision effort.")
        } header: {
            Text("Targets & layout")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        } footer: {
            Text("Larger targets apply now to buttons and chips across the app. The choices-per-screen limit shapes the step-by-step guided flows as they arrive.")
                .font(.caption2)
        }
    }

    // MARK: - Confirmation

    private var confirmationSection: some View {
        Section {
            Picker(selection: confirmationStyle) {
                ForEach(GuidedModeSettings.ConfirmationStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            } label: {
                Text("Confirm deletes with")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Chooses how large deletes are confirmed. Automatic offers the typed word and, with assistive technology on, a hold or two-step option. A specific choice pins that method.")

            Toggle(isOn: $extendedTimeouts) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Extended timeouts")
                        .font(.callout)
                    Text("Gives hold-to-confirm and two-step confirmations three times as long. No confirmation window closes quickly.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("When on, timed confirmations run three times longer")
        } header: {
            Text("Confirmations")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        } footer: {
            Text("Typing the word DELETE is always available. These options add ways to confirm large deletes without typing, and never remove the deliberate step that guards them.")
                .font(.caption2)
        }
    }

    // MARK: - Dwell

    private var dwellSection: some View {
        Section {
            Toggle(isOn: $dwellEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dwell activation")
                        .font(.callout)
                    Text("Remembers your preferred dwell time for guided screens. On iOS, dwell itself is provided by the system.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("When on, stores your dwell time preference")

            if dwellEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dwell time: \(dwellThreshold, format: .number.precision(.fractionLength(1))) seconds")
                        .font(.callout)
                    Slider(
                        value: $dwellThreshold,
                        in: GuidedModeSettings.dwellThresholdRange,
                        step: 0.1
                    )
                    .accessibilityLabel("Dwell time in seconds")
                    .accessibilityValue("\(dwellThreshold, format: .number.precision(.fractionLength(1))) seconds")
                    .accessibilityHint("How long to rest on a target before it activates")
                }
                .listRowBackground(Theme.elev1)
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Label("Open iOS Accessibility settings", systemImage: "arrow.up.forward.app")
                    .symbolRenderingMode(.monochrome)
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens Skymarshal's settings in the Settings app, where iOS Dwell Control lives under Accessibility")
        } header: {
            Text("Dwell")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        } footer: {
            Text("iOS provides dwell through Settings → Accessibility → Switch Control → Dwell Control, or through eye-tracking hardware. Turn it on there; Skymarshal's large targets are built to work with it.")
                .font(.caption2)
        }
    }
}

@available(iOS 17, *)
#Preview {
    NavigationStack {
        GuidedModeSettingsView()
    }
}
