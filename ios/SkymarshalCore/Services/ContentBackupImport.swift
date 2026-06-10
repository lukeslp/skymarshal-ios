import Foundation

// MARK: - File purpose
// Decodes Skymarshal JSON content exports (see ``Exporter/contentJSON``) with
// strict handle/DID integrity checks and rejects any row whose deletion
// target is missing, malformed, cross-account, or the wrong collection.

/// Decodes exported content JSON into ``ContentItem`` values for restore preview
/// or merge/replace via ``ContentService/applyBackupImport``.
@available(iOS 17, *)
public enum ContentBackupImport: Sendable {

    public enum ImportError: Error, Sendable, Equatable {
        case handleMismatch(expected: String, found: String?)
        case didMismatch(expected: String, found: String?)
        case missingEnvelopeIdentity(field: String)
        case invalidContentType(String)
        case unsafeDeletionURI(uri: String?, reason: String)
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

        func makeContentItem(expectedDid: String) throws -> ContentItem {
            guard let type = ContentType(rawValue: contentType), type != .all else {
                throw ImportError.invalidContentType(contentType)
            }
            let targetURI = deletionURI ?? ((type == .posts || type == .replies) ? uri : nil)
            let expectedCollection: ATProtoRecordCollection
            switch type {
            case .posts, .replies:
                expectedCollection = .post
            case .likes:
                expectedCollection = .like
            case .reposts:
                expectedCollection = .repost
            case .all:
                throw ImportError.invalidContentType(contentType)
            }
            try ContentBackupImport.validateDeletionURI(
                targetURI,
                expectedDid: expectedDid,
                expectedCollection: expectedCollection
            )

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
                deletionURI: targetURI,
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

        let exp = expectedHandle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expDid = expectedDid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !exp.isEmpty, !expDid.isEmpty else {
            throw ImportError.missingEnvelopeIdentity(field: exp.isEmpty ? "expected handle" : "expected DID")
        }
        guard let found = env.handle?.trimmingCharacters(in: .whitespacesAndNewlines), !found.isEmpty else {
            throw ImportError.missingEnvelopeIdentity(field: "handle")
        }
        guard let foundDid = env.did?.trimmingCharacters(in: .whitespacesAndNewlines), !foundDid.isEmpty else {
            throw ImportError.missingEnvelopeIdentity(field: "DID")
        }

        let nExp = ContentService.normalizeHandle(exp)
        let nFound = ContentService.normalizeHandle(found)
        if nExp != nFound {
            throw ImportError.handleMismatch(expected: nExp, found: found)
        }
        if expDid.lowercased() != foundDid.lowercased() {
            throw ImportError.didMismatch(expected: expDid, found: foundDid)
        }

        var out: [ContentItem] = []
        out.reserveCapacity(env.items.count)
        for row in env.items {
            out.append(try row.makeContentItem(expectedDid: expDid))
        }
        return DecodeOutcome(
            items: out,
            skippedLikeRepostWithoutDeletionURI: 0,
            envelopeHandle: env.handle,
            envelopeDid: env.did
        )
    }

    private static func validateDeletionURI(
        _ uri: String?,
        expectedDid: String,
        expectedCollection: ATProtoRecordCollection
    ) throws {
        guard let uri, uri.hasPrefix("at://") else {
            throw ImportError.unsafeDeletionURI(uri: uri, reason: "missing or malformed at:// URI")
        }
        let parts = uri.dropFirst("at://".count).split(
            separator: "/",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        guard parts.count == 3,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              !parts[2].isEmpty else {
            throw ImportError.unsafeDeletionURI(uri: uri, reason: "expected at://did/collection/rkey")
        }
        guard String(parts[0]) == expectedDid else {
            throw ImportError.unsafeDeletionURI(uri: uri, reason: "record belongs to another repository")
        }
        guard String(parts[1]) == expectedCollection.rawValue else {
            throw ImportError.unsafeDeletionURI(uri: uri, reason: "record collection does not match content type")
        }
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
