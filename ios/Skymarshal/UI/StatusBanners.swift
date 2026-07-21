import SwiftUI
import SkymarshalCore

/// Two reusable status banners shown above lists during scans / loads.
///
/// `LoadProgressBannerLite` carries a free-form progress message with a
/// pulsing scope glyph + Stop button. (LoadProgressBanner, used by the
/// Content tab, is shaped for ContentService.LoadProgress with a phase
/// enum + items count — different contract.)
///
/// `ScanErrorBanner` surfaces failures inline with a dismissable red
/// triangle. The same component works for any error path; pass the
/// error message in directly.

@available(iOS 17, *)
struct LoadProgressBannerLite: View {
    let title: String
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating, value: pulse)
            Text(title)
                .font(Theme.Mono.body(13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("Stop", action: onCancel)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .cinematicChromeStrip()
        .onAppear { if !reduceMotion { pulse.toggle() } }
    }
}

/// Persistent, dismissible notice that a bulk delete may have been
/// interrupted before it finished. Replaces the earlier modal alert —
/// a banner stays readable at the user's pace instead of demanding an
/// immediate OK, and the explicit dismiss control still clears the
/// recovery breadcrumb exactly like the alert's OK did.
@available(iOS 17, *)
struct DeleteInterruptionBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.caution)
            VStack(alignment: .leading, spacing: 2) {
                Text("Interrupted delete")
                    .font(.footnote.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss interrupted delete notice")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.chipTint(Theme.caution))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
        .accessibilityElement(children: .contain)
    }
}

@available(iOS 17, *)
struct ScanErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't complete that")
                    .font(.footnote.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.chipTint(Theme.danger))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }
}
