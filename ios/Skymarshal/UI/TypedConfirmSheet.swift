import SwiftUI
import SkymarshalCore

/// Bulk-delete intent gate for batches ≥ 100. Visual language matches the
/// Figma Make "Delete Review" sheet: scope lock, estimate, typed confirm.
/// Intent word remains uppercase `DELETE` (safer than Make's lowercase).
///
/// `confirmationDialog` is still used for batches < 100 — the friction
/// here is reserved for true bulk operations where the cost of an
/// accidental tap is on the order of "deleted a thousand posts."
@available(iOS 17, *)
struct TypedConfirmSheet: View {
    let count: Int
    var preflight: DeletePreflightSummary?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typed: String = ""
    @FocusState private var fieldFocused: Bool
    @Environment(AppModel.self) private var model

    private static let requiredWord = "DELETE"

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
                    deleteButton
                }
                .padding(20)
            }
            .cinematicListChrome()
            .navigationTitle("Delete Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityHint("Cancels this deletion and dismisses the sheet")
                }
            }
            .onAppear { fieldFocused = true }
        }
        .interactiveDismissDisabled()
        .cinematicSheetChrome()
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

    private var deleteButton: some View {
        Button(action: onConfirm) {
            Label("Delete \(effectiveCount) record\(effectiveCount == 1 ? "" : "s")", systemImage: "trash")
                .font(.system(.body, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(SaturnButton(emphasis: .destructive))
        .disabled(!enabled)
        .accessibilityLabel("Delete \(effectiveCount) records permanently")
        .accessibilityHint("This action cannot be undone")
        .padding(.top, 4)
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
