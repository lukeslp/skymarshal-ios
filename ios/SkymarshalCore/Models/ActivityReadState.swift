import Foundation

/// Tri-state honesty flag for "could we actually read this account's
/// activity?"
///
/// The Bluescreen activity signals (last-post date, interaction sweeps)
/// are read from the Bluesky AppView. The AppView silently returns
/// HTTP 200 + an empty feed in two cases that are NOT "this account is
/// inactive":
///
///   1. The read is being **throttled** under load (429, or a
///      suspiciously empty 200 for an account whose `postsCount > 0`).
///   2. The account **self-labels** `!no-unauthenticated`, gating its
///      feed from unauthenticated public reads.
///
/// Misreading either as "inactive / no engagement" in a follow-cleanup
/// tool can sweep real, active accounts into a bulk unfollow. The fix is
/// fail-safe: when we are not sure the read was honest, we mark it
/// ``unknown`` and the cleanup filters/presets refuse to act on it.
///
/// This is the read-state channel (did the read succeed?), distinct from
/// the engagement-unknown channel (`AnalyzedAccount.interactedRecently:
/// Bool?` where `nil` = unknown). Activity that we *did* read but found
/// genuinely empty is ``read`` with an empty result — only an unreliable
/// read is ``unknown``.
public enum ActivityReadState: String, Sendable, Hashable, Codable {
    /// We read the account's activity and trust the result (even when
    /// the result is a genuine zero — a confirmed-empty feed for an
    /// account with `postsCount == 0`).
    case read

    /// We could not reliably read the account's activity (throttled,
    /// gated, or errored). Inactivity/disengagement derived from an
    /// AppView read MUST be suppressed for these accounts.
    case unknown
}
