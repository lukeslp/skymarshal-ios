import SwiftUI

/// Thin status row above the list when there's cached data from a
/// previous session. Tells the user when the data was last refreshed
/// and gives them a one-tap Refresh affordance — the same job the
/// existing toolbar menu items do, but reachable inline so it's
/// visible whenever the cache is being shown.
@available(iOS 17, *)
struct LastScannedBanner: View {
    let lastScannedAt: Date
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Last scanned \(lastScannedAt, style: .relative) ago")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("Refresh", action: onRefresh)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .cinematicChromeStrip()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Showing cached data, last scanned \(lastScannedAt, style: .relative) ago")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Refresh", onRefresh)
    }
}
