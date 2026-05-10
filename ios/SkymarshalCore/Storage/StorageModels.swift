import Foundation
import SwiftData

/// SwiftData @Model definitions for the three MVP tables. Mirror the
/// IndexedDB stores in `reference/web/skymarshal/database/schema.ts`
/// (`contentItems`, `engagementCache`, `userSettings`). The other five
/// stores (`searchHistory`, `backups`, `carFiles`, `bookmarks`,
/// `growthSnapshots`) are intentionally skipped for the MVP.

@available(iOS 17, *)
@Model
public final class ContentItemRecord {
    @Attribute(.unique) public var uri: String
    public var cid: String
    public var contentTypeRaw: String
    public var text: String?
    public var createdAt: Date?
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var hasMedia: Bool
    public var ownerHandle: String

    public init(
        uri: String,
        cid: String,
        contentType: ContentType,
        text: String? = nil,
        createdAt: Date? = nil,
        likeCount: Int = 0,
        repostCount: Int = 0,
        replyCount: Int = 0,
        hasMedia: Bool = false,
        ownerHandle: String
    ) {
        self.uri = uri
        self.cid = cid
        self.contentTypeRaw = contentType.rawValue
        self.text = text
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.hasMedia = hasMedia
        self.ownerHandle = ownerHandle
    }

    public var contentType: ContentType {
        ContentType(rawValue: contentTypeRaw) ?? .posts
    }

    public func toContentItem() -> ContentItem {
        ContentItem(
            uri: uri,
            cid: cid,
            contentType: contentType,
            text: text,
            createdAt: createdAt,
            likeCount: likeCount,
            repostCount: repostCount,
            replyCount: replyCount,
            hasMedia: hasMedia
        )
    }
}

@available(iOS 17, *)
@Model
public final class EngagementCacheRecord {
    @Attribute(.unique) public var uri: String
    public var likeCount: Int
    public var repostCount: Int
    public var replyCount: Int
    public var cachedAt: Date
    public var ttlSeconds: TimeInterval

    public init(
        uri: String,
        likeCount: Int,
        repostCount: Int,
        replyCount: Int,
        cachedAt: Date = Date(),
        ttlSeconds: TimeInterval
    ) {
        self.uri = uri
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.cachedAt = cachedAt
        self.ttlSeconds = ttlSeconds
    }

    public var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > ttlSeconds
    }
}

@available(iOS 17, *)
@Model
public final class UserSettingsRecord {
    @Attribute(.unique) public var handle: String
    public var downloadLimitDefault: Int
    public var batchSize: Int
    public var fetchOrderRaw: String
    public var lastSessionAccessJwt: String?
    public var lastSessionRefreshJwt: String?
    public var lastSessionDid: String?

    public init(
        handle: String,
        downloadLimitDefault: Int = 500,
        batchSize: Int = 100,
        fetchOrder: String = "newest",
        lastSessionAccessJwt: String? = nil,
        lastSessionRefreshJwt: String? = nil,
        lastSessionDid: String? = nil
    ) {
        self.handle = handle
        self.downloadLimitDefault = downloadLimitDefault
        self.batchSize = batchSize
        self.fetchOrderRaw = fetchOrder
        self.lastSessionAccessJwt = lastSessionAccessJwt
        self.lastSessionRefreshJwt = lastSessionRefreshJwt
        self.lastSessionDid = lastSessionDid
    }
}

/// SwiftData container factory for the app and tests.
@available(iOS 17, *)
public enum SkymarshalSchema {
    public static let allModels: [any PersistentModel.Type] = [
        ContentItemRecord.self,
        EngagementCacheRecord.self,
        UserSettingsRecord.self,
    ]

    public static func makeContainer(
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
