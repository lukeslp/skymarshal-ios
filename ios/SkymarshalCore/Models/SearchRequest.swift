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
    /// When `true`, ``keyword`` is parsed with ``SearchKeywordGrammar``
    /// (`+required`, `-excluded`, `"phrase"`, `plain` OR-terms, `\bword\b`).
    /// Optional so older saved presets decode without migration.
    public var advancedKeywordGrammar: Bool?
    /// Case-insensitive substring match against the item's `at://` URI (e.g.
    /// filter likes/reposts toward posts whose URI contains a DID fragment).
    public var subjectUriContains: String?

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
        advancedKeywordGrammar: Bool? = nil,
        subjectUriContains: String? = nil,
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
        self.advancedKeywordGrammar = advancedKeywordGrammar
        self.subjectUriContains = subjectUriContains
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
            || (authorDid?.isEmpty == false)
            || (excludedUris?.isEmpty == false)
            || mediaFilter != nil
            || advancedKeywordGrammar == true
            || (subjectUriContains?.isEmpty == false)
    }

    /// Precomputed keyword branch for one batch pass: advanced grammar is parsed at most once
    /// (see ``apply(to:)``). Single-item checks use ``matches(_:)``, which parses per call.
    public enum SearchKeywordFilterState: Sendable, Equatable {
        case inactive
        case substring(String)
        case grammar(clauses: [SearchKeywordClause])
        /// Advanced grammar was enabled but the expression did not parse — no matches.
        case grammarInvalid
    }

    /// Build the keyword filter state once before filtering many items.
    public func keywordFilterState() -> SearchKeywordFilterState {
        guard let needle = keyword, !needle.isEmpty else { return .inactive }
        if advancedKeywordGrammar == true {
            guard let clauses = try? SearchKeywordGrammar.parse(needle) else { return .grammarInvalid }
            return .grammar(clauses: clauses)
        }
        return .substring(needle)
    }

    /// Apply the request as a synchronous filter against an in-memory list.
    /// Server-side search isn't possible against AT Protocol — the user has
    /// downloaded their own content and we filter locally.
    public func apply(to items: [ContentItem]) -> [ContentItem] {
        let kw = keywordFilterState()
        return items.filter { matches($0, keywordFilterState: kw) }.prefix(limit).map { $0 }
    }

    /// Filter a single item (parses advanced grammar once per call — prefer ``apply(to:)`` for lists).
    public func matches(_ item: ContentItem) -> Bool {
        matches(item, keywordFilterState: keywordFilterState())
    }

    /// Filter a single item using a precomputed ``SearchKeywordFilterState`` (from ``keywordFilterState()``).
    public func matches(_ item: ContentItem, keywordFilterState: SearchKeywordFilterState) -> Bool {
        if let types = contentTypes, !types.contains(.all),
           !types.contains(item.contentType) { return false }

        switch keywordFilterState {
        case .inactive:
            break
        case .grammarInvalid:
            return false
        case .substring(let needle):
            let lowered = needle.lowercased()
            let textHit = item.text?.lowercased().contains(lowered) ?? false
            let altHit = includeAltTextInKeyword && item.altText.lowercased().contains(lowered)
            guard textHit || altHit else { return false }
        case .grammar(let clauses):
            let haystack = Self.keywordHaystack(item: item, includeAltText: includeAltTextInKeyword)
            guard SearchKeywordGrammar.matches(haystack: haystack, clauses: clauses) else { return false }
        }

        if let did = authorDid, !did.isEmpty {
            guard item.uri.localizedCaseInsensitiveContains(did) else { return false }
        }
        if let sub = subjectUriContains, !sub.isEmpty {
            guard item.uri.localizedCaseInsensitiveContains(sub) else { return false }
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

    private static func keywordHaystack(item: ContentItem, includeAltText: Bool) -> String {
        var parts: [String] = []
        if let t = item.text, !t.isEmpty { parts.append(t) }
        if includeAltText, !item.altText.isEmpty { parts.append(item.altText) }
        return parts.joined(separator: "\n")
    }
}

/// Search hit — same fields as ``ContentItem`` plus the computed score.
/// Kept as a distinct type so the public API surface matches Python's
/// `SearchResult` TypedDict.
public struct SearchResult: Identifiable, Hashable, Sendable {
    public let item: ContentItem
    public var id: String { item.id }
    public var engagementScore: Double { item.engagementScore }

    public init(item: ContentItem) {
        self.item = item
    }
}
