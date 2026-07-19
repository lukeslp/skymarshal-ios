import Foundation

/// The full read-only payload the main app writes for the home-screen
/// widgets. The widget extension only ever *reads* this — it performs
/// no network. The app computes everything from its existing engine
/// (``AnalyzedAccount``, ``ScanSummary``, ``ContentItem``) and serializes
/// a snapshot to the shared App Group container. Keeping the widget
/// network-free preserves the privacy posture: no new hosts.
///
/// Every field is plain `Codable` value data (no live model references)
/// so the widget process can decode it without linking the network or
/// service layers.
public struct WidgetSnapshot: Codable, Hashable, Sendable {

    /// Follow-hygiene headline counts, mirrored from a bluescreen scan.
    public struct HygieneSummary: Codable, Hashable, Sendable {
        /// Confirmed ghosts: follows who never engage back.
        public let ghosts: Int
        /// Reciprocity gaps: accounts that engage you while you do not
        /// engage them back.
        public let reciprocityGaps: Int
        /// Inactive follows (no recent posting).
        public let inactive: Int
        /// Total accounts you follow (analyzed set).
        public let follows: Int
        /// Total followers.
        public let followers: Int
        /// followers / follows ratio.
        public let ratio: Double

        public init(
            ghosts: Int,
            reciprocityGaps: Int,
            inactive: Int,
            follows: Int,
            followers: Int,
            ratio: Double
        ) {
            self.ghosts = ghosts
            self.reciprocityGaps = reciprocityGaps
            self.inactive = inactive
            self.follows = follows
            self.followers = followers
            self.ratio = ratio
        }
    }

    /// One person worth replying back to: they engaged you, you have not
    /// reciprocated (or barely have).
    public struct FanNudge: Codable, Hashable, Sendable, Identifiable {
        public let handle: String
        public let displayName: String?
        /// How many times they engaged you recently.
        public let theyEngagedYou: Int
        /// Last time they interacted with you, if known.
        public let lastInteraction: Date?

        public var id: String { handle }

        public init(
            handle: String,
            displayName: String?,
            theyEngagedYou: Int,
            lastInteraction: Date?
        ) {
            self.handle = handle
            self.displayName = displayName
            self.theyEngagedYou = theyEngagedYou
            self.lastInteraction = lastInteraction
        }

        /// Name to show in a row: display name when present, else @handle.
        public var title: String {
            if let displayName, !displayName.isEmpty { return displayName }
            return "@\(handle)"
        }
    }

    /// A post of yours that is picking up engagement.
    public struct TopPost: Codable, Hashable, Sendable {
        public let text: String
        public let likeCount: Int
        public let repostCount: Int
        public let replyCount: Int
        public let indexedAt: Date

        public init(
            text: String,
            likeCount: Int,
            repostCount: Int,
            replyCount: Int,
            indexedAt: Date
        ) {
            self.text = text
            self.likeCount = likeCount
            self.repostCount = repostCount
            self.replyCount = replyCount
            self.indexedAt = indexedAt
        }
    }

    /// A recent post by someone who regularly engages with the user.
    /// The app refreshes these recommendations; the widget remains network-free.
    public struct RecommendedPost: Codable, Hashable, Sendable, Identifiable {
        public let uri: String
        public let handle: String
        public let displayName: String?
        public let text: String
        public let likeCount: Int
        public let repostCount: Int
        public let replyCount: Int
        public let indexedAt: Date
        public let authorEngagement: Int

        public var id: String { uri }
        public var authorTitle: String {
            if let displayName, !displayName.isEmpty { return displayName }
            return "@\(handle)"
        }

        public init(uri: String, handle: String, displayName: String?, text: String,
                    likeCount: Int, repostCount: Int, replyCount: Int,
                    indexedAt: Date, authorEngagement: Int) {
            self.uri = uri
            self.handle = handle
            self.displayName = displayName
            self.text = text
            self.likeCount = likeCount
            self.repostCount = repostCount
            self.replyCount = replyCount
            self.indexedAt = indexedAt
            self.authorEngagement = authorEngagement
        }
    }

    /// One day in the follower-count history sparkline.
    public struct FollowerPoint: Codable, Hashable, Sendable, Identifiable {
        public let date: Date
        public let count: Int

        public var id: Date { date }

        public init(date: Date, count: Int) {
            self.date = date
            self.count = count
        }
    }

    public let hygieneSummary: HygieneSummary
    public let peopleToEngage: [FanNudge]
    /// Optional preserves decoding of snapshots written by earlier builds.
    public let recommendedPosts: [RecommendedPost]?
    public let topPost: TopPost?
    public let followerHistory: [FollowerPoint]
    public let generatedAt: Date

    public init(
        hygieneSummary: HygieneSummary,
        peopleToEngage: [FanNudge],
        recommendedPosts: [RecommendedPost]? = nil,
        topPost: TopPost?,
        followerHistory: [FollowerPoint],
        generatedAt: Date
    ) {
        self.hygieneSummary = hygieneSummary
        self.peopleToEngage = peopleToEngage
        self.recommendedPosts = recommendedPosts
        self.topPost = topPost
        self.followerHistory = followerHistory
        self.generatedAt = generatedAt
    }
}

public extension WidgetSnapshot {
    /// Shared App Group identifier. Both the app and the widget read this.
    static let appGroupIdentifier = "group.blue.skymarshal.ios"

    /// A representative non-empty snapshot for the gallery / placeholder.
    /// Used by widget previews and the redacted gallery render so the
    /// extension never has to ship hard-coded view literals.
    static var placeholder: WidgetSnapshot {
        let now = Date()
        let history = (0..<7).reversed().map { offset in
            FollowerPoint(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now,
                count: 1180 + (6 - offset) * 12
            )
        }
        return WidgetSnapshot(
            hygieneSummary: HygieneSummary(
                ghosts: 42,
                reciprocityGaps: 17,
                inactive: 88,
                follows: 640,
                followers: 1264,
                ratio: 1.98
            ),
            peopleToEngage: [
                FanNudge(handle: "mara.bsky.social", displayName: "Mara", theyEngagedYou: 9, lastInteraction: now),
                FanNudge(handle: "devon.bsky.social", displayName: "Devon", theyEngagedYou: 6, lastInteraction: now),
                FanNudge(handle: "rio.bsky.social", displayName: "Rio", theyEngagedYou: 4, lastInteraction: now),
                FanNudge(handle: "sam.bsky.social", displayName: "Sam", theyEngagedYou: 3, lastInteraction: now)
            ],
            recommendedPosts: [
                RecommendedPost(
                    uri: "at://did:plc:example/app.bsky.feed.post/example",
                    handle: "mara.bsky.social", displayName: "Mara",
                    text: "A small idea that unexpectedly turned into a very good conversation.",
                    likeCount: 259, repostCount: 33, replyCount: 12,
                    indexedAt: now, authorEngagement: 9
                )
            ],
            topPost: TopPost(
                text: "the deploy went through on the first try and now i am suspicious",
                likeCount: 214,
                repostCount: 38,
                replyCount: 27,
                indexedAt: now
            ),
            followerHistory: history,
            generatedAt: now
        )
    }

    /// An empty snapshot used before the first scan writes real data.
    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            hygieneSummary: HygieneSummary(
                ghosts: 0, reciprocityGaps: 0, inactive: 0,
                follows: 0, followers: 0, ratio: 0
            ),
            peopleToEngage: [],
            recommendedPosts: [],
            topPost: nil,
            followerHistory: [],
            generatedAt: Date()
        )
    }
}
