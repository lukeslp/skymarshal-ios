// ScopePill.swift
//
// Operational status chip. Replaces the system-styled "Unknown" /
// "Partial" capsules on the Scope tab and the `BotScoreBadge` capsule
// on `AccountRow`. Plex Mono SemiBold caps text, Theme.chipTint(...)
// background keyed by emphasis, sharp 3pt corner radius — the
// silhouette change that separates Skymarshal from Settings.app.
//
// Inputs:   `value` (required), optional `label`, `emphasis` color
//           routing, optional leading SF Symbol.
// Outputs:  a `View` that paints a 3pt-radius rectangular chip and
//           supplies a sensible default `accessibilityLabel`.

import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
public struct ScopePill: View {

    public enum Emphasis {
        case muted, scope, danger, caution, success, info

        @available(iOS 17, *)
        var foreground: Color {
            switch self {
            case .muted:   return .secondary
            case .scope:   return Theme.scope
            case .danger:  return Theme.danger
            case .caution: return Theme.caution
            case .success: return Theme.success
            case .info:    return Theme.info
            }
        }

        @available(iOS 17, *)
        var background: Color {
            switch self {
            case .muted:   return Theme.chipTint(.gray)
            case .scope:   return Theme.chipTint(Theme.scope)
            case .danger:  return Theme.chipTint(Theme.danger)
            case .caution: return Theme.chipTint(Theme.caution)
            case .success: return Theme.chipTint(Theme.success)
            case .info:    return Theme.chipTint(Theme.info)
            }
        }
    }

    public let value: String
    public let label: String?
    public let emphasis: Emphasis
    public let leading: Image?

    public init(
        value: String,
        label: String? = nil,
        emphasis: Emphasis = .muted,
        leading: Image? = nil
    ) {
        self.value = value
        self.label = label
        self.emphasis = emphasis
        self.leading = leading
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let leading {
                leading
                    .font(Theme.Mono.kicker(11))
                    .symbolRenderingMode(.monochrome)
            }
            Text(value.uppercased())
                .font(Theme.Mono.kicker(11))
                .tracking(0.15)
        }
        .foregroundStyle(emphasis.foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(emphasis.background)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(defaultAccessibilityLabel)
    }

    private var defaultAccessibilityLabel: String {
        if let label, !label.isEmpty { return "\(label) \(value)" }
        return value
    }
}

@available(iOS 17, *)
#Preview("ScopePill — emphases") {
    VStack(alignment: .leading, spacing: 8) {
        ScopePill(value: "Unknown")
        ScopePill(value: "Partial", emphasis: .scope)
        ScopePill(value: "12", label: "automation signals",
                  emphasis: .caution,
                  leading: Image(systemName: "ant.fill"))
        ScopePill(value: "Healthy", emphasis: .success)
        ScopePill(value: "Risk", emphasis: .danger)
    }
    .padding(24)
}
