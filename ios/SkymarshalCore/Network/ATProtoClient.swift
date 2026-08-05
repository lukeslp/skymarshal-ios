import Foundation

/// Minimal AT Protocol HTTP client — four endpoints only.
///
/// `createSession`, `getAuthorFeed`, `getActorLikes`, `deleteRecord`.
/// No third-party SDK; pure URLSession. The community ATProtoKit (pre-1.0,
/// 121 releases in 14 months, "things will break" per the maintainer) was
/// ruled out for the MVP — keeps dependencies at zero and avoids pre-1.0 SDK churn.
///
/// Two timeout layers: URLSession's `timeoutIntervalForRequest = 30` plus
/// a `withTimeout` wrapper at every call site. Without both, a wedged PDS
/// locks the UI in `isLoading = true` forever.
///
/// Session lifecycle: the client holds the active ``Session`` in memory
/// and persists it to ``SessionStore`` (Keychain) on every set / refresh
/// so a cold start can resume without a re-prompt. When the access JWT
/// expires (~2h TTL) any authenticated XRPC call returns an
/// ``ATProtoError`` with `isExpiredToken == true`; ``perform(_:)``
/// transparently calls ``refreshSession()`` and retries once. Refreshes
/// are coalesced through ``refreshTask`` so a burst of in-flight calls
/// don't each kick off their own refresh.
public enum ATProtoRecordCollection: String, Sendable {
    case post = "app.bsky.feed.post"
    case like = "app.bsky.feed.like"
    case repost = "app.bsky.feed.repost"
    case follow = "app.bsky.graph.follow"
}

