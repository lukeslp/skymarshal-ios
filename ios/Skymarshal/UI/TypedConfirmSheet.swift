import SwiftUI
import UIKit
import Combine
import SkymarshalCore

/// Bulk-delete intent gate for batches ≥ 100. Visual language matches the
/// Figma Make "Delete Review" sheet: scope lock, estimate, typed confirm.
/// Intent word remains uppercase `DELETE` (safer than Make's lowercase).
///
/// `confirmationDialog` is still used for batches < 100 — the friction
/// here is reserved for true bulk operations where the cost of an
/// accidental tap is on the order of "deleted a thousand posts."
///
/// Accessibility: typing DELETE is the only path when no assistive
/// technology is running. When VoiceOver, Switch Control, or
/// AssistiveTouch is active, a "Hold to confirm" alternative appears —
/// a continuous 3-second press-and-hold, or (via accessibility action,
/// for users who cannot perform a timed hold) a two-step activate/
/// re-activate confirm with a 10-second window. Every path preserves
/// deliberate friction; nothing confirms on a single activation.
@available(iOS 17, *)
struct TypedConfirmSheet: View {
    let count: Int
    var preflight: DeletePreflightSummary?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typed: String = ""
    @FocusState private var fieldFocused: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// Guided Mode Tier 1 overrides (`GuidedModeSettings`, spec §4).
    /// `.automatic` preserves the pre-existing AT-detection behavior
    /// below unchanged; any other value pins the sheet to that single
    /// confirmation mechanism regardless of assistive-tech status.
    @AppStorage(GuidedModeSettings.confirmationStyleKey) private var confirmationStyleRaw: String =
        GuidedModeSettings.confirmationStyleDefault.rawValue
    /// When on, the hold duration and two-step arm window run at 3x
    /// their base length (spec §4: "arming windows ×3, no short-lived
    /// UI").
    @AppStorage(GuidedModeSettings.extendedTimeoutsKey) private var extendedTimeoutsEnabled: Bool =
        GuidedModeSettings.extendedTimeoutsDefault

    /// Assistive-tech presence — seeded at init, kept fresh via the
    /// UIAccessibility status-change notifications below.
    @State private var assistiveTechActive: Bool = TypedConfirmSheet.assistiveTechRunning

    /// Two-step arm/confirm machine for the accessibility-action path.
    /// Re-created in `.onAppear` once `armWindowSeconds` (which depends
    /// on the extended-timeouts preference) is available.
    @State private var arming = TwoStepConfirmArming()
    @State private var armed = false
    @State private var disarmTask: Task<Void, Never>?

    /// Press-and-hold progress (0…1) for the visible hold path.
    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdConfirmed = false
    @State private var holdTask: Task<Void, Never>?

    private static let requiredWord = "DELETE"
    private static let baseHoldSeconds: Double = 3
    private static let baseArmWindowSeconds: Double = 10

    private static var assistiveTechRunning: Bool {
        UIAccessibility.isVoiceOverRunning
            || UIAccessibility.isSwitchControlRunning
            || UIAccessibility.isAssistiveTouchRunning
    }

