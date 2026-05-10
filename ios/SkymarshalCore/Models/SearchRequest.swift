import Foundation

/// Filter criteria for searching the user's loaded content.
///
/// Mirrors `reference/python/services/content_service.py:52-66` and adds the
/// TS-only fields from `reference/web/skymarshal/types.ts:63-92`
/// (`authorDid`, `excludedUris`, computed engagement bounds) — those are
/// good additions per MIGRATION.md.
///
/// All filter fields are optional and combine with **AND** semantics. A
/// `nil` field means "don't filter on this dimension."
public struct SearchRequest: Hashable, Sendable, Codable {
    public var keyword: String?
    public var contentTypes: Set<ContentType>?
    public var startDate: Date?
    public var endDate: Date?
    public var likes: ClosedRange<Int>?
    public var reposts: ClosedRange<Int>?
    public var replies: ClosedRange<Int>?
    public var minEngagement: Int?
    public var maxEngagement: Int?
    public var authorDid: String?
    public var excludedUris: Set<String>?
    public var mediaFilter: MediaFilter?
    public var includeAltTextInKeyword: Bool
    public var limit: Int

    public init(
        keyword: String? = nil,
        contentTypes: Set<ContentType>? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        likes: ClosedRange<Int>? = nil,
        reposts: ClosedRange<Int>? = nil,
        replies: ClosedRange<Int>? = nil,
        minEngagement: Int? = nil,
        maxEngagement: Int? = nil,
        authorDid: String? = nil,
        excludedUris: Set<String>? = nil,
        mediaFilter: MediaFilter? = nil,
        includeAltTextInKeyword: Bool = true,
        limit: Int = 250
    ) {
        self.keyword = keyword
        self.contentTypes = contentTypes
        self.startDate = startDate
        self.endDate = endDate
        self.likes = likes
        self.reposts = reposts
        self.replies = replies
        self.minEngagement = minEngagement
        self.maxEngagement = maxEngagement
        self.authorDid = authorDid
        self.excludedUris = excludedUris
        self.mediaFilter = mediaFilter
        self.includeAltTextInKeyword = includeAltTextInKeyword
        self.limit = limit
    }

    public enum MediaFilter: String, Hashable, Sendable, Codable, CaseIterable, Identifiable {
        case onlyMedia
        case noMedia

        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .onlyMedia: return "With media"
            case .noMedia:   return "No media"
            }
        }
    }

    /// True when at least one filter is set to a non-default value.
    public var hasActiveFilters: Bool {
        keyword?.isEmpty == false
            || contentTypes != nil
            || startDate != nil
            || endDate != nil
            || likes != nil
            || reposts != nil
            || replies != nil
            || minEngagement != nil
            || maxEngagement != nil
            || authorDid != nil
            || (excludedUris?.isEmpty == false)
            || mediaFilter != nil
    }

    /// Apply the request as a synchronous filter against an in-memory list.
    /// Server-side search isn't possible against AT Protocol — the user has
    /// downloaded their own content and we filter locally.
    public func apply(to items: [ContentItem]) -> [ContentItem] {
        items.filter(matches).prefix(limit).map { $0 }
    }

    public func matches(_ item: ContentItem) -> Bool {
        if let types = contentTypes, !types.contains(.all),
           !types.contains(item.contentType) { return false }
        if let needle = keyword, !needle.isEmpty {
            let lowered = needle.lowercased()
            let textHit = item.text?.lowercased().contains(lowered) ?? false
            let altHit = includeAltTextInKeyword && item.altText.lowercased().contains(lowered)
            guard textHit || altHit else { return false }
        }
        if let start = startDate, let created = item.createdAt, created < start { return false }
        if let end = endDate, let created = item.createdAt, created > end { return false }
        if let r = likes,   !r.contains(item.likeCount)   { return false }
        if let r = reposts, !r.contains(item.repostCount) { return false }
        if let r = replies, !r.contains(item.replyCount)  { return false }
        let score = Int(item.engagementScore)
        if let lo = minEngagement, score < lo { return false }
        if let hi = maxEngagement, score > hi { return false }
        if let excluded = excludedUris, excluded.contains(item.uri) { return false }
        switch mediaFilter {
        case .onlyMedia: if !item.hasMedia { return false }
        case .noMedia:   if item.hasMedia { return false }
        case .none:      break
        }
        return true
    }
}

/// Search hit — same fields as ``ContentItem`` plus the computed score.
/// Kept as a distinct type so the public API surface matches Python's
/// `SearchResult` TypedDict.
public struct SearchResult: Identifiable, Hashable, Sendable {
    public let item: ContentItem
    public var id: String { item.uri }
    public var engagementScore: Double { item.engagementScore }

    public init(item: ContentItem) {
        self.item = item
    }
}
