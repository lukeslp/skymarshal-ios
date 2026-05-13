import Foundation

// MARK: - File purpose
// Decodes Skymarshal JSON content exports (see ``Exporter/contentJSON``) and
// builds optional restore previews — local-only, no network.

/// Decodes exported content JSON into ``ContentItem`` values for restore preview
/// or offline injection via ``ContentService/setLoadedContent``.
@available(iOS 17, *)
public enum ContentBackupImport: Sendable {

    public struct RestorePreviewSummary: Sendable, Equatable {
        public let importedCount: Int
        public let currentCount: Int
        public let onlyInImport: Int
        public let onlyInCurrent: Int

        public init(importedCount: Int, currentCount: Int, onlyInImport: Int, onlyInCurrent: Int) {
            self.importedCount = importedCount
            self.currentCount = currentCount
            self.onlyInImport = onlyInImport
            self.onlyInCurrent = onlyInCurrent
        }
    }

    private struct Envelope: Decodable {
        let handle: String?
        let exportedAt: String?
        let itemCount: Int?
        let items: [Row]
    }

    private struct Row: Decodable {
        let uri: String
        let cid: String
        let contentType: String
        let text: String?
        let createdAt: String?
        let likeCount: Int
        let repostCount: Int
        let replyCount: Int
        let engagementScore: Double?
        let hasMedia: Bool
        let altText: String?

        func toContentItem() -> ContentItem {
            let type = ContentType(rawValue: contentType) ?? .posts
            let date: Date? = {
                guard let s = createdAt, !s.isEmpty else { return nil }
                return ISO8601DateFormatter().date(from: s)
            }()
            let media: [MediaPreview] = hasMedia
                ? [MediaPreview(kind: .image, alt: altText)]
                : []
            return ContentItem(
                uri: uri,
                cid: cid,
                contentType: type,
                text: text,
                createdAt: date,
                likeCount: likeCount,
                repostCount: repostCount,
                replyCount: replyCount,
                media: media,
                parentReplyURI: nil
            )
        }
    }

    /// Decode JSON bytes from ``Exporter/contentJSON`` into items.
    public static func decodeContentItems(from data: Data) throws -> [ContentItem] {
        let decoder = JSONDecoder()
        let env = try decoder.decode(Envelope.self, from: data)
        return env.items.map { $0.toContentItem() }
    }
    public static func restorePreview(
        currentItems: [ContentItem],
        importedItems: [ContentItem]
    ) -> RestorePreviewSummary {
        let curUris = Set(currentItems.map(\.uri))
        let impUris = Set(importedItems.map(\.uri))
        let onlyImp = impUris.subtracting(curUris).count
        let onlyCur = curUris.subtracting(impUris).count
        return RestorePreviewSummary(
            importedCount: importedItems.count,
            currentCount: currentItems.count,
            onlyInImport: onlyImp,
            onlyInCurrent: onlyCur
        )
    }
}

private extension ContentType {
    var isOwnRecord: Bool { self == .posts || self == .replies }
}
