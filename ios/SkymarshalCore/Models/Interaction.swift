import Foundation

/// One interaction between the user and another account, in either
/// direction. Outgoing interactions come from the user's cached
/// content (free); incoming interactions come from a network sweep
/// of the target's archive.
public struct Interaction: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: Kind
    public let direction: Direction
    public let timestamp: Date?
    /// `at://` URI of the post the interaction is about. For
    /// outgoing replies, this is the parent (the target's post).
    /// For outgoing likes/reposts, this is the post the user liked
    /// or reposted (which the target authored).
    /// For incoming replies, this is the user's post the target
    /// replied to.
    /// For incoming likes/reposts, this is the user's post that
    /// was liked or reposted.
    public let subjectURI: String
    /// First few words of the subject post, when we have it. Lets
    /// the row show context without an extra fetch.
    public let subjectText: String?
    /// at:// URI of the user's reply / like / repost record (for
    /// outgoing). Lets the UI offer "View on Bluesky" or "Delete"
    /// against the user's own action. Nil for incoming.
    public let actorRecordURI: String?

    public enum Kind: String, Sendable, Hashable, Codable {
        case like, reply, repost
    }

    public enum Direction: String, Sendable, Hashable, Codable {
        case outgoing, incoming
    }

    public init(
        kind: Kind,
        direction: Direction,
        subjectURI: String,
        subjectText: String? = nil,
        timestamp: Date? = nil,
        actorRecordURI: String? = nil
    ) {
        self.kind = kind
        self.direction = direction
        self.subjectURI = subjectURI
        self.subjectText = subjectText
        self.timestamp = timestamp
        self.actorRecordURI = actorRecordURI
        // Synthesize a stable id from the parts that uniquely
        // identify this interaction. Avoids collisions when the
        // same subject URI appears in both directions or with
        // different kinds.
        self.id = "\(direction.rawValue)|\(kind.rawValue)|\(subjectURI)|\(actorRecordURI ?? "")"
    }
}

/// What loadInteractions returns. Includes both directions and
/// completion flags so the UI knows whether to offer "Load more"
/// in either section.
public struct InteractionBundle: Sendable {
    public let target: BskyProfile
    public let outgoing: [Interaction]
    public let incoming: [Interaction]
    /// True when the outgoing scan was complete (always true today
    /// — outgoing is just a filter over the cached `loaded` items).
    public let outgoingComplete: Bool
    /// False if the incoming sweep hit the page cap before reaching
    /// the end of the target's recent archive — surface a hint in
    /// the UI ("showing the most recent N items").
    public let incomingComplete: Bool

    public init(
        target: BskyProfile,
        outgoing: [Interaction],
        incoming: [Interaction],
        outgoingComplete: Bool = true,
        incomingComplete: Bool = true
    ) {
        self.target = target
        self.outgoing = outgoing
        self.incoming = incoming
        self.outgoingComplete = outgoingComplete
        self.incomingComplete = incomingComplete
    }
}

/// Reported during loadInteractions so the UI can show "Checking
/// their replies… 3 found" while the network sweep runs.
public struct InteractionProgress: Sendable, Hashable {
    public let phase: Phase
    public let itemsFound: Int
    public let message: String

    public init(phase: Phase, itemsFound: Int, message: String) {
        self.phase = phase
        self.itemsFound = itemsFound
        self.message = message
    }

    public enum Phase: String, Sendable, Hashable {
        case outgoing
        case incomingFeed
        case incomingLikes
        case complete
    }
}
