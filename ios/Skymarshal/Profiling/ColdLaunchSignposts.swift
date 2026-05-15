import Foundation
import os

/// Points-of-interest signposts for Instruments (subsystem
/// `blue.skymarshal.ios`, category `ColdLaunch`). Pair **begin**/**end**
/// intervals with the same `name` and `signpostID` so the template
/// "Points of Interest" and SwiftUI timelines show cold-launch work.
///
/// **Primary functions:** `runSyncInterval`, `runAsyncInterval`, `event`
/// **I/O:** none — emits to the unified logging system only.
enum ColdLaunchSignposts {

    static let subsystem = "blue.skymarshal.ios"
    static let category = "ColdLaunch"

    static let log = OSLog(subsystem: subsystem, category: category)

    /// Wrap synchronous work (e.g. ``AppModel.liveDefault()`` container build).
    @inline(__always)
    static func runSyncInterval<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let sid = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: sid)
        defer { os_signpost(.end, log: log, name: name, signpostID: sid) }
        return try work()
    }

    /// Wrap async work (e.g. `hydrateFromCache`, `RootView.task`).
    @inline(__always)
    static func runAsyncInterval<T>(_ name: StaticString, _ work: () async throws -> T) async rethrows -> T {
        let sid = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: sid)
        defer { os_signpost(.end, log: log, name: name, signpostID: sid) }
        return try await work()
    }

    /// Instant marker (tab appear, app init milestones).
    @inline(__always)
    static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name)
    }
}
