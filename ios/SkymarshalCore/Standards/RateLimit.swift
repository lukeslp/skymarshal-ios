import Foundation

/// 429-aware exponential backoff for Bluesky PDS write operations.
///
/// The PDS caps writes at roughly 5,000 per hour per account. A bulk delete
/// on a moderately active account will hit the limit; a bare `try/catch`
/// burns through every subsequent URI hammering the limit while doing zero
/// work. The schedule below is the proven sequence — total wait is 240s if
/// all retries are exhausted, after which the call fails upward.
///
/// Lifted verbatim from `reference/python/deletion.py:31-70`. The long tail
/// (60s, 120s) is what lets the per-account window reset.
public enum RateLimit {

    /// Backoff delays in seconds. The leading 0 is implicit (first attempt
    /// has no wait).
    public static let backoffSeconds: [UInt64] = [1, 2, 4, 8, 15, 30, 60, 120]

    /// Detect a 429 across three orthogonal signals: error description
    /// substring match, ``ATProtoError`` with status 429, or an `NSError`
    /// userInfo HTTPStatusCode of 429.
    public static func isRateLimit(_ error: Error) -> Bool {
        // Check both the debug description and the localized description —
        // LocalizedError types put the human-readable text in
        // localizedDescription via errorDescription, which String(describing:)
        // does not surface.
        let haystacks = [
            String(describing: error).lowercased(),
            error.localizedDescription.lowercased(),
        ]
        let needles = ["ratelimitexceeded", "rate limit", "too many requests"]
        if haystacks.contains(where: { hay in needles.contains(where: hay.contains) }) {
            return true
        }
        if let atError = error as? ATProtoError, atError.status == 429 {
            return true
        }
        if let httpStatus = (error as NSError).userInfo["HTTPStatusCode"] as? Int,
           httpStatus == 429 {
            return true
        }
        return false
    }

    /// Run `work` with 429-aware exponential backoff. Re-throws any non-429
    /// error immediately. After exhausting the schedule, throws the last
    /// observed 429 error.
    ///
    /// Wrap each individual write call (e.g. one `deleteRecord`), not an
    /// outer batch loop — each URI gets its own retry budget.
    public static func withBackoff<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        let schedule: [UInt64] = [0] + backoffSeconds
        for delay in schedule {
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
            do {
                return try await work()
            } catch {
                guard isRateLimit(error) else { throw error }
                lastError = error
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}

/// Lightweight error type for HTTP failures from AT Protocol XRPC calls.
/// Network code raises this; ``ContentService`` catches it.
public struct ATProtoError: Error, Sendable, Equatable {
    public let status: Int
    public let message: String
    public let body: String?

    public init(status: Int, message: String, body: String? = nil) {
        self.status = status
        self.message = message
        self.body = body
    }
}
