// SaturnButton.swift
//
// Skymarshal's primary CTA button style — sharp 3pt corner radius,
// 1pt ink-toned border, paper-toned fill on idle, scope-blue tint on
// press. Replaces `.borderedProminent` on Sign in / Begin scan so
// those surfaces stop reading as generic iOS first-launch flows.
//
// Inputs:   SwiftUI `ButtonStyle.Configuration` (label + isPressed).
// Outputs:  a `View` rendering the configured button.
//
// **Token shim:** v1.0.1 references `Color(.systemBackground)` for fill
// and `Color.primary.opacity(0.32)` for the stroke. These are the
// placeholders until `Theme+Saturn.swift` ships paper / hairline tokens
// in v1.0.2. When v1.0.2 lands, swap the two lines flagged with
// `// v1.0.2 shim ↓`. Keep the comment until both are replaced.

import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
public struct SaturnButton: ButtonStyle {

    public enum Emphasis { case primary, ghost, destructive }

    public var emphasis: Emphasis = .primary

    public init(emphasis: Emphasis = .primary) {
        self.emphasis = emphasis
    }

    public func makeBody(configuration: Configuration) -> some View {
        SaturnButtonBody(configuration: configuration, emphasis: emphasis)
    }
}

@available(iOS 17, *)
private struct SaturnButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let emphasis: SaturnButton.Emphasis

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var fill: Color {
        if !isEnabled { return Color(.tertiarySystemBackground) }
        if configuration.isPressed {
            switch emphasis {
            case .primary:     return Theme.chipTint(Theme.scope)
            case .ghost:       return Theme.chipTint(Theme.scope).opacity(0.6)
            case .destructive: return Theme.chipTint(Theme.danger)
            }
        }
        // v1.0.2 shim ↓
        return emphasis == .ghost ? Color.clear : Color(.systemBackground)
    }

    private var stroke: Color {
        if !isEnabled { return Color.primary.opacity(0.18) }
        switch emphasis {
        case .primary:     return configuration.isPressed ? Theme.scope : Color.primary.opacity(0.32)
        case .ghost:       return configuration.isPressed ? Theme.scope : Color.primary.opacity(0.32)
        case .destructive: return Theme.danger
        }
    }

    private var textColor: Color {
        if !isEnabled { return .secondary }
        switch emphasis {
        case .primary:     return configuration.isPressed ? Theme.scope : .primary
        case .ghost:       return configuration.isPressed ? Theme.scope : .primary
        case .destructive: return Theme.danger
        }
    }

    private var reduceMotion: Bool {
        ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion)
    }

    var body: some View {
        configuration.label
            .font(Theme.Mono.body(15).weight(.medium))
            .tracking(0.6)
            .foregroundStyle(textColor)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isEnabled)
    }
}

@available(iOS 17, *)
#Preview("SaturnButton — states") {
    VStack(spacing: 16) {
        Button("Sign in") {}
            .buttonStyle(SaturnButton(emphasis: .primary))
        Button("Sign in") {}
            .buttonStyle(SaturnButton(emphasis: .primary))
            .disabled(true)
        Button("Cancel") {}
            .buttonStyle(SaturnButton(emphasis: .ghost))
        Button("Delete forever") {}
            .buttonStyle(SaturnButton(emphasis: .destructive))
    }
    .padding(24)
}
