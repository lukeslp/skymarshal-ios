// StatusLine.swift
//
// Single-line inline status: dot + title + trailing meta + optional
// subtitle. Use to surface progress / success / warning / error
// feedback inline with the surface that owns it (an export sheet, a
// scan strip, a backup-import card) — instead of routing through an
// `.alert` for routine outcomes. Pattern adopted from the screenshat-ios
// "QPStatusLine" but rendered with Skymarshal's Theme tokens, Plex
// Mono caption typography, and OLED-tuned dot colors.
//
// `StatusBanners.swift`'s `LoadProgressBannerLite` / `ScanErrorBanner`
// are higher-level shells with cancel / dismiss buttons; StatusLine is
// the lower-level building block. Use StatusLine for "the data of the
// status" (progress, success, error message) and the banners when you
// also need a control affordance.
//
// Inputs:   style, title, optional meta, optional subtitle.
// Outputs:  a `View` rendering a left-aligned status row.

import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct StatusLine: View {

    enum Style {
        case neutral
        case progress
        case success
        case warning
        case danger
    }

    let style: Style
    let title: String
    let meta: String?
    let subtitle: String?

    init(style: Style, title: String, meta: String? = nil, subtitle: String? = nil) {
        self.style = style
        self.title = title
        self.meta = meta
        self.subtitle = subtitle
    }

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                dot
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 6)
                if let meta, !meta.isEmpty {
                    Text(meta)
                        .font(Theme.Mono.tabular(11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(style == .progress ? .updatesFrequently : [])
    }

    @ViewBuilder
    private var dot: some View {
        switch style {
        case .progress:
            // Tiny inline progress puck — pulses with .updatesFrequently
            // accessibility trait so VoiceOver re-reads on change.
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .symbolEffect(
                    .pulse,
                    options: reduceMotion ? .nonRepeating : .repeating,
                    value: title
                )
                .accessibilityHidden(true)
        default:
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
    }

    private var dotColor: Color {
        switch style {
        case .neutral:  return Color.secondary.opacity(0.6)
        case .progress: return Theme.scope
        case .success:  return Theme.success
        case .warning:  return Theme.warn
        case .danger:   return Theme.danger
        }
    }

    private var accessibilityLabelText: String {
        var parts = [title]
        if let meta, !meta.isEmpty { parts.append(meta) }
        if let subtitle, !subtitle.isEmpty { parts.append(subtitle) }
        return parts.joined(separator: ". ")
    }
}

@available(iOS 17, *)
#Preview("StatusLine — styles") {
    VStack(alignment: .leading, spacing: 14) {
        StatusLine(style: .neutral, title: "Idle", meta: "—", subtitle: "Pick a format above to begin.")
        StatusLine(style: .progress, title: "Encoding", meta: "12k items", subtitle: "Building JSON envelope…")
        StatusLine(style: .success, title: "Ready", meta: "1.2 MB", subtitle: "Tap Share to hand off.")
        StatusLine(style: .warning, title: "Partial", subtitle: "Some entries skipped.")
        StatusLine(style: .danger, title: "Encode failed", subtitle: "JSONEncoder threw on item 47.")
    }
    .padding(20)
}