public actor ATProtoClient {

    private let baseURL: URL
    /// Public read-only XRPC endpoint. Unauthenticated. Use for
    /// getProfiles / getLikes / getAuthorFeed-of-other-actors —
    /// avoids burning your access-jwt rate budget on read sweeps.
    private let publicURL: URL
    private let session: URLSession
    private var currentSession: Session?
    /// Coalesces concurrent refresh attempts so a burst of expired-token
    /// errors from N parallel XRPC calls produces ONE refresh, not N.
    /// Each caller awaits the same task and gets the same new Session.
    /// Cleared on success/failure so the next expiration starts fresh.
    private var refreshTask: Task<Session, Error>?
    /// When true, ``setSession``/``clearSession`` write through to
    /// ``SessionStore``. Disabled by tests that don't want to touch the
    /// device keychain.
    private let persistSessionToKeychain: Bool

    public init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        publicURL: URL = URL(string: "https://public.api.bsky.app")!,
        session: URLSession? = nil,
        persistSessionToKeychain: Bool = true
    ) {
        self.baseURL = baseURL
        self.publicURL = publicURL
        self.persistSessionToKeychain = persistSessionToKeychain
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 120
            config.waitsForConnectivity = false
            config.httpMaximumConnectionsPerHost = 4
            self.session = URLSession(configuration: config)
        }
    }

    public var isAuthenticated: Bool { currentSession != nil }
    public var currentHandle: String? { currentSession?.handle }
    public var currentDid: String? { currentSession?.did }

    public func setSession(_ session: Session) {
        self.currentSession = session
        if persistSessionToKeychain {
            SessionStore.save(session)
        }
    }

    public func clearSession() {
        self.currentSession = nil
        refreshTask?.cancel()
        refreshTask = nil
        if persistSessionToKeychain {
            SessionStore.clear()
        }
    }

    /// Optimistic resume of a previously-persisted session. Loads the
    /// Keychain-backed tokens and primes ``currentSession`` without
    /// pre-validating against the network — the first authenticated
    /// XRPC call will refresh as needed via ``perform(_:requiresAuth:allowRefresh:)``,
    /// and the refresh-and-retry path clears state on failure. This
    /// avoids killing a perfectly good session at cold start just
    /// because the user is briefly offline. Returns `true` when tokens
    /// were loaded; `false` only when no session is persisted.
    @discardableResult
    public func tryResumePersistedSession() async -> Bool {
        guard persistSessionToKeychain, let stored = SessionStore.load() else {
            return false
        }
        self.currentSession = stored
        return true
    }

    // MARK: - Auth

    /// `com.atproto.server.createSession` — log in with handle + app password.
    public func createSession(handle: String, password: String) async throws -> Session {
        let body: [String: String] = ["identifier": handle, "password": password]
        let result: Session = try await withTimeout(seconds: 30) {
            try await self.post(
                lexicon: "com.atproto.server.createSession",
                body: body,
                requireAuth: false
            )
        }
        self.currentSession = result
        if persistSessionToKeychain {
            SessionStore.save(result)
        }
        return result
    }

    /// `com.atproto.server.refreshSession` — exchange the current refresh
    /// JWT for a fresh `(accessJwt, refreshJwt)` pair. Bluesky rotates
    /// the refresh token on every call, so we must persist the new pair
    /// or the next refresh will fail with "RefreshTokenExpired" against
    /// a token that's already been consumed.
    ///
    /// Concurrent callers share one Task via ``refreshTask`` — N
    /// in-flight XRPC calls that all 401 at once trigger ONE refresh,
    /// not N. The deduplication is correctness as much as politeness:
    /// each refresh invalidates the prior refresh token, so racing
    /// refreshes mutually kill each other.
    @discardableResult
    public func refreshSession() async throws -> Session {
        if let inFlight = refreshTask {
            return try await inFlight.value
        }
        guard let session = currentSession else {
            throw ATProtoError(status: 401, message: "No session to refresh")
        }
        let baseURL = self.baseURL
        let urlSession = self.session
        let refreshJwt = session.refreshJwt
        let persist = self.persistSessionToKeychain
        let task = Task<Session, Error> { () -> Session in
            try await withTimeout(seconds: 30) {
                var request = URLRequest(
                    url: baseURL.appendingPathComponent("xrpc/com.atproto.server.refreshSession")
                )
                request.httpMethod = "POST"
                request.setValue("Bearer \(refreshJwt)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ATProtoError(status: 0, message: "Non-HTTP response")
                }
                guard 200..<300 ~= http.statusCode else {
                    throw ATProtoError(
                        status: http.statusCode,
                        message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                        body: String(data: data, encoding: .utf8)
                    )
                }
                let new = try JSONDecoder().decode(Session.self, from: data)
                if persist {
                    SessionStore.save(new)
                }
                return new
            }
        }
        refreshTask = task
        do {
            let new = try await task.value
            refreshTask = nil
            self.currentSession = new
            return new
        } catch {
            refreshTask = nil
            throw error
        }
    }

    // MARK: - Reads

    /// `app.bsky.feed.getAuthorFeed` — own posts (and replies + reposts depending on filter).
    public func getAuthorFeed(
        actor: String,
        limit: Int = 100,
        cursor: String? = nil,
        filter: String = "posts_with_replies"
    ) async throws -> AuthorFeedResponse {
        var params: [URLQueryItem] = [
            .init(name: "actor", value: actor),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
            .init(name: "filter", value: filter),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(lexicon: "app.bsky.feed.getAuthorFeed", queryItems: params)
        }
    }

    /// `app.bsky.feed.getActorLikes` — own likes.
    public func getActorLikes(
        actor: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> LikesResponse {
        var params: [URLQueryItem] = [
            .init(name: "actor", value: actor),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(lexicon: "app.bsky.feed.getActorLikes", queryItems: params)
        }
    }

    /// `com.atproto.repo.listRecords` over `app.bsky.feed.like` — the user's own
    /// like records, read straight from their repo.
    ///
    /// Use this **in addition to** ``getActorLikes(actor:limit:cursor:)``, never
    /// instead of it. The feed endpoint carries engagement counts and post text
    /// that the raw records do not; this endpoint sees like records the feed
    /// endpoint cannot, because it never tries to hydrate the subject. Diffing
    /// the two is what surfaces ghost likes.
    public func listLikeRecords(
        repo: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> LikeRecordsResponse {
        var params: [URLQueryItem] = [
            .init(name: "repo", value: repo),
            .init(name: "collection", value: ATProtoRecordCollection.like.rawValue),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(lexicon: "com.atproto.repo.listRecords", queryItems: params)
        }
    }

    // MARK: - Reads (graph)

    /// `app.bsky.graph.getFollows` — accounts the user follows.
    /// Authenticated (user's own follow list). Pagination via cursor.
    public func getFollows(
        actor: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> GetFollowsResponse {
        var params: [URLQueryItem] = [
            .init(name: "actor", value: actor),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(lexicon: "app.bsky.graph.getFollows", queryItems: params)
        }
    }

    /// `app.bsky.graph.getFollowers` — accounts following the actor (followers).
    /// Public endpoint — readable without auth for most actors.
    public func getFollowers(
        actor: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> GetFollowersResponse {
        var params: [URLQueryItem] = [
            .init(name: "actor", value: actor),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        let publicURL = self.publicURL
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(
                lexicon: "app.bsky.graph.getFollowers",
                queryItems: params,
                base: publicURL,
                requireAuth: false
            )
        }
    }

    /// `app.bsky.actor.getProfiles` — batch fetch detailed profiles.
    /// Hits the **public read endpoint** (no auth needed) so a 1k-follow
    /// scan doesn't burn the user's authenticated rate budget.
    /// Batch size is capped at 25 by the lexicon.
    public func getProfiles(actors: [String]) async throws -> GetProfilesResponse {
        guard !actors.isEmpty else { return GetProfilesResponse(profiles: []) }
        let capped = Array(actors.prefix(25))
        let params = capped.map { URLQueryItem(name: "actors", value: $0) }
        let publicURL = self.publicURL
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(
                lexicon: "app.bsky.actor.getProfiles",
                queryItems: params,
                base: publicURL,
                requireAuth: false
            )
        }
    }

    /// `app.bsky.feed.getLikes` — who liked a specific post URI. Used to
    /// check whether each followed account has interacted with the user.
    /// Public endpoint, no auth.
    public func getLikes(
        uri: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> GetLikesResponse {
        var params: [URLQueryItem] = [
            .init(name: "uri", value: uri),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        let publicURL = self.publicURL
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(
                lexicon: "app.bsky.feed.getLikes",
                queryItems: params,
                base: publicURL,
                requireAuth: false
            )
        }
    }

    /// `app.bsky.feed.getRepostedBy` — who reposted a post URI. Public
    /// endpoint, no auth. Used by interaction history to find their
    /// reposts of your content.
    public func getRepostedBy(
        uri: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> GetRepostedByResponse {
        var params: [URLQueryItem] = [
            .init(name: "uri", value: uri),
            .init(name: "limit", value: "\(min(max(limit, 1), 100))"),
        ]
        if let cursor { params.append(.init(name: "cursor", value: cursor)) }
        let publicURL = self.publicURL
        return try await withTimeout(seconds: 30) { [params] in
            try await self.get(
                lexicon: "app.bsky.feed.getRepostedBy",
                queryItems: params,
                base: publicURL,
                requireAuth: false
            )
        }
    }

    /// `app.bsky.actor.getProfile` — single detailed profile. Public
    /// endpoint, no auth. Useful when you have a handle/DID but no
    /// scan-cached AnalyzedAccount yet (e.g. mutual follows traversal,
    /// or a future "refresh this profile" affordance on AccountDetailView).
    public func getProfile(actor: String) async throws -> BskyProfile {
        let publicURL = self.publicURL
        return try await withTimeout(seconds: 30) {
            try await self.get(
                lexicon: "app.bsky.actor.getProfile",
                queryItems: [.init(name: "actor", value: actor)],
                base: publicURL,
                requireAuth: false
            )
        }
    }

    // MARK: - Writes

    /// `com.atproto.repo.deleteRecord`. **Wrapped in `RateLimit.withBackoff`** —
    /// see `RateLimit.swift` for the schedule and rationale. Outer timeout
    /// of 300s (5 min) accommodates the 240s worst-case retry budget plus
    /// one final request.
    public func deleteRecord(
        uri: String,
        expectedCollection: ATProtoRecordCollection,
        onRateLimitWait: (@Sendable (Int) -> Void)? = nil
    ) async throws {
        guard let session = currentSession else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }
        let parts = parseATURI(uri)
        guard let repo = parts.did,
              let collection = parts.collection,
              let rkey = parts.rkey,
              !repo.isEmpty,
              !collection.isEmpty,
              !rkey.isEmpty else {
            throw ATProtoError(
                status: 400,
                message: "Malformed at:// URI — expected at://did/collection/rkey, got \(uri)"
            )
        }
        guard repo == session.did else {
            throw ATProtoError(
                status: 400,
                message: "Delete target belongs to \(repo), not the signed-in repository"
            )
        }
        guard collection == expectedCollection.rawValue else {
            throw ATProtoError(
                status: 400,
                message: "Delete target collection \(collection) does not match \(expectedCollection.rawValue)"
            )
        }

        let body: [String: String] = [
            "repo": session.did,
            "collection": expectedCollection.rawValue,
            "rkey": rkey,
        ]

        try await withTimeout(seconds: 300) {
            try await RateLimit.withBackoff(onWait: onRateLimitWait) {
                let _: EmptyResponse = try await self.post(
                    lexicon: "com.atproto.repo.deleteRecord",
                    body: body,
                    requireAuth: true
                )
            }
        }
    }

    // MARK: - Internals

    private func get<T: Decodable>(
        lexicon: String,
        queryItems: [URLQueryItem],
        base: URL? = nil,
        requireAuth: Bool = true
    ) async throws -> T {
        var components = URLComponents(
            url: (base ?? baseURL).appendingPathComponent("xrpc/\(lexicon)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        if requireAuth, let token = currentSession?.accessJwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request, requiresAuth: requireAuth)
    }

    private func post<Body: Encodable, T: Decodable>(
        lexicon: String,
        body: Body,
        requireAuth: Bool
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("xrpc/\(lexicon)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requireAuth, let token = currentSession?.accessJwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request, requiresAuth: requireAuth)
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        requiresAuth: Bool = true,
        allowRefresh: Bool = true
    ) async throws -> T {
        do {
            let (data, response) = try await performRaw(request)
            if T.self == EmptyResponse.self {
                // Endpoints that return no body still need to satisfy the
                // generic. Decode empty JSON object — works because the
                // marker has no fields. Avoids the unsafe `as! T` cast that
                // crashed if a caller ever asked for a non-EmptyResponse
                // type from an empty endpoint.
                return try JSONDecoder().decode(T.self, from: Data("{}".utf8))
            }
            _ = response
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as ATProtoError where allowRefresh
            && requiresAuth
            && error.isExpiredToken
            && currentSession != nil {
            // Access JWT expired (or got revoked). Refresh once and
            // replay with the new bearer; second failure bubbles up
            // and triggers a session-invalidated notification so the
            // UI can drop back to the LoginView instead of spamming
            // identical "ExpiredToken" toasts at the user.
            let newSession: Session
            do {
                newSession = try await refreshSession()
            } catch {
                // Only a definitive rejection of the refresh token means the
                // session is dead. A timeout, airplane mode, or a PDS 5xx is
                // transient — wiping the Keychain on those reintroduced the
                // "logged out after a while" bug for every flaky network.
                if Self.isDefinitiveAuthRejection(error) {
                    handleRefreshFailure()
                }
                throw error
            }
            var retried = request
            retried.setValue("Bearer \(newSession.accessJwt)", forHTTPHeaderField: "Authorization")
            return try await perform(retried, requiresAuth: requiresAuth, allowRefresh: false)
        }
    }

    /// Returns raw `(Data, HTTPURLResponse)` after status-code validation.
    /// Centralizes the HTTP-level error mapping so the typed `perform`
    /// can stay focused on decoding.
    private func performRaw(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ATProtoError(status: 0, message: "Non-HTTP response")
        }
        guard 200..<300 ~= http.statusCode else {
            throw ATProtoError(
                status: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                body: String(data: data, encoding: .utf8),
                retryAfterSeconds: Self.retryAfterSeconds(from: http)
            )
        }
        return (data, http)
    }

    /// Extract the server-instructed wait from a throttled response.
    /// `Retry-After` carries delta-seconds; `ratelimit-reset` carries a
    /// Unix epoch. Either feeds ``RateLimit/withBackoff(_:)`` as an
    /// override; absent both, the fixed ladder applies.
    static func retryAfterSeconds(from http: HTTPURLResponse) -> TimeInterval? {
        if let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfter), seconds > 0 {
            return seconds
        }
        if let reset = http.value(forHTTPHeaderField: "ratelimit-reset"),
           let epoch = TimeInterval(reset) {
            let delta = epoch - Date().timeIntervalSince1970
            if delta > 0 { return delta }
        }
        return nil
    }

    /// Tear down a session that can't be refreshed. Clears in-memory +
    /// Keychain state and broadcasts ``Notification.Name.skymarshalSessionInvalidated``
    /// so observers (``AppModel``) can flip the UI back to LoginView
    /// with a useful "Session expired — please sign in again." message
    /// instead of letting the bare ATProtoError reach the user.
    /// True only when the PDS itself rejected the refresh token (HTTP 400 /
    /// 401 from `refreshSession`). `URLError`s and 5xx responses are
    /// transient and must NOT tear the session down.
    static func isDefinitiveAuthRejection(_ error: Error) -> Bool {
        guard let atError = error as? ATProtoError else { return false }
        return atError.status == 400 || atError.status == 401
    }

    private func handleRefreshFailure() {
        self.currentSession = nil
        self.refreshTask = nil
        if persistSessionToKeychain {
            SessionStore.clear()
        }
        NotificationCenter.default.post(
            name: .skymarshalSessionInvalidated,
            object: nil
        )
    }

    private func parseATURI(_ uri: String) -> (did: String?, collection: String?, rkey: String?) {
        // at://<did>/<collection>/<rkey>
        guard uri.hasPrefix("at://") else { return (nil, nil, nil) }
        let trimmed = String(uri.dropFirst("at://".count))
        let parts = trimmed.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return (nil, nil, nil) }
        return (String(parts[0]), String(parts[1]), String(parts[2]))
    }
}

/// Marker for endpoints that return no body.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

extension Notification.Name {
    /// Posted by ``ATProtoClient`` when a session refresh attempt fails
    /// and the locally-held tokens have been cleared. Observers should
    /// switch the UI back to a signed-out state and surface a copy
    /// banner asking the user to re-authenticate.
    public static let skymarshalSessionInvalidated = Notification.Name(
        "blue.skymarshal.ios.SessionInvalidated"
    )
}
