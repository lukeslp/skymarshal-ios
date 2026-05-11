import Foundation

/// Two-layer async timeout pattern. URLSession bounds a single HTTP request;
/// this wrapper bounds the call as the caller experiences it (including
/// retries and downstream work URLSession can't see).
///
/// Complements URLSession’s per-request timeout (`ATProtoClient`). Both layers
/// must exist — without the call-site wrapper, a wedged
/// framework call below the URL layer leaves the UI in `isLoading=true`
/// forever.
public enum TimeoutError: Error, Sendable {
    case timedOut(seconds: TimeInterval)
}

/// Run `operation` with an upper time bound. Throws ``TimeoutError`` if
/// the deadline passes before `operation` returns. Cancels the racing
/// task on either branch winning so neither leaks.
public func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut(seconds: seconds)
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw TimeoutError.timedOut(seconds: seconds)
        }
        return result
    }
}
