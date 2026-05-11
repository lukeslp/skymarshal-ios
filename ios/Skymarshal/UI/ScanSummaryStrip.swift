import SwiftUI
import SkymarshalCore

/// Horizontally-scrolling color-coded count pills above the
/// AccountRow list. Six categories: total / bots / inactive /
/// deleted / mutuals / bad ratio. Each pill is **tap-to-filter** —
/// the canonical "show me only the bots and let me bulk-act" flow.
/// Tap an active pill again to clear that filter.
///
/// State binding: pills mutate the shared `FollowerFilters` struct
/// the BluescreenView holds. The same struct is also editable via
/// the full BluescreenFilterSheet — both UIs converge on a single
/// source of truth.
@available(iOS 17, *)
struct ScanSummaryStrip: View {
    let summary: ScanSummary
    @Binding var filters: FollowerFilters

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Total — display-only (no filter axis matches "all")
                Pill(
                    value: "\(summary.totalAnalyzed.formatted())",
                    label: "analyzed",
                    color: .secondary,
                    isActive: false,
                    onTap: nil
                )
                Pill(
                    value: "\(summary.bots)",
                    label: "bots",
                    color: Theme.danger,
                    isActive: filters.showBots,
                    onTap: { filters.showBots.toggle() }
                )
                Pill(
                    value: "\(summary.inactive)",
                    label: "inactive",
                    color: Theme.caution,
                    isActive: filters.showInactive,
                    onTap: { filters.showInactive.toggle() }
                )
                Pill(
                    value: "\(summary.deleted)",
                    label: "deleted",
                    color: Theme.danger,
                    isActive: filters.showDeleted,
                    onTap: { filters.showDeleted.toggle() }
                )
                Pill(
                    value: "\(summary.mutuals)",
                    label: "mutuals",
                    color: Theme.scope,
                    isActive: filters.showMutualOnly,
                    onTap: { filters.showMutualOnly.toggle() }
                )
                Pill(
                    value: "\(summary.badRatio)",
                    label: "bad ratio",
                    color: Theme.warn,
                    isActive: filters.showBadRatio,
                    onTap: { filters.showBadRatio.toggle() }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
        .scrollClipDisabled()
    }
}

/// Single count pill. Tap-to-filter when `onTap` is provided; pure
/// display when nil (used for the total-analyzed pill).
@available(iOS 17, *)
private struct Pill: View {
    let value: String
    let label: String
    let color: Color
    let isActive: Bool
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: { withAnimation(.snappy) { onTap() } }) {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityLabel(softLabel(for: label, value: value))
                .accessibilityHint(isActive ? "Active filter, tap to clear" : "Tap to filter")
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            } else {
                content
            }
        }
    }

    /// VoiceOver-facing label. The pill display label stays short for
    /// scanning ("bots"); the spoken label expands to a softer, less
    /// labeling phrase ("Likely automated accounts").
    private func softLabel(for label: String, value: String) -> String {
        switch label {
        case "bots":     return "Likely automated accounts, \(value)"
        case "deleted":  return "Deleted accounts, \(value)"
        case "inactive": return "Inactive accounts, \(value)"
        case "mutuals":  return "Mutual follows, \(value)"
        case "bad ratio": return "Unusual follower ratio, \(value)"
        case "analyzed": return "Total analyzed, \(value)"
        default:         return "\(label), \(value)"
        }
    }

    private var content: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(isActive ? .white : color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(isActive ? .white.opacity(0.85) : .secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            isActive
                ? AnyShapeStyle(color)
                : AnyShapeStyle(Theme.chipTint(color)),
            in: .capsule
        )
    }
}
