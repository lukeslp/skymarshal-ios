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

    /// Server-supplied waits are honored up to this cap. Anything longer
    /// (a fully exhausted hourly window can be ~50 min away) should fail
    /// upward so batch-level handling can halt with honest messaging
    /// instead of one item silently sleeping for an hour.
    public static let maxServerWaitSeconds: Double = 120

    /// Run `work` with 429-aware exponential backoff. Re-throws any non-429
    /// error immediately. After exhausting the schedule, throws the last
    /// observed 429 error.
    ///
    /// When the 429 carries a server-supplied wait (`Retry-After` /
    /// `ratelimit-reset`, surfaced as ``ATProtoError/retryAfterSeconds``),
    /// that wait is used for the next retry instead of the ladder step,
    /// clamped to ``maxServerWaitSeconds``. The fixed ladder remains the
    /// fallback whenever the server says nothing — never simplify it.
    ///
    /// Wrap each individual write call (e.g. one `deleteRecord`), not an
    /// outer batch loop — each URI gets its own retry budget.
    public static func withBackoff<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        let schedule: [UInt64] = [0] + backoffSeconds
        for delay in schedule {
            let serverWait = (lastError as? ATProtoError)?.retryAfterSeconds
                .map { min(max($0, 1), maxServerWaitSeconds) }
            if let serverWait {
                try await Task.sleep(nanoseconds: UInt64(serverWait * 1_000_000_000))
            } else if delay > 0 {
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
///
/// `error` is the structured XRPC error code parsed out of the JSON body
/// (e.g. `"ExpiredToken"`, `"InvalidToken"`, `"RateLimitExceeded"`).
/// `HTTPURLResponse.localizedString(forStatusCode:)` returns generic
/// phrases like "bad request" for the 400 the PDS returns on an expired
/// access JWT — without the parsed code we can't tell expiry apart from
/// a real client error, which is the root of the "atproto errors
/// everywhere after a while" failure mode.
public struct ATProtoError: Error, Sendable, Equatable, LocalizedError {
    public let status: Int
    public let message: String
    public let body: String?
    public let error: String?
    /// Server-instructed wait parsed from `Retry-After` / `ratelimit-reset`
    /// response headers, when present. ``RateLimit/withBackoff(_:)`` prefers
    /// this over its fixed ladder for the next retry.
    public let retryAfterSeconds: TimeInterval?

    public init(
        status: Int,
        message: String,
        body: String? = nil,
        error: String? = nil,
        retryAfterSeconds: TimeInterval? = nil
    ) {
        self.status = status
        self.message = message
        self.body = body
        self.error = error ?? Self.parseErrorCode(from: body)
        self.retryAfterSeconds = retryAfterSeconds
    }

    /// Surface the structured PDS message ("Token has been expired" rather
    /// than `localizedString(forStatusCode: 400) == "bad request"`) so
    /// `error.localizedDescription` is actually useful in UI toasts.
    public var errorDescription: String? {
        if let parsedMessage = Self.parseErrorMessage(from: body), !parsedMessage.isEmpty {
            return parsedMessage
        }
        if let error, !error.isEmpty {
            return "\(error) (HTTP \(status))"
        }
        return "\(message) (HTTP \(status))"
    }

    /// True for the two error codes that mean "your access token isn't
    /// good anymore, get a new one". Bluesky returns these on different
    /// statuses depending on path — `400 ExpiredToken` on most XRPC
    /// reads/writes, occasional `401 AuthenticationRequired` /
    /// `400 InvalidToken` on edge cases. We pattern-match codes, not
    /// statuses, to keep the detector robust to PDS behavior drift.
    public var isExpiredToken: Bool {
        guard let error else { return false }
        return Self.expiredTokenCodes.contains(error)
    }

    /// XRPC error codes that should trigger a refresh-and-retry path.
    public static let expiredTokenCodes: Set<String> = [
        "ExpiredToken",
        "InvalidToken",
        "AuthenticationRequired",
    ]

    private static func parseErrorCode(from body: String?) -> String? {
        parseJSONField(named: "error", body: body)
    }

    private static func parseErrorMessage(from body: String?) -> String? {
        parseJSONField(named: "message", body: body)
    }

    /// Single-field JSON peek used to pull `"error"` and `"message"` out
    /// of an XRPC error envelope without committing to a Codable shape
    /// (some error bodies have extra fields we don't model).
    private static func parseJSONField(named name: String, body: String?) -> String? {
        guard let body, !body.isEmpty,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let dict = json as? [String: Any] else {
            return nil
        }
        return dict[name] as? String
    }
}
