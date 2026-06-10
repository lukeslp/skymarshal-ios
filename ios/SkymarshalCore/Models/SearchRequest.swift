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
    /// Caps ``apply(to:maximumResults:)`` for programmatic callers (e.g.
    /// ``ContentService/search(_:)``). The SwiftUI list uses unbounded
    /// ``apply(to:)`` so large archives are not silently truncated.
    public var limit: Int
    /// When `true`, ``keyword`` is parsed with ``SearchKeywordGrammar``
    /// (`+required`, `-excluded`, `"phrase"`, `plain` OR-terms, `\bword\b`).
    /// Optional so older saved presets decode without migration.
    public var advancedKeywordGrammar: Bool?
    /// Case-insensitive substring match against the *subject* URI of likes
    /// and reposts (the post being liked / reposted, not the viewer record).
    /// Posts and replies are passed through — for them the post itself IS
    /// the subject and applying this filter has no semantic meaning.
    /// Matches Python `SearchManager.search`'s `subject_contains` gate at
    /// `reference/python/search.py:301-311`.
    public var subjectUriContains: String?
    /// Case-insensitive substring match against the subject post author's
    /// handle for likes and reposts (requires ``ContentItem/subjectAuthorHandle``
    /// populated at load). Posts and replies pass through. Mirrors Python
    /// `SearchManager._filter_by_subject_handle` at `search.py:604-642`.
    public var subjectHandleContains: String?

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
        subjectHandleContains: String? = nil,
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
        self.subjectHandleContains = subjectHandleContains
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
            || (subjectHandleContains?.isEmpty == false)
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
    /// downloaded their own content and we filter locally. No result cap —
    /// SwiftUI `List` virtualizes rows.
    public func apply(to items: [ContentItem]) -> [ContentItem] {
        apply(to: items, maximumResults: nil)
    }

    /// Same as ``apply(to:)``, optionally truncating. Pass an explicit cap
    /// for API callers; omit (`nil`) for the full match set.
    public func apply(to items: [ContentItem], maximumResults: Int?) -> [ContentItem] {
        let kw = keywordFilterState()
        let filtered = items.filter { matches($0, keywordFilterState: kw) }
        guard let cap = maximumResults else { return filtered }
        if cap <= 0 { return filtered }
        return Array(filtered.prefix(cap))
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
            // Mirrors Python: pass through for posts/replies (the post IS
            // the subject — this filter is about likes/reposts toward
            // posts that contain a DID or path fragment in their URI).
            // For likes/reposts, `ContentItem.uri` is already the subject
            // URI (see ContentItem.swift docstring), so the substring
            // check is direct.
            if item.contentType == .likes || item.contentType == .reposts {
                guard item.uri.localizedCaseInsensitiveContains(sub) else { return false }
            }
        }
        if let handleNeedle = subjectHandleContains, !handleNeedle.isEmpty {
            if item.contentType == .likes || item.contentType == .reposts {
                guard let handle = item.subjectAuthorHandle,
                      handle.localizedCaseInsensitiveContains(handleNeedle) else {
                    return false
                }
            }
        }
        // Fail closed: when a date filter is active, an item whose
        // createdAt could not be parsed must NOT match. Letting nil-dated
        // items through turned "delete before <date>" into "delete
        // everything" for archives whose timestamps failed to parse.
        if startDate != nil || endDate != nil {
            guard let created = item.createdAt else { return false }
            if let start = startDate, created < start { return false }
            if let end = endDate, created > end { return false }
        }
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
