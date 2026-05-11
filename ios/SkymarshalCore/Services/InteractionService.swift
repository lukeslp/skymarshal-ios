import Foundation

/// Two-direction interaction sweep between the user and another
/// account. Outgoing direction is free (filtered from the user's
/// cached content). Incoming direction walks the target's recent
/// archive once (capped at 200 items per pass) and looks for
/// items pointing at the user.
@available(iOS 17, *)
public actor InteractionService {

    private let client: ATProtoClient
    /// Per-pass page cap that the UI passes in via the `cap` param on
    /// `loadInteractions`. Default 200 → ~10s wall-clock on each
    /// incoming pass. Power-user "Deep sweep" raises this to 2000 →
    /// ~30s. Read endpoint isn't rate-limited the way write is, so the
    /// only cost of raising the cap is wall-clock and a few hundred KB
    /// of `Interaction` structs in memory.
    public static let defaultPageCap = 200
    public static let deepSweepPageCap = 2000

    public init(client: ATProtoClient) {
        self.client = client
    }

    public func loadInteractions(
        userDID: String,
        userItems: [ContentItem],
        targetDID: String,
        targetHandle: String,
        cap: Int = InteractionService.defaultPageCap,
        progress: (@Sendable (InteractionProgress) async -> Void)? = nil
    ) async throws -> InteractionBundle {
        // Resolve target profile up front so the sheet has a header
        // even if both sweeps return zero.
        let targetProfile = (try? await client.getProfile(actor: targetDID))
            ?? BskyProfile(did: targetDID, handle: targetHandle)

        // Phase 1 — outgoing (free, no network)
        let outgoing = Self.filterOutgoing(items: userItems, targetDID: targetDID)
        await progress?(InteractionProgress(
            phase: .outgoing,
            itemsFound: outgoing.count,
            message: "Found \(outgoing.count) interaction\(outgoing.count == 1 ? "" : "s") from you"
        ))

        // User's own DID prefix for incoming-direction matching.
        let userPrefix = "at://\(userDID)/"

        // Phase 2 — incoming via target's getAuthorFeed
        var incoming: [Interaction] = []
        var feedComplete = true
        do {
            let (replies, reposts, complete) = try await sweepIncomingFeed(
                targetDID: targetDID,
                userPrefix: userPrefix,
                cap: cap,
                progress: progress
            )
            incoming.append(contentsOf: replies)
            incoming.append(contentsOf: reposts)
            feedComplete = complete
        } catch {
            // Soft-fail on this pass — incoming likes pass might
            // still succeed and contribute partial data.
            feedComplete = false
        }

        // Phase 3 — incoming likes via getActorLikes(actor: target)
        var likesComplete = true
        do {
            let (likes, complete) = try await sweepIncomingLikes(
                targetDID: targetDID,
                userPrefix: userPrefix,
                cap: cap,
                progressBaseCount: incoming.count,
                progress: progress
            )
            incoming.append(contentsOf: likes)
            likesComplete = complete
        } catch {
            likesComplete = false
        }

        await progress?(InteractionProgress(
            phase: .complete,
            itemsFound: outgoing.count + incoming.count,
            message: "Done. \(outgoing.count) from you, \(incoming.count) from them."
        ))

        return InteractionBundle(
            target: targetProfile,
            outgoing: outgoing,
            incoming: incoming,
            outgoingComplete: true,
            incomingComplete: feedComplete && likesComplete,
            examinedPerDirection: cap
        )
    }

    // MARK: - Outgoing (pure filter)

    /// Walk the user's cached items and pick out anything pointing at
    /// the target. Pure function — no actor isolation needed; exposed
    /// for unit testing.
    public nonisolated static func filterOutgoing(
        items: [ContentItem],
        targetDID: String
    ) -> [Interaction] {
        let prefix = "at://\(targetDID)/"
        return items.compactMap { item -> Interaction? in
            switch item.contentType {
            case .likes:
                guard item.uri.hasPrefix(prefix) else { return nil }
                return Interaction(
                    kind: .like,
                    direction: .outgoing,
                    subjectURI: item.uri,
                    subjectText: item.text,
                    timestamp: item.createdAt
                )
            case .reposts:
                guard item.uri.hasPrefix(prefix) else { return nil }
                return Interaction(
                    kind: .repost,
                    direction: .outgoing,
                    subjectURI: item.uri,
                    subjectText: item.text,
                    timestamp: item.createdAt
                )
            case .replies:
                guard let parent = item.parentReplyURI,
                      parent.hasPrefix(prefix) else { return nil }
                return Interaction(
                    kind: .reply,
                    direction: .outgoing,
                    subjectURI: parent,
                    subjectText: item.text,
                    timestamp: item.createdAt,
                    actorRecordURI: item.uri
                )
            case .all, .posts:
                return nil
            }
        }
    }

    // MARK: - Incoming (network sweeps)

    /// Walk target's getAuthorFeed and pull out anything pointing at the
    /// user. One sweep yields BOTH incoming replies (their replies to
    /// us) AND incoming reposts (their reposts of us) — both shapes
    /// live in the same feed response.
    private func sweepIncomingFeed(
        targetDID: String,
        userPrefix: String,
        cap: Int,
        progress: (@Sendable (InteractionProgress) async -> Void)?
    ) async throws -> ([Interaction], [Interaction], Bool) {
        var replies: [Interaction] = []
        var reposts: [Interaction] = []
        var cursor: String? = nil
        var examined = 0

        while examined < cap {
            try Task.checkCancellation()
            let response = try await client.getAuthorFeed(
                actor: targetDID,
                limit: 100,
                cursor: cursor,
                filter: "posts_with_replies"
            )

            for view in response.feed {
                examined += 1

                // Reply pointing at user
                if let parentURI = view.post.record?.reply?.parent?.uri,
                   parentURI.hasPrefix(userPrefix) {
                    replies.append(Interaction(
                        kind: .reply,
                        direction: .incoming,
                        subjectURI: parentURI,
                        subjectText: view.post.record?.text,
                        timestamp: view.post.record?.createdAt.flatMap {
                            ISO8601DateFormatter().date(from: $0)
                        },
                        actorRecordURI: view.post.uri
                    ))
                }

                // Repost where view.reason marks it AND the post URI is the user's
                if view.reason != nil, view.post.uri.hasPrefix(userPrefix) {
                    reposts.append(Interaction(
                        kind: .repost,
                        direction: .incoming,
                        subjectURI: view.post.uri,
                        subjectText: view.post.record?.text,
                        timestamp: view.reason?.indexedAt.flatMap {
                            ISO8601DateFormatter().date(from: $0)
                        }
                    ))
                }
            }

            await progress?(InteractionProgress(
                phase: .incomingFeed,
                itemsFound: replies.count + reposts.count,
                message: "Checking their feed… \(examined) items examined"
            ))

            cursor = response.cursor
            if cursor == nil { break }
        }

        let complete = cursor == nil  // false = we hit the page cap before exhausting
        return (replies, reposts, complete)
    }

    /// Walk target's getActorLikes and pick out likes on user's posts.
    private func sweepIncomingLikes(
        targetDID: String,
        userPrefix: String,
        cap: Int,
        progressBaseCount: Int,
        progress: (@Sendable (InteractionProgress) async -> Void)?
    ) async throws -> ([Interaction], Bool) {
        var likes: [Interaction] = []
        var cursor: String? = nil
        var examined = 0

        while examined < cap {
            try Task.checkCancellation()
            let response = try await client.getActorLikes(
                actor: targetDID,
                limit: 100,
                cursor: cursor
            )

            for view in response.feed {
                examined += 1
                if view.post.uri.hasPrefix(userPrefix) {
                    likes.append(Interaction(
                        kind: .like,
                        direction: .incoming,
                        subjectURI: view.post.uri,
                        subjectText: view.post.record?.text,
                        timestamp: view.post.record?.createdAt.flatMap {
                            ISO8601DateFormatter().date(from: $0)
                        }
                    ))
                }
            }

            await progress?(InteractionProgress(
                phase: .incomingLikes,
                itemsFound: progressBaseCount + likes.count,
                message: "Checking their likes… \(examined) examined"
            ))

            cursor = response.cursor
            if cursor == nil { break }
        }

        return (likes, cursor == nil)
    }
}
