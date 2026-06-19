import Foundation

/// Conservative follow-hygiene engine: engaged-audience, ghost detection,
/// and reciprocity, computed only from the AppView endpoints the app
/// already uses (`getLikes`, `getRepostedBy`, `getActorLikes`,
/// `getAuthorFeed`). No new network surface — this stays inside the
/// privacy posture Option B commits to.
///
/// Every signal is **fail-safe**: a throttled or gated read produces an
/// `.unknown` read-state and the candidate is excluded from any
/// destructive bucket rather than guessed at. An empty read for an
/// account whose profile reports activity is treated as `.unknown`, not
/// "they never engaged you" — the core bug this engine avoids.
@available(iOS 17, *)
public actor EngagementEngine {

    private let client: ATProtoClient

    public init(client: ATProtoClient) {
        self.client = client
    }

    // MARK: - Result types

    /// DIDs that liked or reposted the user's recent posts — the people
    /// actually paying attention. Keyed by DID with a hit count so the
    /// caller can rank by intensity.
    public struct EngagedAudience: Sendable {
        public let countsByDID: [String: Int]
        /// Whether the audience read was reliable across the sampled
        /// posts. `.unknown` when throttling truncated the sweep — ghost
        /// detection downstream must not treat a thin engaged set as
        /// ground truth.
        public let readState: ActivityReadState

        public init(countsByDID: [String: Int], readState: ActivityReadState) {
            self.countsByDID = countsByDID
            self.readState = readState
        }

        public var engagedDIDs: Set<String> { Set(countsByDID.keys) }
    }

    /// One follow classified against the engaged set + a source-side
    /// verification of their own activity toward the user.
    public struct GhostVerdict: Sendable, Hashable {
        public enum Classification: String, Sendable, Hashable {
            /// Source-side read confirmed: they never engaged the user.
            case confirmedGhost
            /// They DID engage (engaged set or source-side hit) — not a ghost.
            case engaged
            /// Read was unreliable (throttle/gate) — excluded from any
            /// destructive action by fail-safe.
            case unknown
        }

        public let did: String
        public let classification: Classification

        public init(did: String, classification: Classification) {
            self.did = did
            self.classification = classification
        }
    }

    /// A "they engage you, you don't reciprocate" gap.
    public struct ReciprocityGap: Sendable, Hashable {
        public let did: String
        /// How many times they engaged the user (inbound).
        public let inboundCount: Int
        /// Whether the user engaged them at all (outbound).
        public let userReciprocates: Bool

        public init(did: String, inboundCount: Int, userReciprocates: Bool) {
            self.did = did
            self.inboundCount = inboundCount
            self.userReciprocates = userReciprocates
        }
    }

    // MARK: - Engaged audience

    /// Build the engaged set from the likers + reposters of the user's
    /// recent post URIs. Each `getLikes` / `getRepostedBy` call is
    /// throttle-wrapped; a throttle on any post taints the read-state to
    /// `.unknown` but the partial counts are still returned (the caller
    /// decides how much to trust them).
    ///
    /// - Parameter userPostURIs: the user's recent post `at://` URIs
    ///   (cheapest source: the user's cached content items).
    public func engagedAudience(
        userPostURIs: [String],
        maxPosts: Int = 100
    ) async -> EngagedAudience {
        var counts: [String: Int] = [:]
        var readState: ActivityReadState = .read

        for uri in userPostURIs.prefix(maxPosts) {
            if Task.isCancelled { break }
            do {
                let likes = try await RateLimit.withBackoff {
                    try await self.client.getLikes(uri: uri, limit: 100, cursor: nil)
                }
                for like in likes.likes {
                    counts[like.actor.did, default: 0] += 1
                }
            } catch {
                if RateLimit.isRateLimit(error) { readState = .unknown }
            }
            do {
                let reposts = try await RateLimit.withBackoff {
                    try await self.client.getRepostedBy(uri: uri, limit: 100, cursor: nil)
                }
                for profile in reposts.repostedBy {
                    counts[profile.did, default: 0] += 1
                }
            } catch {
                if RateLimit.isRateLimit(error) { readState = .unknown }
            }
        }

        return EngagedAudience(countsByDID: counts, readState: readState)
    }

    // MARK: - Ghost detection

    /// Classify a candidate follow. First cheap pass: if they're in the
    /// engaged set, they're `engaged`. Otherwise do a source-side verify
    /// — read THEIR own likes (`getActorLikes`) and look for any like on
    /// one of the user's posts. Zero hits with a clean read =
    /// `confirmedGhost`; any hit = `engaged` (the audience window missed
    /// them); a throttled read = `unknown` (fail-safe excluded).
    ///
    /// - Parameters:
    ///   - candidateDID: the follow being checked.
    ///   - engagedDIDs: the precomputed engaged set (cheap short-circuit).
    ///   - userPostURIPrefix: `at://{userDID}/` — matches any record the
    ///     candidate aimed at the user.
    ///   - candidatePostsCount: the candidate's profile `postsCount`,
    ///     used to disambiguate a genuinely-empty read from a gated one.
    public func verifyGhost(
        candidateDID: String,
        engagedDIDs: Set<String>,
        userPostURIPrefix: String,
        candidatePostsCount: Int,
        cap: Int = 200
    ) async -> GhostVerdict {
        if engagedDIDs.contains(candidateDID) {
            return GhostVerdict(did: candidateDID, classification: .engaged)
        }

        var cursor: String? = nil
        var examined = 0
        var sawAny = false

        while examined < cap {
            if Task.isCancelled {
                return GhostVerdict(did: candidateDID, classification: .unknown)
            }
            let pageCursor = cursor
            let response: LikesResponse
            do {
                response = try await RateLimit.withBackoff {
                    try await self.client.getActorLikes(
                        actor: candidateDID, limit: 100, cursor: pageCursor
                    )
                }
            } catch {
                // Throttle or any read failure → fail-safe unknown.
                return GhostVerdict(did: candidateDID, classification: .unknown)
            }

            for view in response.feed {
                examined += 1
                sawAny = true
                if view.post.uri.hasPrefix(userPostURIPrefix) {
                    return GhostVerdict(did: candidateDID, classification: .engaged)
                }
            }

            cursor = response.cursor
            if cursor == nil { break }
        }

        // Empty read for an account whose profile claims posts/likes
        // exist is the gate/throttle signature, not a confirmed ghost.
        if !sawAny && candidatePostsCount > 0 {
            return GhostVerdict(did: candidateDID, classification: .unknown)
        }
        return GhostVerdict(did: candidateDID, classification: .confirmedGhost)
    }

    /// One-account verdict for the lazy AccountDetailView read. Returns
    /// the verdict **and** the inbound engagement count (how many of the
    /// candidate's likes pointed at the user's posts), gathered from the
    /// same single capped `getActorLikes` sweep — no extra calls.
    ///
    /// This is the cheap user-initiated path the detail view calls on
    /// open: one membership check against the precomputed `engagedDIDs`
    /// short-circuit, then at most `cap / 100` PDS pages (default cap
    /// 200 = ≤ 2 pages, well under the 15-call/account budget). When the
    /// candidate is already in the engaged set we can't recover an exact
    /// count without the sweep, so we report `1` (they engage you) and
    /// skip the network entirely.
    public func verifyGhostWithInbound(
        candidateDID: String,
        engagedDIDs: Set<String>,
        userPostURIPrefix: String,
        candidatePostsCount: Int,
        cap: Int = 200
    ) async -> (verdict: GhostVerdict, inboundCount: Int) {
        if engagedDIDs.contains(candidateDID) {
            return (GhostVerdict(did: candidateDID, classification: .engaged), 1)
        }

        var cursor: String? = nil
        var examined = 0
        var sawAny = false
        var inbound = 0

        while examined < cap {
            if Task.isCancelled {
                return (GhostVerdict(did: candidateDID, classification: .unknown), 0)
            }
            let pageCursor = cursor
            let response: LikesResponse
            do {
                response = try await RateLimit.withBackoff {
                    try await self.client.getActorLikes(
                        actor: candidateDID, limit: 100, cursor: pageCursor
                    )
                }
            } catch {
                return (GhostVerdict(did: candidateDID, classification: .unknown), 0)
            }

            for view in response.feed {
                examined += 1
                sawAny = true
                if view.post.uri.hasPrefix(userPostURIPrefix) {
                    inbound += 1
                }
            }

            cursor = response.cursor
            if cursor == nil { break }
        }

        if inbound > 0 {
            return (GhostVerdict(did: candidateDID, classification: .engaged), inbound)
        }
        if !sawAny && candidatePostsCount > 0 {
            return (GhostVerdict(did: candidateDID, classification: .unknown), 0)
        }
        return (GhostVerdict(did: candidateDID, classification: .confirmedGhost), 0)
    }

    // MARK: - Reciprocity

    /// Compute reciprocity gaps. `inbound` is who engaged the user and
    /// how much (from interaction sweeps the caller already ran);
    /// `outboundDIDs` is who the user engaged (parsed from the user's own
    /// likes/reposts/replies). A gap is an account the user does NOT
    /// engage back despite ≥ `minInbound` inbound interactions.
    public nonisolated static func reciprocityGaps(
        inbound: [String: Int],
        outboundDIDs: Set<String>,
        minInbound: Int = 2
    ) -> [ReciprocityGap] {
        inbound.compactMap { did, count -> ReciprocityGap? in
            guard count >= minInbound else { return nil }
            let reciprocates = outboundDIDs.contains(did)
            guard !reciprocates else { return nil }
            return ReciprocityGap(
                did: did,
                inboundCount: count,
                userReciprocates: false
            )
        }
        .sorted { $0.inboundCount > $1.inboundCount }
    }

    /// Parse the DIDs the user engages from their own cached content —
    /// the authors of posts the user liked / reposted, and the parents
    /// of the user's replies. Pure: no network. `did_from_uri` mirror.
    public nonisolated static func outboundEngagedDIDs(
        from userItems: [ContentItem]
    ) -> Set<String> {
        var dids = Set<String>()
        for item in userItems {
            switch item.contentType {
            case .likes, .reposts:
                if let did = didFromURI(item.uri) { dids.insert(did) }
            case .replies:
                if let parent = item.parentReplyURI, let did = didFromURI(parent) {
                    dids.insert(did)
                }
            case .posts, .all:
                continue
            }
        }
        return dids
    }

    /// Extract the repo DID from an `at://did/collection/rkey` URI.
    nonisolated static func didFromURI(_ uri: String) -> String? {
        guard uri.hasPrefix("at://") else { return nil }
        let body = uri.dropFirst("at://".count)
        let did = body.prefix { $0 != "/" }
        return did.isEmpty ? nil : String(did)
    }
}
