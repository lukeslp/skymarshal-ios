import SwiftUI
import SkymarshalCore

/// A thin status bar shown above the list while ``ContentService`` is
/// paginating. Per the council verdict (consensus + elegance, both
/// converged): users with thousands of posts must see "Loaded N • still
/// scanning" instead of a frozen spinner, with a Stop button if they
/// want to act on what's already loaded.
@available(iOS 17, *)
struct LoadProgressBanner: View {

    let progress: ContentService.LoadProgress
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Loaded \(progress.itemsLoaded.formatted()) • scanning \(progress.phase.rawValue.lowercased())…")
                    .font(.footnote)
                Text("Filters and search work on what's loaded so far.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Stop") { onCancel() }
                .font(.footnote.weight(.medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading content. \(progress.itemsLoaded.formatted()) items loaded so far.")
    }
}

@available(iOS 17, *)
#Preview {
    VStack {
        LoadProgressBanner(
            progress: .init(phase: .posts, itemsLoaded: 1247, pagesFetched: 13, isComplete: false),
            onCancel: {}
        )
        Spacer()
    }
}
