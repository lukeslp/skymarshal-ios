import SwiftUI
import SkymarshalCore

/// Bulk-delete intent gate for batches ≥ 100. Mirrors GitHub's
/// repo-deletion pattern: user must type the exact word "DELETE" before
/// the destructive button enables. Switch Control + dwell users get an
/// unambiguous intent step that `confirmationDialog` alone can't
/// provide because dwell can land on the destructive button by
/// accident.
///
/// `confirmationDialog` is still used for batches < 100 — the friction
/// here is reserved for true bulk operations where the cost of an
/// accidental tap is on the order of "deleted a thousand posts."
@available(iOS 17, *)
struct TypedConfirmSheet: View {
    let count: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typed: String = ""
    @FocusState private var fieldFocused: Bool

    private static let requiredWord = "DELETE"

    private var enabled: Bool {
        typed == Self.requiredWord
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(count) posts will be permanently deleted from Bluesky.")
                            .font(.body)
                        Text("This action cannot be undone. Deleted posts cannot be recovered, and the bsky.social rate limit means this batch will take several minutes to complete.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Confirm bulk deletion")
                        .font(.subheadline.weight(.semibold))
                        .tracking(0.3)
                }

                Section {
                    TextField("Type DELETE", text: $typed)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .accessibilityLabel("Confirmation phrase")
                        .accessibilityHint("Type the word DELETE to enable the destructive action")
                } footer: {
                    Text("Typing the word above proves this is intentional. The Delete button stays disabled until the match is exact.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive, action: onConfirm) {
                        Label("Delete \(count) posts permanently", systemImage: "trash")
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.danger)
                    .disabled(!enabled)
                    .accessibilityLabel("Delete \(count) posts permanently")
                    .accessibilityHint("This action cannot be undone")
                }
            }
            .navigationTitle("Bulk delete")
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
    }
}

@available(iOS 17, *)
#Preview("Big batch") {
    TypedConfirmSheet(count: 1_247, onConfirm: {}, onCancel: {})
}

@available(iOS 17, *)
#Preview("Just over threshold") {
    TypedConfirmSheet(count: 100, onConfirm: {}, onCancel: {})
}
