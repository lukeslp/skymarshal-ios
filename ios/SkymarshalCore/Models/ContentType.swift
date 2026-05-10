import Foundation

/// What kind of Bluesky content an item is.
///
/// Matches `reference/web/skymarshal/models/enums.ts:13-26` (TypeScript) and
/// `reference/python/models.py:78-86` (Python). The five-case set including
/// `all` is intentional — it's the segmented-control selector the UI binds
/// to, not a true classification.
public enum ContentType: String, Codable, Sendable, CaseIterable, Identifiable {
    case all
    case posts
    case replies
    case reposts
    case likes

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all:     return "All"
        case .posts:   return "Posts"
        case .replies: return "Replies"
        case .reposts: return "Reposts"
        case .likes:   return "Likes"
        }
    }

    /// AT Protocol record collection name, where applicable. `.all` and
    /// `.replies` (which live inside `app.bsky.feed.post` records with a
    /// non-nil `reply` field) return nil.
    public var atProtoCollection: String? {
        switch self {
        case .all, .replies: return nil
        case .posts:         return "app.bsky.feed.post"
        case .reposts:       return "app.bsky.feed.repost"
        case .likes:         return "app.bsky.feed.like"
        }
    }
}

/// Approval mode for a deletion operation.
public enum DeleteMode: String, Codable, Sendable, CaseIterable {
    case individual
    case batch
    case all
    case dryRun

    public var label: String {
        switch self {
        case .individual: return "One at a time"
        case .batch:      return "In batches"
        case .all:        return "All at once"
        case .dryRun:     return "Preview only"
        }
    }
}
