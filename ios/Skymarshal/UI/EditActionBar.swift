import SwiftUI
import SkymarshalCore

/// Inline bulk-action bar shown above the list while EditMode is active.
///
/// Lives in the view hierarchy (NOT in `.toolbar`) so it stays visible
/// during search — when iOS focuses the .searchable field, the entire
/// navigation bar (and its toolbar items) collapses, and the bottom
/// toolbar gets occluded by the keyboard. Both placements are dead for
/// the search-then-bulk-act flow. An inline bar above the List is
/// reachable in all states.
@available(iOS 17, *)
struct EditActionBar: View {

    /// The destructive verb this bar carries. Content deletes posts
    /// (permanent); Followers unfollows accounts (reversible). Same bar,
    /// different stakes — the label, icon, and undo hint all follow from it.
    enum Action {
        case delete
        case unfollow

        var verb: String { self == .delete ? "Delete" : "Unfollow" }
        var icon: String { self == .delete ? "trash" : "person.crop.circle.badge.minus" }
        var noun: String { self == .delete ? "posts" : "accounts" }
        var undoHint: String? {
            self == .delete ? "This action cannot be undone" : nil
        }

        func accessibilityLabel(count: Int) -> String {
            count > 0
                ? "\(verb) \(count) selected \(noun)\(self == .delete ? " permanently" : "")"
                : "\(verb) (no selection)"
        }
    }

    let selectionCount: Int
    let visibleCount: Int
    let allSelected: Bool
    var action: Action = .delete
    let onToggleAll: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleAll) {
                HStack(spacing: 4) {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                        .font(.callout)
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.subheadline.weight(.medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(visibleCount == 0)

            Spacer(minLength: 8)

            if selectionCount > 0 {
                Text("\(selectionCount.formatted()) selected")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Spacer(minLength: 8)

            Button(role: .destructive, action: onDelete) {
                Label(action.verb, systemImage: action.icon)
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.danger)
            .disabled(selectionCount == 0)
            .accessibilityLabel(action.accessibilityLabel(count: selectionCount))
            .accessibilityHint(action.undoHint ?? "")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
        .animation(reduceMotion ? nil : .snappy, value: selectionCount)
        .animation(reduceMotion ? nil : .snappy, value: allSelected)
    }
}

@available(iOS 17, *)
#Preview("Empty") {
    EditActionBar(
        selectionCount: 0, visibleCount: 47, allSelected: false,
        onToggleAll: {}, onDelete: {}
    )
}

@available(iOS 17, *)
#Preview("With selection") {
    EditActionBar(
        selectionCount: 47, visibleCount: 47, allSelected: true,
        onToggleAll: {}, onDelete: {}
    )
}