    private var reduceMotion: Bool {
        ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion)
    }

    private var confirmationStyle: GuidedModeSettings.ConfirmationStyle {
        GuidedModeSettings.ConfirmationStyle(rawValue: confirmationStyleRaw) ?? .automatic
    }

    /// Extended-timeouts-adjusted durations. Plain `Double`s (not
    /// `static let`s) because they depend on the `@AppStorage` value.
    private var holdSeconds: Double {
        GuidedModeSettings.applyExtendedTimeouts(extendedTimeoutsEnabled, to: Self.baseHoldSeconds)
    }
    private var armWindowSeconds: Double {
        GuidedModeSettings.applyExtendedTimeouts(extendedTimeoutsEnabled, to: Self.baseArmWindowSeconds)
    }

    /// Whether the non-typing alternative (hold / two-step) section is
    /// offered. `.automatic` preserves the original AT-detection gate;
    /// an explicit `.typed` override hides it even under active AT;
    /// an explicit `.twoStep`/`.hold` override shows it even without AT.
    private var showAlternateConfirmSection: Bool {
        switch confirmationStyle {
        case .automatic: return assistiveTechActive
        case .typed: return false
        case .twoStep, .hold: return true
        }
    }

    private var effectiveCount: Int {
        preflight?.totalCount ?? count
    }

    private var enabled: Bool {
        typed == Self.requiredWord
    }

    private var scopeHandle: String {
        model.currentHandle.map { "@\($0)" } ?? "signed-in account"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    scopeLockCard
                    estimateCard
                    riskFlags
                    confirmField
                    if showAlternateConfirmSection {
                        holdToConfirmSection
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) { actionBar }
            .cinematicListChrome()
            .navigationTitle("Delete Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityHint("Cancels this deletion and dismisses the sheet")
                }
            }
            .onAppear {
                fieldFocused = true
                // Build the two-step machine with the extended-timeouts-
                // adjusted window so the machine's own `isArmed` window
                // and the visual disarm task agree (spec §4 ×3).
                arming = TwoStepConfirmArming(windowSeconds: armWindowSeconds)
            }
        }
        .interactiveDismissDisabled()
        .cinematicSheetChrome()
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.voiceOverStatusDidChangeNotification
        )) { _ in refreshAssistiveTechStatus() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.switchControlStatusDidChangeNotification
        )) { _ in refreshAssistiveTechStatus() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.assistiveTouchStatusDidChangeNotification
        )) { _ in refreshAssistiveTechStatus() }
        .onDisappear {
            disarmTask?.cancel()
            holdTask?.cancel()
        }
    }

    /// Full-size Cancel + Delete pair, pinned below the scroll content
    /// so both are visible and ≥ 44pt without any scrolling.
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(SaturnButton(emphasis: .ghost))
            .accessibilityHint("Cancels this deletion and dismisses the sheet")

            Button(action: onConfirm) {
                Label("Delete \(effectiveCount) record\(effectiveCount == 1 ? "" : "s")", systemImage: "trash")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(SaturnButton(emphasis: .destructive))
            .disabled(!enabled)
            .accessibilityLabel("Delete \(effectiveCount) records permanently")
            .accessibilityHint("This action cannot be undone")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var scopeLockCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.danger)
                    .frame(width: 6, height: 6)
                Text("Scope lock · \(scopeHandle)")
                    .font(Theme.Mono.kicker())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text("\(effectiveCount)")
                .font(Theme.Mono.tabular(28))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text("records selected")
                .font(Theme.Mono.caption())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if count > effectiveCount {
                Text("\(count) item(s) selected; \(count - effectiveCount) cannot be deleted from this archive.")
                    .font(.caption)
                    .foregroundStyle(Theme.caution)
            }
            if let preflight, !preflight.resolutionErrors.isEmpty {
                Text("\(preflight.resolutionErrors.count) selection(s) skipped (no deletable URI).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.elev2)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }

    private var estimateCard: some View {
        Text("This action cannot be undone. At Bluesky's rate limits, this batch takes \(DeletePacing.formattedEstimate(for: effectiveCount)) at minimum — keep Skymarshal open and your device awake. You can stop partway; finished deletions stay deleted.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.elev1)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    }
            }
    }

    private var riskFlags: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Risk flags")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Label("Permanent Bluesky deletes — not recoverable", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Theme.caution)
                .symbolRenderingMode(.monochrome)
            if effectiveCount >= 1_000 {
                Label("Large batch — plan for a long open session", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.caution)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.elev1)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
    }

    private var confirmField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type \(Self.requiredWord) to confirm")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(Self.requiredWord, text: $typed)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .font(Theme.Mono.body(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.elev2)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .strokeBorder(enabled ? Theme.danger : Theme.hairline, lineWidth: 1)
                        }
                }
                .accessibilityLabel("Confirmation phrase")
                .accessibilityHint("Type the word DELETE to enable the destructive action")
        }
    }

    // MARK: - Hold-to-confirm (assistive tech only)

    /// Non-typing confirmation path, shown only while VoiceOver, Switch
    /// Control, or AssistiveTouch is running. Touch users hold for a
    /// continuous 3 seconds; the accessibility action path is a
    /// two-step arm/confirm for users who cannot perform a timed hold.
    private var holdToConfirmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or confirm without typing")
                .font(.caption)
                .foregroundStyle(.secondary)
            holdButton
            Text(
                armed
                    ? "Armed. Activate again within \(Int(armWindowSeconds)) seconds to delete."
                    : "Press and hold for \(Int(holdSeconds)) seconds. With Switch Control, activate once to arm, then activate again within \(Int(armWindowSeconds)) seconds."
            )
            .font(.caption)
            .foregroundStyle(armed ? Theme.danger : .secondary)
        }
    }

    private var holdButton: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.elev1)
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.chipTint(Theme.danger))
                        .frame(width: proxy.size.width * holdProgress)
                }
            }
            Label(
                isHolding ? "Keep holding…" : "Hold to confirm delete",
                systemImage: "hand.tap"
            )
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.danger)
            .symbolRenderingMode(.monochrome)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .frame(height: 48)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Theme.danger, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .onLongPressGesture(
            minimumDuration: holdSeconds,
            maximumDistance: 60
        ) {
            completeHold()
        } onPressingChanged: { pressing in
            if pressing { beginHold() } else { cancelHold() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            armed
                ? "Armed. Activate again to delete \(effectiveCount) records."
                : "Confirm delete without typing"
        )
        .accessibilityHint("Two steps: first activation arms, second activation within \(Int(armWindowSeconds)) seconds deletes. This cannot be undone.")
        .accessibilityAction { twoStepActivate() }
        .accessibilityAction(named: Text(armed ? "Confirm deletion" : "Arm deletion")) {
            twoStepActivate()
        }
    }

    private func refreshAssistiveTechStatus() {
        assistiveTechActive = Self.assistiveTechRunning
        if !assistiveTechActive {
            disarmTask?.cancel()
            arming.reset()
            armed = false
            cancelHold()
        }
    }

    private func beginHold() {
        guard !holdConfirmed else { return }
        isHolding = true
        holdTask?.cancel()
        if reduceMotion {
            // No continuous animation — step the progress fill in six
            // discrete increments so the affordance still communicates.
            holdProgress = 0
            holdTask = Task { @MainActor in
                for step in 1...6 {
                    try? await Task.sleep(nanoseconds: UInt64(holdSeconds / 6 * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    holdProgress = Double(step) / 6
                }
            }
        } else {
            holdProgress = 0
            withAnimation(.linear(duration: holdSeconds)) {
                holdProgress = 1
            }
        }
    }

    private func cancelHold() {
        guard !holdConfirmed else { return }
        holdTask?.cancel()
        isHolding = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { holdProgress = 0 }
    }

    private func completeHold() {
        guard !holdConfirmed else { return }
        holdConfirmed = true
        holdTask?.cancel()
        isHolding = false
        holdProgress = 1
        UIAccessibility.post(
            notification: .announcement,
            argument: "Deletion confirmed. Deleting \(effectiveCount) records."
        )
        onConfirm()
    }

    /// Accessibility-action path: two activations, no timed hold.
    private func twoStepActivate() {
        switch arming.activate() {
        case .armed:
            armed = true
            UIAccessibility.post(
                notification: .announcement,
                argument: "Armed. Activate again within \(Int(armWindowSeconds)) seconds to confirm deleting \(effectiveCount) records."
            )
            disarmTask?.cancel()
            disarmTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(armWindowSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                arming.reset()
                armed = false
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Confirmation window expired. Nothing was deleted."
                )
            }
        case .confirmed:
            disarmTask?.cancel()
            armed = false
            UIAccessibility.post(
                notification: .announcement,
                argument: "Deletion confirmed. Deleting \(effectiveCount) records."
            )
            onConfirm()
        }
    }
}

@available(iOS 17, *)
#Preview("Big batch") {
    TypedConfirmSheet(count: 1_247, preflight: nil, onConfirm: {}, onCancel: {})
        .environment(AppModel.liveDefault())
}

@available(iOS 17, *)
#Preview("Just over threshold") {
    TypedConfirmSheet(count: 100, preflight: nil, onConfirm: {}, onCancel: {})
        .environment(AppModel.liveDefault())
}
