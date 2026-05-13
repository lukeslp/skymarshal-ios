import Foundation

// MARK: - File purpose
// Computes the exact delete scope from a list of item IDs against loaded
// content — same resolution rules as ``ContentService/delete(itemIDs:)``
// so UI can show counts and URIs before any XRPC write.

/// Outcome of resolving item IDs to deletable records (no network).
public struct DeletePreflightSummary: Sendable, Equatable {
    /// Items that will be sent to ``ATProtoClient/deleteRecord(uri:)``.
    public let itemsToDelete: [ContentItem]
    /// Human-readable reasons for IDs that could not be resolved.
    public let resolutionErrors: [String]

    public var deletionURIs: [String] {
        itemsToDelete.compactMap(\.deletionURI)
    }

    public var countByContentType: [ContentType: Int] {
        var m: [ContentType: Int] = [:]
        for item in itemsToDelete {
            m[item.contentType, default: 0] += 1
        }
        return m
    }

    public var totalCount: Int { itemsToDelete.count }

    public init(itemsToDelete: [ContentItem], resolutionErrors: [String]) {
        self.itemsToDelete = itemsToDelete
        self.resolutionErrors = resolutionErrors
    }
}

/// Builds delete preflight summaries using the same ID resolution as the delete loop.
public enum DeletePreflight: Sendable {

    /// Resolves `itemIDs` (``ContentItem/id`` or raw `uri`) against `loadedContent`
    /// in stable order — first match wins per ID, mirroring ``ContentService/delete``.
    public static func summarize(
        itemIDs: [String],
        loadedContent: [ContentItem]
    ) -> DeletePreflightSummary {
        var itemsToDelete: [ContentItem] = []
        var errors: [String] = []

        for id in itemIDs {
            guard let item = loadedContent.first(where: { $0.id == id || $0.uri == id }) else {
                errors.append("\(id): not in loaded content")
                continue
            }
            guard item.deletionURI != nil else {
                errors.append("\(item.uri): no deletable \(item.contentType.label.lowercased()) record")
                continue
            }
            itemsToDelete.append(item)
        }

        return DeletePreflightSummary(itemsToDelete: itemsToDelete, resolutionErrors: errors)
    }
}
