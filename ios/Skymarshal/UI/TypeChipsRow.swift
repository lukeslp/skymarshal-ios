import SwiftUI
import SkymarshalCore

/// Horizontal type-chip row for content-type selection. Figma Make chip
/// language: radius-sm, hairline border, accent wash when active — not
/// Capsule / tertiarySystemFill.
///
/// Multi-select: each of the four concrete types (Posts, Replies, Reposts,
/// Likes) is an independent toggle, and a leading "All" chip selects every
/// type at once. The default selection (Posts + Replies) lives in the
/// owning view — most archives are mostly likes, and likes are the thing
/// people least want to wade through on landing.
@available(iOS 17, *)
struct TypeChipsRow: View {
    @Binding var selected: Set<ContentType>
    let counts: [ContentType: Int]

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    private var allSelected: Bool {
        selected.isSuperset(of: ContentType.selectable)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TypeChip(
                    type: .all,
                    count: count(for: .all),
                    isActive: allSelected,
                    action: { mutate { selected = Set(ContentType.selectable) } }
                )

                ForEach(ContentType.selectable) { type in
                    TypeChip(
                        type: type,
                        count: count(for: type),
                        isActive: selected.contains(type),
                        action: { mutate { toggle(type) } }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .contentMargins(.trailing, 24, for: .scrollContent)
    }

    /// Toggle one type, keeping at least one selected — an empty set would
    /// show an empty list with no chip to explain why.
    private func toggle(_ type: ContentType) {
        if selected.contains(type) {
            if selected.count > 1 { selected.remove(type) }
        } else {
            selected.insert(type)
        }
    }

    private func mutate(_ change: () -> Void) {
        if reduceMotion { change() } else { withAnimation(.snappy, change) }
    }

    private func count(for type: ContentType) -> Int {
        if type == .all {
            return counts.values.reduce(0, +)
        }
        return counts[type] ?? 0
    }
}

@available(iOS 17, *)
private struct TypeChip: View {
    let type: ContentType
    let count: Int
    let isActive: Bool
    let action: () -> Void

    @Environment(\.targetSizeFloor) private var targetSizeFloor

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.sfSymbol)
                    .font(.caption2.weight(.semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isActive ? type.stripeColor : .secondary)
                Text(type.label)
                    .font(Theme.Mono.body(12))
                    .fontWeight(.semibold)
                if count > 0 {
                    Text(count.formatted())
                        .font(Theme.Mono.tabular(11))
                        .foregroundStyle(isActive ? AnyShapeStyle(type.stripeColor) : AnyShapeStyle(.tertiary))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(isActive ? type.stripeColor.opacity(0.14) : Theme.elev2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(
                        isActive ? type.stripeColor.opacity(0.55) : Theme.hairline,
                        lineWidth: 1
                    )
            }
            .foregroundStyle(isActive ? type.stripeColor : .secondary)
            // Visual chip stays compact; the frame + contentShape extend
            // the hit area to the HIG floor (pattern: AccountRow), now
            // driven by the user's Guided Mode target-size-floor
            // preference (Standard 44 / Large 60 / Max 88 — see
            // GuidedModeSettings.TargetSizeFloor) instead of a hardcoded
            // 44pt.
            .frame(minHeight: targetSizeFloor.points)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.label), \(count.formatted()) item\(count == 1 ? "" : "s")")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

@available(iOS 17, *)
#Preview {
    VStack {
        StatefulPreviewWrapper([.posts, .replies] as Set<ContentType>) { binding in
            TypeChipsRow(
                selected: binding,
                counts: [.posts: 9_832, .replies: 856, .reposts: 47, .likes: 339]
            )
        }
        Spacer()
    }
    .background(Theme.void)
}

@available(iOS 17, *)
private struct StatefulPreviewWrapper<T, Content: View>: View {
    @State private var value: T
    let content: (Binding<T>) -> Content

    init(_ initial: T, @ViewBuilder content: @escaping (Binding<T>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
