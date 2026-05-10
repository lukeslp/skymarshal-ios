import Foundation

/// Minimal AT Protocol HTTP client — four endpoints only.
///
/// `createSession`, `getAuthorFeed`, `getActorLikes`, `deleteRecord`.
/// No third-party SDK; pure URLSession. The community ATProtoKit (pre-1.0,
/// 121 releases in 14 months, "things will break" per the maintainer) was
/// ruled out for the MVP — see `~/.swarm/reports/2026-05-09/enhance-skymarshal-ios.md`.
///
/// Two timeout layers: URLSession's `timeoutIntervalForRequest = 30` plus
/// a `withTimeout` wrapper at every call site. Without both, a wedged PDS
/// locks the UI in `isLoading = true` forever.
public actor ATProtoClient {

    private let baseURL: URL
    private let session: URLSession
    private var currentSession: Session?

    public init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
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
    }

    public func clearSession() {
        self.currentSession = nil
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
        return result
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

    // MARK: - Writes

    /// `com.atproto.repo.deleteRecord`. **Wrapped in `RateLimit.withBackoff`** —
    /// see `RateLimit.swift` for the schedule and rationale. Outer timeout
    /// of 300s (5 min) accommodates the 240s worst-case retry budget plus
    /// one final request.
    public func deleteRecord(uri: String) async throws {
        guard let session = currentSession else {
            throw ATProtoError(status: 401, message: "Not authenticated")
        }
        let parts = parseATURI(uri)
        guard let collection = parts.collection, let rkey = parts.rkey else {
            throw ATProtoError(
                status: 400,
                message: "Malformed at:// URI — expected at://did/collection/rkey, got \(uri)"
            )
        }

        let body: [String: String] = [
            "repo": session.did,
            "collection": collection,
            "rkey": rkey,
        ]

        try await withTimeout(seconds: 300) {
            try await RateLimit.withBackoff {
                let _: EmptyResponse = try await self.post(
                    lexicon: "com.atproto.repo.deleteRecord",
                    body: body,
                    requireAuth: true
                )
            }
        }
    }

    // MARK: - Internals

    private func get<T: Decodable>(lexicon: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("xrpc/\(lexicon)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        if let token = currentSession?.accessJwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
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
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ATProtoError(status: 0, message: "Non-HTTP response")
        }
        guard 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8)
            throw ATProtoError(
                status: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                body: body
            )
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try JSONDecoder().decode(T.self, from: data)
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
