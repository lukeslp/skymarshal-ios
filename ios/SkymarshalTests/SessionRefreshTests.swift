import XCTest
@testable import SkymarshalCore

/// Unit coverage for the session refresh + persistence path that was
/// introduced after users reported `atproto errors everywhere` once the
/// 2-hour access JWT expired. The fix lives in three places:
///
///   1. ``ATProtoError`` parses the XRPC error body so the
///      `isExpiredToken` flag is reliable across the 400/401 codes the
///      PDS uses for this condition.
///   2. ``ATProtoClient`` refreshes on demand and retries once,
///      coalescing concurrent refreshes through ``refreshTask``.
///   3. ``SessionStore`` round-trips the rotating tokens through the
///      iOS keychain so cold start doesn't drop the user back to
///      LoginView while a perfectly valid refresh JWT (3-month TTL)
///      sits unused.
///
/// These tests focus on (1) and (3) — the small pure pieces. The
/// refresh-and-retry orchestration in (2) is observable end-to-end and
/// would require a URLProtocol-backed URLSession stub; that scaffolding
/// lives further down the testing roadmap.
final class SessionRefreshTests: XCTestCase {

    // MARK: - ATProtoError XRPC-code parsing

    func test_atProtoError_parsesErrorCodeFromXRPCBody() {
        let body = #"{"error":"ExpiredToken","message":"Token has been expired"}"#
        let err = ATProtoError(status: 400, message: "bad request", body: body)
        XCTAssertEqual(err.error, "ExpiredToken")
    }

    func test_atProtoError_parsesMessageIntoLocalizedDescription() {
        let body = #"{"error":"ExpiredToken","message":"Token has been expired"}"#
        let err = ATProtoError(status: 400, message: "bad request", body: body)
        // localizedDescription should now read the structured XRPC
        // message instead of HTTPURLResponse's generic "bad request".
        XCTAssertEqual(err.localizedDescription, "Token has been expired")
    }

    func test_atProtoError_handlesEmptyBodyGracefully() {
        let err = ATProtoError(status: 500, message: "internal", body: nil)
        XCTAssertNil(err.error)
        XCTAssertEqual(err.localizedDescription, "internal (HTTP 500)")
    }

    func test_atProtoError_handlesMalformedJSONGracefully() {
        let err = ATProtoError(status: 502, message: "bad gateway", body: "<html>nope</html>")
        XCTAssertNil(err.error)
        // Without a parsed message we fall back on the HTTP phrase.
        XCTAssertEqual(err.localizedDescription, "bad gateway (HTTP 502)")
    }

    func test_atProtoError_explicitErrorCodeOverridesParse() {
        let err = ATProtoError(
            status: 400,
            message: "bad request",
            body: #"{"error":"SomethingElse"}"#,
            error: "ExpiredToken"
        )
        XCTAssertEqual(err.error, "ExpiredToken")
    }

    // MARK: - isExpiredToken across the codes the PDS actually uses

    func test_isExpiredToken_trueForExpiredToken() {
        let err = ATProtoError(
            status: 400,
            message: "bad request",
            body: #"{"error":"ExpiredToken","message":"Token has expired"}"#
        )
        XCTAssertTrue(err.isExpiredToken)
    }

    func test_isExpiredToken_trueForInvalidToken() {
        let err = ATProtoError(
            status: 400,
            message: "bad request",
            body: #"{"error":"InvalidToken"}"#
        )
        XCTAssertTrue(err.isExpiredToken)
    }

    func test_isExpiredToken_trueForAuthenticationRequired() {
        let err = ATProtoError(
            status: 401,
            message: "unauthorized",
            body: #"{"error":"AuthenticationRequired"}"#
        )
        XCTAssertTrue(err.isExpiredToken)
    }

    func test_isExpiredToken_falseForRateLimit() {
        let err = ATProtoError(
            status: 429,
            message: "too many requests",
            body: #"{"error":"RateLimitExceeded"}"#
        )
        XCTAssertFalse(err.isExpiredToken)
    }

    func test_isExpiredToken_falseForUnrelated400() {
        let err = ATProtoError(
            status: 400,
            message: "bad request",
            body: #"{"error":"InvalidRequest","message":"missing field"}"#
        )
        XCTAssertFalse(err.isExpiredToken)
    }

    func test_isExpiredToken_falseWhenBodyHasNoErrorCode() {
        let err = ATProtoError(status: 401, message: "unauthorized", body: nil)
        XCTAssertFalse(err.isExpiredToken)
    }

