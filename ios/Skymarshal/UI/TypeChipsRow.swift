import SwiftUI
import SkymarshalCore

/// Horizontal pill-chip row for content-type selection. Replaces the
/// 5-segment .pickerStyle(.segmented) which couldn't share a row with
/// other controls and didn't have space for category counts.
///
/// Lifted from skymarshal-web's ContentManagement.tsx pattern:
/// `border-primary bg-primary/10 text-primary` on the active chip,
/// `(N)` count badge after the label. Each chip uses its content
/// type's stripeColor (Posts=blue, Replies=cyan, Reposts=green,
/// Likes=pink) so the active state nods at the row stripes below —
/// quiet through-line, not a coordinated theme park.
@available(iOS 17, *)
struct TypeChipsRow: View {
    @Binding var scope: ContentType
    let counts: [ContentType: Int]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ContentType.allCases) { type in
                    TypeChip(
                        type: type,
                        count: count(for: type),
                        isActive: scope == type,
                        action: {
                            if reduceMotion {
                                scope = type
                            } else {
                                withAnimation(.snappy) { scope = type }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.sfSymbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? type.stripeColor : .secondary)
                Text(type.label)
                    .font(.subheadline.weight(.medium))
                if count > 0 {
                    Text(count.formatted())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isActive ? AnyShapeStyle(type.stripeColor) : AnyShapeStyle(.tertiary))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(
                    isActive ? AnyShapeStyle(type.stripeColor.opacity(0.12))
                             : AnyShapeStyle(Color(.tertiarySystemFill))
                )
            }
            .overlay {
                Capsule().strokeBorder(
                    isActive ? type.stripeColor.opacity(0.55) : .clear,
                    lineWidth: 1
                )
            }
            .foregroundStyle(isActive ? type.stripeColor : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.label), \(count.formatted()) item\(count == 1 ? "" : "s")")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

@available(iOS 17, *)
#Preview {
    VStack {
        StatefulPreviewWrapper(ContentType.all) { binding in
            TypeChipsRow(
                scope: binding,
                counts: [.posts: 9_832, .replies: 856, .reposts: 47, .likes: 339]
            )
        }
        Spacer()
    }
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
