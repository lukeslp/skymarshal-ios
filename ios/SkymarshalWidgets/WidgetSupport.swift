import WidgetKit
import SwiftUI
import SkymarshalCore

/// One timeline entry: the snapshot plus the render date. All five
/// widgets share this entry type — they differ only in which slice of
/// the snapshot they render.
struct SkymarshalEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// True when no real snapshot existed yet (first run / signed out).
    let isPlaceholder: Bool
}

/// Shared timeline provider. Reads the App Group snapshot the app wrote;
/// performs no network. Refreshes are driven by the app calling
/// `WidgetCenter.reloadAllTimelines()` after a scan, with a periodic
/// fallback reload so a stale "generated at" never lingers forever.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SkymarshalEntry {
        SkymarshalEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SkymarshalEntry) -> Void) {
        completion(currentEntry(isGallery: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkymarshalEntry>) -> Void) {
        let entry = currentEntry(isGallery: context.isPreview)
        // The app pushes fresh data via reloadAllTimelines after a scan.
        // A 6-hour refresh is just a backstop so relative dates re-render.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry(isGallery: Bool) -> SkymarshalEntry {
        if isGallery {
            return SkymarshalEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
        }
        if let snapshot = WidgetSnapshotStore.read() {
            return SkymarshalEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
        }
        return SkymarshalEntry(date: Date(), snapshot: .empty, isPlaceholder: true)
    }
}

// MARK: - Shared style helpers

/// Visual tokens matching the app: IBM Plex Mono via `Theme.Mono`, the
/// semantic `Theme` color set. Kept here so all five widget views read
/// the same vocabulary.
enum WidgetStyle {
    static let kicker = Theme.Mono.kicker(10)
    static let body = Theme.Mono.body(12)
    static let caption = Theme.Mono.caption(10)

    /// Big tabular number font, scaled per widget.
    static func metric(_ size: CGFloat) -> Font { Theme.Mono.tabular(size) }
}

/// A small label/value stat block used across the hygiene widgets.
struct WidgetStat: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(WidgetStyle.metric(18))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(WidgetStyle.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Section kicker (uppercase mono) used as a widget header.
struct WidgetKicker: View {
    let text: String
    var tint: Color = Theme.scope

    var body: some View {
        Text(text.uppercased())
            .font(WidgetStyle.kicker)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

extension Date {
    /// Compact relative string ("3h", "2d") for tight widget rows.
    var widgetRelative: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        return "\(days / 7)w"
    }
}
