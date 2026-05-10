import SwiftUI
import SkymarshalCore

/// Horizontally-scrolling color-coded count pills above the
/// AccountRow list. Six categories: total / bots / inactive /
/// deleted / mutuals / bad ratio. Each pill's color matches the
/// AccountRow leading-stripe color for the same category — quiet
/// visual through-line.
@available(iOS 17, *)
struct ScanSummaryStrip: View {
    let summary: ScanSummary

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                stat("\(summary.totalAnalyzed.formatted())", "analyzed", .secondary)
                stat("\(summary.bots)", "bots", .red)
                stat("\(summary.inactive)", "inactive", .orange)
                stat("\(summary.deleted)", "deleted", .red)
                stat("\(summary.mutuals)", "mutuals", .accentColor)
                stat("\(summary.badRatio)", "bad ratio", .yellow)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
        .scrollClipDisabled()
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.10), in: .capsule)
    }
}
