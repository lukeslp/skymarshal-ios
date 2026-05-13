import Foundation
import SwiftData

// MARK: - File purpose
// Writes lightweight ``GraphSnapshotRecord`` rows from in-memory content
// and follower scan so the Scope tab can read persisted summaries.

@available(iOS 17, *)
public enum GraphSnapshotWriter: Sendable {

    /// Replaces prior snapshots for each ``GraphSnapshotKind`` for this owner.
    public static func syncLocalSummaries(
        context: ModelContext,
        ownerHandle: String,
        items: [ContentItem],
        accounts: [AnalyzedAccount]
    ) throws {
        for kind in GraphSnapshotKind.allCases {
            try deleteSnapshot(context: context, owner: ownerHandle, kind: kind)
        }

        let replyWithParent = items.filter { $0.contentType == .replies && $0.parentReplyURI != nil }.count
        let likes = items.filter { $0.contentType == .likes }.count
        let reposts = items.filter { $0.contentType == .reposts }.count
        let posts = items.filter { $0.contentType == .posts }.count

        let interactionPayload: [String: Int] = [
            "replyWithParent": replyWithParent,
            "likes": likes,
            "reposts": reposts,
            "posts": posts,
            "totalItems": items.count,
        ]
        context.insert(GraphSnapshotRecord(
            ownerHandle: ownerHandle,
            kind: .interactionGraph,
            completeness: items.isEmpty ? .unknown : .partial,
            summaryJSON: try encodeJSONObject(interactionPayload)
        ))

        let accountPayload: [String: Int] = [
            "accounts": accounts.count,
            "topFollowersMax": accounts.map(\.profile.followersCount).max() ?? 0,
        ]
        context.insert(GraphSnapshotRecord(
            ownerHandle: ownerHandle,
            kind: .accountGraph,
            completeness: accounts.isEmpty ? .unknown : .partial,
            summaryJSON: try encodeJSONObject(accountPayload)
        ))

        let heat = AnalyticsService.buildSnapshot(from: items)
        let heatPayload = HeatmapExport(postsByHourLocal: heat.postsByHourLocal, postsByWeekday: heat.postsByWeekday)
        context.insert(GraphSnapshotRecord(
            ownerHandle: ownerHandle,
            kind: .timelineHeatmap,
            completeness: items.isEmpty ? .unknown : .partial,
            summaryJSON: try encodeJSONObject(heatPayload)
        ))

        context.insert(GraphSnapshotRecord(
            ownerHandle: ownerHandle,
            kind: .postGraph,
            completeness: .unknown,
            summaryJSON: #"{"state":"not_materialized"}"#
        ))

        try context.save()
    }

    private static func deleteSnapshot(
        context: ModelContext,
        owner: String,
        kind: GraphSnapshotKind
    ) throws {
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<GraphSnapshotRecord>(
            predicate: #Predicate { $0.ownerHandle == owner && $0.kindRaw == kindRaw }
        )
        for row in (try? context.fetch(descriptor)) ?? [] {
            context.delete(row)
        }
    }

    private struct HeatmapExport: Encodable {
        let postsByHour: [Int]
        let postsByWeekday: [Int]
        init(postsByHourLocal: [Int], postsByWeekday: [Int]) {
            self.postsByHour = postsByHourLocal
            self.postsByWeekday = postsByWeekday
        }
    }

    private static func encodeJSONObject(_ enc: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(enc)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
