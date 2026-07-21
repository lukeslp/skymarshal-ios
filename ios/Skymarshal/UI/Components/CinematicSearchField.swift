import SwiftUI
import SkymarshalCore

/// Make-parity elev2 search well (App.tsx Content / Patterns). Replaces
/// stock `.searchable` so the field stays on the void page chrome and
/// stays reachable next to Sort / Select (nav-drawer search collapses
/// those controls while focused).
@available(iOS 17, *)
struct CinematicSearchField: View {
    @Binding var text: String
    var prompt: String
    var onAdvanced: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
                .submitLabel(.search)
                .accessibilityLabel(prompt)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            if let onAdvanced {
                Button(action: onAdvanced) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Advanced filters")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, onAdvanced == nil ? 10 : 6)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.elev2)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Make Patterns sensitivity control — elev1 rail, elev2 active cell.
/// Each option carries a consequence line so "Strict vs Loose" is a
/// real choice, not a guess: shown visibly as a caption under the rail
/// for the active option, and spoken per option as a hint.
@available(iOS 17, *)
struct SensitivitySegmentedControl: View {
    @Binding var threshold: Double

    private let options: [(label: String, value: Double, consequence: String)] = [
        ("Strict", 0.8, "Flags fewer accounts; fewer mistakes"),
        ("Balanced", 0.6, "Balanced flagging"),
        ("Loose", 0.4, "Flags more accounts; may include real people"),
    ]

    private var activeConsequence: String? {
        options.first { abs(threshold - $0.value) < 0.05 }?.consequence
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                ForEach(options, id: \.value) { option in
                    let active = abs(threshold - option.value) < 0.05
                    Button {
                        threshold = option.value
                    } label: {
                        Text(option.label)
                            .font(.subheadline.weight(active ? .semibold : .regular))
                            .foregroundStyle(active ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .fill(active ? Theme.elev2 : Color.clear)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .strokeBorder(active ? Theme.hairlineMed : Color.clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.label) bot sensitivity")
                    .accessibilityHint(option.consequence)
                    .accessibilityAddTraits(active ? [.isSelected] : [])
                }
            }
            .padding(2)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.elev1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Bot sensitivity")

            if let activeConsequence {
                Text(activeConsequence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
        }
    }
}
