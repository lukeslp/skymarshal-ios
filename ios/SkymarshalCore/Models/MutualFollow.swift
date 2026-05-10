import Foundation

/// One account that both the user and a target follow. Compact —
/// just enough to render an avatar tile in the AccountDetailView
/// "You both follow" section. Tap into a tile, look up the full
/// `AnalyzedAccount` from `FollowerService.loaded` if present, or
/// fall back to a `getProfile` re-fetch.
public struct MutualFollow: Identifiable, Hashable, Sendable, Codable {
    public var id: String { did }
    public let did: String
    public let handle: String
    public let displayName: String?
    public let avatar: String?

    public init(did: String, handle: String, displayName: String? = nil, avatar: String? = nil) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.avatar = avatar
    }
}

/// Result of `FollowerService.loadMutualFollows`. The `truncated`
/// flag tells the UI to surface a "(showing first 500)" hint when
/// the target's follow list exceeded the page cap.
public struct MutualFollowResult: Sendable, Hashable {
    public let matches: [MutualFollow]
    public let truncated: Bool

    public init(matches: [MutualFollow], truncated: Bool) {
        self.matches = matches
        self.truncated = truncated
    }
}