    // MARK: - SessionStore round-trip through the keychain

    /// Round-trip a session through the Keychain to confirm persistence
    /// works on the simulator. The Skymarshal test target inherits the
    /// host app's keychain access so SecItem* succeeds without extra
    /// entitlements; this is the same surface the live app uses.
    func test_sessionStore_roundTrip() throws {
        SessionStore.clear()
        defer { SessionStore.clear() }

        let original = Session(
            did: "did:plc:roundtripfixture",
            handle: "roundtrip.bsky.social",
            accessJwt: "access-jwt-fixture",
            refreshJwt: "refresh-jwt-fixture"
        )

        XCTAssertTrue(SessionStore.save(original), "save() should succeed on a clean keychain")

        let loaded = SessionStore.load()
        XCTAssertEqual(loaded, original)
    }

    func test_sessionStore_saveReplacesExisting() throws {
        SessionStore.clear()
        defer { SessionStore.clear() }

        let first = Session(
            did: "did:plc:first",
            handle: "first.bsky.social",
            accessJwt: "access-first",
            refreshJwt: "refresh-first"
        )
        let second = Session(
            did: "did:plc:second",
            handle: "second.bsky.social",
            accessJwt: "access-second",
            refreshJwt: "refresh-second"
        )

        XCTAssertTrue(SessionStore.save(first))
        XCTAssertTrue(SessionStore.save(second), "save() should update the existing row")
        XCTAssertEqual(SessionStore.load(), second)
    }

    func test_sessionStore_clearRemovesPersistedSession() {
        SessionStore.clear()
        defer { SessionStore.clear() }

        let stored = Session(
            did: "did:plc:clearfixture",
            handle: "clear.bsky.social",
            accessJwt: "access-clear",
            refreshJwt: "refresh-clear"
        )
        _ = SessionStore.save(stored)
        XCTAssertNotNil(SessionStore.load())

        _ = SessionStore.clear()
        XCTAssertNil(SessionStore.load())
    }

    // MARK: - ATProtoClient session APIs (in-memory only — no network)

    func test_atProtoClient_setSessionStoresInMemoryAndKeychainIsOptional() async {
        // persistSessionToKeychain: false keeps the test hermetic — we
        // already cover the keychain round-trip directly above.
        let client = ATProtoClient(persistSessionToKeychain: false)
        let session = Session(
            did: "did:plc:memorytest",
            handle: "memory.bsky.social",
            accessJwt: "a",
            refreshJwt: "r"
        )
        await client.setSession(session)

        let isAuth = await client.isAuthenticated
        let handle = await client.currentHandle
        let did = await client.currentDid

        XCTAssertTrue(isAuth)
        XCTAssertEqual(handle, "memory.bsky.social")
        XCTAssertEqual(did, "did:plc:memorytest")
    }

    func test_atProtoClient_clearSessionWipesEverything() async {
        let client = ATProtoClient(persistSessionToKeychain: false)
        let session = Session(
            did: "did:plc:cleartest",
            handle: "clear.bsky.social",
            accessJwt: "a",
            refreshJwt: "r"
        )
        await client.setSession(session)
        await client.clearSession()

        let isAuth = await client.isAuthenticated
        XCTAssertFalse(isAuth)
    }

    func test_atProtoClient_tryResumeReturnsFalseWithNoStoredSession() async {
        SessionStore.clear()
        defer { SessionStore.clear() }

        // Keychain persistence enabled but cleared — resume should fail.
        let client = ATProtoClient(persistSessionToKeychain: true)
        let resumed = await client.tryResumePersistedSession()
        XCTAssertFalse(resumed)
    }

    func test_atProtoClient_tryResumeLoadsStoredSession() async {
        SessionStore.clear()
        defer { SessionStore.clear() }

        let stored = Session(
            did: "did:plc:resumetest",
            handle: "resume.bsky.social",
            accessJwt: "access-resumed",
            refreshJwt: "refresh-resumed"
        )
        _ = SessionStore.save(stored)

        let client = ATProtoClient(persistSessionToKeychain: true)
        let resumed = await client.tryResumePersistedSession()
        XCTAssertTrue(resumed)

        let handle = await client.currentHandle
        let did = await client.currentDid
        XCTAssertEqual(handle, "resume.bsky.social")
        XCTAssertEqual(did, "did:plc:resumetest")
    }
}
