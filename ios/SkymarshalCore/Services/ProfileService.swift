import Foundation

/// Paginated profile graph reads for the profile explorer — no timeline, no compose.
@available(iOS 17, *)
public actor ProfileService {

    private let client: ATProtoClient

    public init(client: ATProtoClient) {
        self.client = client
    }

    /// Fetch profile summary (public read host).
    public func fetchProfile(actor: String) async throws -> BskyProfile {
        try await client.getProfile(actor: actor)
    }

    /// All followers of `actor` up to `maxPages` (100 profiles per page max).
    public func loadFollowers(actor: String, maxPages: Int = 40) async throws -> [BskyProfile] {
        var combined: [BskyProfile] = []
        var cursor: String?
        var pages = 0
        repeat {
            let page = try await client.getFollowers(actor: actor, cursor: cursor)
            combined.append(contentsOf: page.followers)
            cursor = page.cursor
            pages += 1
            if cursor == nil || pages >= maxPages { break }
        } while true
        return Self.uniqueByDID(combined)
    }

    /// Accounts `actor` follows (uses authenticated host — matches existing follow-list semantics).
    public func loadFollows(actor: String, maxPages: Int = 40) async throws -> [BskyProfile] {
        var combined: [BskyProfile] = []
        var cursor: String?
        var pages = 0
        repeat {
            let page = try await client.getFollows(actor: actor, cursor: cursor)
            combined.append(contentsOf: page.follows)
            cursor = page.cursor
            pages += 1
            if cursor == nil || pages >= maxPages { break }
        } while true
        return Self.uniqueByDID(combined)
    }

    /// Cursor paging can hand back the same account on two pages when the
    /// graph changes mid-read. The explorer list is keyed by DID, and a
    /// repeated identity breaks SwiftUI list diffing (the same failure
    /// `FollowerService.scan` guards against). Keep the first occurrence.
    static func uniqueByDID(_ profiles: [BskyProfile]) -> [BskyProfile] {
        var seen = Set<String>()
        return profiles.filter { seen.insert($0.did).inserted }
    }
}
