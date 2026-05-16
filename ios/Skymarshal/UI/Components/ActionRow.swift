// ActionRow.swift
//
// Full-width tappable action row. Use when a list of two or three
// actions deserves more touchable real-estate than a `Button` row in a
// `Menu` or a stack of `.bordered` buttons. Pattern adopted from the
// screenshat-ios "QPPill" idea (subtitle + busy state + leading symbol)
// but rendered in Skymarshal's spy-bird / scope idiom: 6pt corner
// radius (Theme.Radius.sm), Theme.scope-tinted fill on the primary
// emphasis, hairline stroke on neutral, and rounded display title +
// Plex Mono caption to match `SaturnButton` and `ScopePill`.
//
// Roles:
//   .scope        — primary scope-blue fill (export "Save", scan start)
//   .neutral      — paper-toned fill, hairline stroke (secondary actions)
//   .destructive  — danger-tinted hairline + danger label (logout, etc.)
//
// Busy: pass `isBusy = true` to swap the leading symbol for a
// `ProgressView` and disable the tap target. Use this while the action
// is preparing async work (encoding an export, downloading a ZIP, etc.).
//
// Inputs:   role, leading SF Symbol, title, optional caption, busy +
//           disabled flags, `action` closure.
// Outputs:  a `View` rendering a tappable card row.

import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct ActionRow: View {

    enum Role { case scope, neutral, destructive }

    let role: Role
    let systemImage: String
    let title: String
    let caption: String?
    var isBusy: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    init(
        role: Role = .neutral,
        systemImage: String,
        title: String,
        caption: String? = nil,
        isBusy: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.role = role
        self.systemImage = systemImage
        self.title = title
        self.caption = caption
        self.isBusy = isBusy
        self.isDisabled = isDisabled
        self.action = action
    }

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                leadingPuck
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.leading)
                    if let caption, !caption.isEmpty {
                        Text(caption)
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isBusy {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy || isDisabled)
        .opacity(isDisabled && !isBusy ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint(caption ?? "")
        .accessibilityAddTraits(isBusy ? .updatesFrequently : [])
    }

    @ViewBuilder
    private var leadingPuck: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(puckFill)
                .frame(width: 32, height: 32)
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(puckSymbol)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(puckSymbol)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Token routing

    private var fill: Color {
        switch role {
        case .scope:       return Theme.chipTint(Theme.scope)
        case .neutral:     return Color(.secondarySystemGroupedBackground)
        case .destructive: return Color(.secondarySystemGroupedBackground)
        }
    }

    private var stroke: Color {
        switch role {
        case .scope:       return Theme.scope.opacity(0.45)
        case .neutral:     return Color.primary.opacity(0.10)
        case .destructive: return Theme.danger.opacity(0.55)
        }
    }

    private var puckFill: Color {
        switch role {
        case .scope:       return Theme.scope.opacity(0.22)
        case .neutral:     return Color.primary.opacity(0.06)
        case .destructive: return Theme.chipTint(Theme.danger)
        }
    }

    private var puckSymbol: Color {
        switch role {
        case .scope:       return Theme.scope
        case .neutral:     return .primary
        case .destructive: return Theme.danger
        }
    }

    private var titleColor: Color {
        switch role {
        case .destructive: return Theme.danger
        default:           return .primary
        }
    }
}

@available(iOS 17, *)
#Preview("ActionRow — variants") {
    VStack(spacing: 10) {
        ActionRow(
            role: .scope,
            systemImage: "curlybraces",
            title: "Export as JSON",
            caption: "Pretty-printed, includes handle + DID"
        ) {}
        ActionRow(
            role: .neutral,
            systemImage: "tablecells",
            title: "Export as CSV",
            caption: "One row per item, RFC 4180"
        ) {}
        ActionRow(
            role: .scope,
            systemImage: "tray.and.arrow.down",
            title: "Apply to device archive",
            caption: "Preparing…",
            isBusy: true
        ) {}
        ActionRow(
            role: .destructive,
            systemImage: "trash",
            title: "Delete forever",
            caption: "Cannot be undone"
        ) {}
    }
    .padding(20)
}
