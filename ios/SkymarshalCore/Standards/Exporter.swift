import Foundation

/// Pure-function exporter for content + follower scan results.
/// Produces JSON or CSV `Data` ready for SwiftUI's ShareLink to hand
/// off to the iOS share sheet (Save to Files, AirDrop, Mail, etc.).
///
/// JSON shape mirrors the web's TS `DataManager.exportData()` output:
/// top-level `{handle, exportedAt, items: [...]}`. CSV is tabular
/// with one row per item and a header row.
public enum Exporter {

    // MARK: - Content (posts / replies / reposts / likes)

    public static func contentJSON(
        _ items: [ContentItem],
        handle: String?,
        did: String? = nil
    ) throws -> ExportPayload {
        let dateFormatter = ISO8601DateFormatter()
        let envelope = ContentExportEnvelope(
            handle: handle,
            did: did,
            exportedAt: dateFormatter.string(from: Date()),
            itemCount: items.count,
            items: items.map { ContentExportRow($0, dateFormatter: dateFormatter) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        return ExportPayload(
            data: data,
            suggestedFilename: filename(for: handle, kind: "content", ext: "json"),
            mimeType: "application/json"
        )
    }

    public static func contentCSV(_ items: [ContentItem]) -> ExportPayload {
        let dateFormatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append([
            "uri", "cid", "contentType", "createdAt",
            "likeCount", "repostCount", "replyCount",
            "engagementScore", "hasMedia", "altText", "text",
        ].joined(separator: ","))

        for item in items {
            lines.append([
                csvEscape(item.uri),
                csvEscape(item.cid),
                csvEscape(item.contentType.rawValue),
                csvEscape(item.createdAt.map { dateFormatter.string(from: $0) } ?? ""),
                String(item.likeCount),
                String(item.repostCount),
                String(item.replyCount),
                String(item.engagementScore),
                item.hasMedia ? "true" : "false",
                csvEscape(item.altText),
                csvEscape(item.text ?? ""),
            ].joined(separator: ","))
        }

        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        return ExportPayload(
            data: data,
            suggestedFilename: filename(for: nil, kind: "content", ext: "csv"),
            mimeType: "text/csv"
        )
    }

    // MARK: - Followers (analyzed accounts from a bluescreen scan)

    public static func followersJSON(
        _ accounts: [AnalyzedAccount],
        handle: String?
    ) throws -> ExportPayload {
        let dateFormatter = ISO8601DateFormatter()
        let envelope = FollowersExportEnvelope(
            handle: handle,
            exportedAt: dateFormatter.string(from: Date()),
            accountCount: accounts.count,
            accounts: accounts.map { FollowerExportRow($0, dateFormatter: dateFormatter) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        return ExportPayload(
            data: data,
            suggestedFilename: filename(for: handle, kind: "followers", ext: "json"),
            mimeType: "application/json"
        )
    }

    public static func followersCSV(_ accounts: [AnalyzedAccount]) -> ExportPayload {
        let dateFormatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append([
            "did", "handle", "displayName", "followersCount", "followsCount",
            "postsCount", "ratio", "botScore", "botFlags",
            "influenceScore", "influenceTier", "accountAgeDays", "postsPerDay",
            "profileCompleteness", "lastPostDate", "daysSinceLastPost",
            "isInactive", "isDeleted", "isMutual", "engagementScore",
        ].joined(separator: ","))

        for acc in accounts {
            lines.append([
                csvEscape(acc.did),
                csvEscape(acc.handle),
                csvEscape(acc.profile.displayName ?? ""),
                String(acc.profile.followersCount),
                String(acc.profile.followsCount),
                String(acc.profile.postsCount),
                String(acc.ratio),
                String(acc.botScore),
                csvEscape(acc.botFlags.joined(separator: "; ")),
                String(acc.influenceScore),
                csvEscape(acc.influenceTier.rawValue),
                String(acc.accountAgeDays),
                String(acc.postsPerDay),
                String(acc.profileCompleteness),
                csvEscape(acc.lastPostDate.map { dateFormatter.string(from: $0) } ?? ""),
                acc.daysSinceLastPost.map(String.init) ?? "",
                acc.isInactive ? "true" : "false",
                acc.isDeleted ? "true" : "false",
                acc.isMutual ? "true" : "false",
                String(acc.engagementScore),
            ].joined(separator: ","))
        }

        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        return ExportPayload(
            data: data,
            suggestedFilename: filename(for: nil, kind: "followers", ext: "csv"),
            mimeType: "text/csv"
        )
    }

    // MARK: - Helpers

    /// CSV-escape a single field per RFC 4180: wrap in double-quotes if
    /// the field contains a comma, double-quote, CR, or LF; double any
    /// embedded double-quotes.
    static func csvEscape(_ s: String) -> String {
        let needsQuoting = s.contains(",")
            || s.contains("\"")
            || s.contains("\n")
            || s.contains("\r")
        if !needsQuoting { return s }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func filename(for handle: String?, kind: String, ext: String) -> String {
        let date = ISO8601DateFormatter()
        date.formatOptions = [.withFullDate]
        let dateStr = date.string(from: Date()).prefix(10)  // YYYY-MM-DD
        if let h = handle, !h.isEmpty {
            let safe = h.replacingOccurrences(of: ".", with: "-")
            return "skymarshal-\(kind)-\(safe)-\(dateStr).\(ext)"
        }
        return "skymarshal-\(kind)-\(dateStr).\(ext)"
    }
}

/// Output of an export — the bytes plus the metadata SwiftUI's
/// ShareLink/Transferable needs to surface a sensible "Save as…"
/// experience.
public struct ExportPayload: Sendable, Hashable {
    public let data: Data
    public let suggestedFilename: String
    public let mimeType: String

    public init(data: Data, suggestedFilename: String, mimeType: String) {
        self.data = data
        self.suggestedFilename = suggestedFilename
        self.mimeType = mimeType
    }
}

// MARK: - Codable envelopes

private struct ContentExportEnvelope: Encodable {
    let handle: String?
    let did: String?
    let exportedAt: String
    let itemCount: Int
    let items: [ContentExportRow]
}

private struct ContentExportRow: Encodable {
    let uri: String
    let cid: String
    let contentType: String
    let text: String?
    let createdAt: String?
    let likeCount: Int
    let repostCount: Int
    let replyCount: Int
    let engagementScore: Double
    let hasMedia: Bool
    let altText: String?
    let deletionURI: String?

    init(_ item: ContentItem, dateFormatter: ISO8601DateFormatter) {
        self.uri = item.uri
        self.cid = item.cid
        self.contentType = item.contentType.rawValue
        self.text = item.text
        self.createdAt = item.createdAt.map { dateFormatter.string(from: $0) }
        self.likeCount = item.likeCount
        self.repostCount = item.repostCount
        self.replyCount = item.replyCount
        self.engagementScore = item.engagementScore
        self.hasMedia = item.hasMedia
        self.altText = item.altText.isEmpty ? nil : item.altText
        self.deletionURI = item.deletionURI
    }
}

private struct FollowersExportEnvelope: Encodable {
    let handle: String?
    let exportedAt: String
    let accountCount: Int
    let accounts: [FollowerExportRow]
}

private struct FollowerExportRow: Encodable {
    let did: String
    let handle: String
    let displayName: String?
    let followersCount: Int
    let followsCount: Int
    let postsCount: Int
    let ratio: Double
    let botScore: Double
    let botFlags: [String]
    let influenceScore: Double
    let influenceTier: String
    let accountAgeDays: Int
    let postsPerDay: Double
    let profileCompleteness: Double
    let lastPostDate: String?
    let daysSinceLastPost: Int?
    let isInactive: Bool
    let isDeleted: Bool
    let isMutual: Bool
    let engagementScore: Double

    init(_ acc: AnalyzedAccount, dateFormatter: ISO8601DateFormatter) {
        self.did = acc.did
        self.handle = acc.handle
        self.displayName = acc.profile.displayName
        self.followersCount = acc.profile.followersCount
        self.followsCount = acc.profile.followsCount
        self.postsCount = acc.profile.postsCount
        self.ratio = acc.ratio
        self.botScore = acc.botScore
        self.botFlags = acc.botFlags
        self.influenceScore = acc.influenceScore
        self.influenceTier = acc.influenceTier.rawValue
        self.accountAgeDays = acc.accountAgeDays
        self.postsPerDay = acc.postsPerDay
        self.profileCompleteness = acc.profileCompleteness
        self.lastPostDate = acc.lastPostDate.map { dateFormatter.string(from: $0) }
        self.daysSinceLastPost = acc.daysSinceLastPost
        self.isInactive = acc.isInactive
        self.isDeleted = acc.isDeleted
        self.isMutual = acc.isMutual
        self.engagementScore = acc.engagementScore
    }
}
