// SaturnButton.swift
//
// Skymarshal's primary CTA button style — radius-sm continuous corners,
// hairline border, elev1 fill on idle, scope-blue tint on press.
// Optional `.primaryCinematic` uses the OLED accent gradient for
// hero surfaces (Login / Patterns Begin scan).

import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
public struct SaturnButton: ButtonStyle {

    public enum Emphasis { case primary, primaryCinematic, ghost, destructive }

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
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var corner: CGFloat { Theme.Radius.sm }

    private var cinematicSolidForAccessibility: Bool {
        emphasis == .primaryCinematic && colorSchemeContrast == .increased
    }

    private var fill: Color {
        if !isEnabled { return Color(.tertiarySystemBackground) }
        if configuration.isPressed {
            switch emphasis {
            case .primary, .primaryCinematic:
                return Theme.chipTint(Theme.scope)
            case .ghost:
                return Theme.chipTint(Theme.scope).opacity(0.6)
            case .destructive:
                return Theme.chipTint(Theme.danger)
            }
        }
        // Primary idle fill is elev1 (Make cards), not systemBackground.
        return emphasis == .ghost ? Color.clear : Theme.elev1
    }

    private var stroke: Color {
        if !isEnabled { return Theme.hairlineMed }
        switch emphasis {
        case .primaryCinematic where !cinematicSolidForAccessibility:
            return Color.white.opacity(configuration.isPressed ? 0.55 : 0.38)
        case .primaryCinematic:
            return configuration.isPressed ? Theme.scope.opacity(0.85) : Theme.hairlineMed
        case .primary:
            return configuration.isPressed ? Theme.cinematicAccentA : Theme.hairlineMed
        case .ghost:
            return configuration.isPressed ? Theme.cinematicAccentA : Theme.hairlineMed
        case .destructive:
            return Theme.danger
        }
    }

    private var textColor: Color {
        if !isEnabled { return .secondary }
        switch emphasis {
        case .primaryCinematic:
            if cinematicSolidForAccessibility {
                return configuration.isPressed ? Theme.scope : .white
            }
            return .white
        case .primary:
            return configuration.isPressed ? Theme.scope : .primary
        case .ghost:
            return configuration.isPressed ? Theme.scope : .primary
        case .destructive:
            return Theme.danger
        }
    }

    private var labelFont: Font {
        .system(.body, design: .rounded, weight: .semibold)
    }

    private var tracking: CGFloat { 0.28 }

    private var reduceMotion: Bool {
        ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion)
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .tracking(tracking)
            .foregroundStyle(textColor)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(backgroundShapeStyle(configuration: configuration))
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isEnabled)
    }

    private func backgroundShapeStyle(configuration: ButtonStyle.Configuration) -> AnyShapeStyle {
        if emphasis == .primaryCinematic, isEnabled {
            if cinematicSolidForAccessibility {
                return AnyShapeStyle(configuration.isPressed ? Theme.chipTint(Theme.scope) : Theme.scope)
            }
            if configuration.isPressed {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Theme.cinematicAccentA.opacity(0.82),
                            Theme.cinematicAccentB.opacity(0.82),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            return AnyShapeStyle(Theme.cinematicTitleGradient)
        }
        return AnyShapeStyle(fill)
    }
}

@available(iOS 17, *)
#Preview("SaturnButton — states") {
    VStack(spacing: 16) {
        Button("Sign in") {}
            .buttonStyle(SaturnButton(emphasis: .primary))
        Button("Sign in") {}
            .buttonStyle(SaturnButton(emphasis: .primaryCinematic))
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
