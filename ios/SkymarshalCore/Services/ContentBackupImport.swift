import Foundation

// MARK: - File purpose
// Decodes Skymarshal JSON content exports (see ``Exporter/contentJSON``) with
// handle/DID integrity checks and skips likes/reposts that lack a viewer
// ``deletionURI`` (unsafe to delete until re-hydrated from the API).

/// Decodes exported content JSON into ``ContentItem`` values for restore preview
/// or merge/replace via ``ContentService/applyBackupImport``.
@available(iOS 17, *)
public enum ContentBackupImport: Sendable {

    public enum ImportError: Error, Sendable, Equatable {
        case handleMismatch(expected: String, found: String?)
        case didMismatch(expected: String, found: String?)
    }

    public struct DecodeOutcome: Sendable, Equatable {
        public let items: [ContentItem]
        public let skippedLikeRepostWithoutDeletionURI: Int
        public let envelopeHandle: String?
        public let envelopeDid: String?

        public init(
            items: [ContentItem],
            skippedLikeRepostWithoutDeletionURI: Int,
            envelopeHandle: String?,
            envelopeDid: String?
        ) {
            self.items = items
            self.skippedLikeRepostWithoutDeletionURI = skippedLikeRepostWithoutDeletionURI
            self.envelopeHandle = envelopeHandle
            self.envelopeDid = envelopeDid
        }
    }

    public struct RestorePreviewSummary: Sendable, Equatable {
        public let importedCount: Int
        public let currentCount: Int
        public let onlyInImport: Int
        public let onlyInCurrent: Int
        public let skippedUnsafeLikeRepost: Int

        public init(
            importedCount: Int,
            currentCount: Int,
            onlyInImport: Int,
            onlyInCurrent: Int,
            skippedUnsafeLikeRepost: Int = 0
        ) {
            self.importedCount = importedCount
            self.currentCount = currentCount
            self.onlyInImport = onlyInImport
            self.onlyInCurrent = onlyInCurrent
            self.skippedUnsafeLikeRepost = skippedUnsafeLikeRepost
        }
    }

    private struct Envelope: Decodable {
        let handle: String?
        let did: String?
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
        let deletionURI: String?

        func makeContentItemOrSkipUnsafe(skipped: inout Int) -> ContentItem? {
            let type = ContentType(rawValue: contentType) ?? .posts
            if type == .likes || type == .reposts {
                guard let d = deletionURI, !d.isEmpty else {
                    skipped += 1
                    return nil
                }
            }
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
                deletionURI: deletionURI,
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
    /// - Parameters:
    ///   - expectedHandle: When non-nil, must match envelope `handle` (normalized) if the envelope includes a handle.
    ///   - expectedDid: When non-nil, must match envelope `did` if the envelope includes a DID.
    public static func decodeContentItems(
        from data: Data,
        expectedHandle: String?,
        expectedDid: String?
    ) throws -> DecodeOutcome {
        let decoder = JSONDecoder()
        let env = try decoder.decode(Envelope.self, from: data)

        if let exp = expectedHandle?.trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty,
           let found = env.handle?.trimmingCharacters(in: .whitespacesAndNewlines), !found.isEmpty {
            let nExp = ContentService.normalizeHandle(exp)
            let nFound = ContentService.normalizeHandle(found)
            if nExp != nFound {
                throw ImportError.handleMismatch(expected: nExp, found: found)
            }
        }

        if let expDid = expectedDid?.trimmingCharacters(in: .whitespacesAndNewlines), !expDid.isEmpty,
           let foundDid = env.did?.trimmingCharacters(in: .whitespacesAndNewlines), !foundDid.isEmpty {
            if expDid.lowercased() != foundDid.lowercased() {
                throw ImportError.didMismatch(expected: expDid, found: foundDid)
            }
        }

        var skipped = 0
        var out: [ContentItem] = []
        out.reserveCapacity(env.items.count)
        for row in env.items {
            if let item = row.makeContentItemOrSkipUnsafe(skipped: &skipped) {
                out.append(item)
            }
        }
        return DecodeOutcome(
            items: out,
            skippedLikeRepostWithoutDeletionURI: skipped,
            envelopeHandle: env.handle,
            envelopeDid: env.did
        )
    }

    public static func restorePreview(
        currentItems: [ContentItem],
        importedItems: [ContentItem],
        skippedUnsafeLikeRepost: Int = 0
    ) -> RestorePreviewSummary {
        let curUris = Set(currentItems.map(\.uri))
        let impUris = Set(importedItems.map(\.uri))
        let onlyImp = impUris.subtracting(curUris).count
        let onlyCur = curUris.subtracting(impUris).count
        return RestorePreviewSummary(
            importedCount: importedItems.count,
            currentCount: currentItems.count,
            onlyInImport: onlyImp,
            onlyInCurrent: onlyCur,
            skippedUnsafeLikeRepost: skippedUnsafeLikeRepost
        )
    }
}
