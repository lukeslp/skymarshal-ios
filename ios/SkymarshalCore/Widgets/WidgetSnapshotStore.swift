import Foundation

/// Reads and writes the ``WidgetSnapshot`` as JSON inside the shared App
/// Group container. The main app writes after a scan; the widget
/// extension reads in its timeline provider. No network, no UserDefaults
/// size limits — a flat JSON file in the group container.
public enum WidgetSnapshotStore {

    /// File name inside the App Group container.
    private static let fileName = "widget-snapshot.json"

    /// Resolves the App Group container URL. Returns `nil` when the
    /// entitlement is missing (e.g. a build without the App Group), which
    /// lets both sides degrade to placeholder content instead of crashing.
    public static func containerURL(
        groupIdentifier: String = WidgetSnapshot.appGroupIdentifier
    ) -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        )
    }

    private static func fileURL(
        groupIdentifier: String = WidgetSnapshot.appGroupIdentifier
    ) -> URL? {
        containerURL(groupIdentifier: groupIdentifier)?
            .appendingPathComponent(fileName, conformingTo: .json)
    }

    // Dates use the default `.deferredToDate` strategy (a lossless
    // Double of secondsSinceReferenceDate). ISO8601 would silently drop
    // sub-second precision and break exact `Date` round-trips — the
    // widget never displays raw timestamps, only relative strings, so a
    // compact lossless number is the right trade.
    private static func makeEncoder() -> JSONEncoder { JSONEncoder() }
    private static func makeDecoder() -> JSONDecoder { JSONDecoder() }

    /// Persist a snapshot. Returns `false` if the container is
    /// unavailable or the write fails — callers may log but should not
    /// treat a widget write failure as fatal.
    @discardableResult
    public static func write(
        _ snapshot: WidgetSnapshot,
        groupIdentifier: String = WidgetSnapshot.appGroupIdentifier
    ) -> Bool {
        guard let url = fileURL(groupIdentifier: groupIdentifier) else { return false }
        do {
            let data = try makeEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    /// Load the most recently written snapshot, or `nil` if none exists
    /// yet (or the container is unavailable / the file is corrupt).
    public static func read(
        groupIdentifier: String = WidgetSnapshot.appGroupIdentifier
    ) -> WidgetSnapshot? {
        guard
            let url = fileURL(groupIdentifier: groupIdentifier),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? makeDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Round-trip helper exposed for unit tests: encode then decode a
    /// snapshot through the same coders the store uses, without touching
    /// the filesystem.
    public static func roundTrip(_ snapshot: WidgetSnapshot) throws -> WidgetSnapshot {
        let data = try makeEncoder().encode(snapshot)
        return try makeDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
