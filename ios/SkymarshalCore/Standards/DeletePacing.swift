import Foundation

/// Client-side pacing for bulk deletes, and the wall-clock arithmetic the
/// confirm UI shows before the user commits.
///
/// The PDS allows roughly 5,000 writes/hour/account. An unpaced loop
/// burns that in 10-20 minutes of network-speed deletes and then fights
/// the window for the rest of the batch. Pacing past a small burst keeps
/// the sustained rate (~3,200/hr) safely under the quota so the 429
/// ladder stays what it was designed to be: an exception handler, not
/// the steady state.
public enum DeletePacing {
    /// Deletes at the head of a batch that run unpaced. A burst this size
    /// is harmless against an hourly quota and keeps small batches fast.
    public static let burstAllowance = 300

    /// Inter-delete sleep once past the burst. 0.75s + ~0.35s of network
    /// round-trip ≈ 1.1s/item ≈ 3,200/hr sustained.
    public static let pacedDelaySeconds: Double = 0.75

    /// Observed median `deleteRecord` round-trip used for estimates.
    public static let perItemNetworkSeconds: Double = 0.35

    /// Wall-clock estimate for deleting `count` records, assuming no 429s
    /// (each 429 only adds time, so this is a floor — the UI copy says so).
    public static func estimatedSeconds(for count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        let burst = min(count, burstAllowance)
        let paced = count - burst
        return Double(burst) * perItemNetworkSeconds
            + Double(paced) * (pacedDelaySeconds + perItemNetworkSeconds)
    }

    /// "about 2 minutes" / "about 3 hours" — deliberately coarse; the
    /// point is honesty about magnitude, not precision.
    public static func formattedEstimate(for count: Int) -> String {
        let seconds = estimatedSeconds(for: count)
        if seconds < 90 { return "under 2 minutes" }
        let minutes = seconds / 60
        if minutes < 90 {
            return "about \(Int(minutes.rounded())) minutes"
        }
        let hours = minutes / 60
        if hours < 1.75 { return "about an hour and a half" }
        return "about \(Int(hours.rounded())) hours"
    }
}
