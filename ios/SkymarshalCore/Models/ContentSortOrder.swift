import Foundation

/// Sort order for local content list after filters apply.
@available(iOS 17, *)
public enum ContentSortOrder: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case newestCreated
    case oldestCreated
    case highestEngagement
    case lowestEngagement

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .newestCreated:      return "Newest first"
        case .oldestCreated:      return "Oldest first"
        case .highestEngagement: return "Highest engagement"
        case .lowestEngagement:   return "Lowest engagement"
        }
    }

    public func sort(_ items: [ContentItem]) -> [ContentItem] {
        switch self {
        case .newestCreated:
            return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldestCreated:
            return items.sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
        case .highestEngagement:
            return items.sorted { $0.engagementScore > $1.engagementScore }
        case .lowestEngagement:
            return items.sorted { $0.engagementScore < $1.engagementScore }
        }
    }
}
