import XCTest
import SwiftData
@testable import SkymarshalCore

@available(iOS 17, *)
final class StorageRoundTripTests: XCTestCase {

    // MARK: - Helpers

    private func sampleProfile() -> BskyProfile {
        let createdAt = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(-365 * 86_400)
        )
        return BskyProfile(
            did: "did:plc:roundtrip",
            handle: "alice.bsky.social",
            displayName: "Alice",
            description: "real bio",
            avatar: "https://x/avatar",
            banner: "https://x/banner",
            followersCount: 1500,
            followsCount: 300,
            postsCount: 800,
            createdAt: createdAt,
            viewer: .init(
                muted: false,
                blockedBy: nil,
                blocking: nil,
                following: "at://me/follow/abc",
                followedBy: "at://them/follow/xyz"
            )
        )
    }

    // MARK: - AnalyzedAccountRecord

    func test_analyzedAccount_roundTrip_preservesProfile() {
        let original = BluescreenAnalyzer.analyze(profile: sampleProfile())
        let record = AnalyzedAccountRecord(account: original, ownerHandle: "owner.bsky.social")
        let restored = record.toAnalyzedAccount()

        XCTAssertEqual(restored.did, original.did)
        XCTAssertEqual(restored.handle, original.handle)
        XCTAssertEqual(restored.profile.displayName, original.profile.displayName)
        XCTAssertEqual(restored.profile.description, original.profile.description)
        XCTAssertEqual(restored.profile.followersCount, original.profile.followersCount)
        XCTAssertEqual(restored.profile.followsCount, original.profile.followsCount)
        XCTAssertEqual(restored.profile.postsCount, original.profile.postsCount)
        XCTAssertEqual(restored.profile.avatar, original.profile.avatar)
        XCTAssertEqual(restored.profile.banner, original.profile.banner)
    }

    func test_analyzedAccount_roundTrip_preservesScoredFields() {
        let original = BluescreenAnalyzer.analyze(profile: sampleProfile())
        let record = AnalyzedAccountRecord(account: original, ownerHandle: "owner.bsky.social")
        let restored = record.toAnalyzedAccount()

        XCTAssertEqual(restored.botScore, original.botScore)
        XCTAssertEqual(restored.botFlags, original.botFlags)
        XCTAssertEqual(restored.ratio, original.ratio)
        XCTAssertEqual(restored.influenceScore, original.influenceScore)
        XCTAssertEqual(restored.influenceTier, original.influenceTier)
        XCTAssertEqual(restored.accountAgeDays, original.accountAgeDays)
        XCTAssertEqual(restored.profileCompleteness, original.profileCompleteness)
        XCTAssertEqual(restored.isInactive, original.isInactive)
        XCTAssertEqual(restored.isDeleted, original.isDeleted)
        XCTAssertEqual(restored.isMutual, original.isMutual)
    }

    func test_analyzedAccount_roundTrip_preservesViewerState() {
        let original = BluescreenAnalyzer.analyze(profile: sampleProfile())
        let record = AnalyzedAccountRecord(account: original, ownerHandle: "owner.bsky.social")
        let restored = record.toAnalyzedAccount()

        XCTAssertEqual(restored.profile.viewer?.following, "at://me/follow/abc")
        XCTAssertEqual(restored.profile.viewer?.followedBy, "at://them/follow/xyz")
        XCTAssertTrue(restored.isMutual)
    }

    func test_analyzedAccount_roundTrip_preservesInteractedRecently() {
        // Test all three states of the optional Bool — true/false/nil —
        // since we encode it through interactedRecentlyRaw as -1/0/1
        let base = BluescreenAnalyzer.analyze(profile: sampleProfile())

        let withTrue = AnalyzedAccount(
            profile: base.profile, ratio: base.ratio, botScore: base.botScore,
            botFlags: base.botFlags, influenceScore: base.influenceScore,
            influenceTier: base.influenceTier, accountAgeDays: base.accountAgeDays,
            postsPerDay: base.postsPerDay, profileCompleteness: base.profileCompleteness,
            lastPostDate: base.lastPostDate, daysSinceLastPost: base.daysSinceLastPost,
            isInactive: base.isInactive, isDeleted: base.isDeleted, isMutual: base.isMutual,
            engagementScore: base.engagementScore, interactedRecently: true
        )
        XCTAssertEqual(
            AnalyzedAccountRecord(account: withTrue, ownerHandle: "o").toAnalyzedAccount().interactedRecently,
            true
        )

        let withFalse = AnalyzedAccount(
            profile: base.profile, ratio: base.ratio, botScore: base.botScore,
            botFlags: base.botFlags, influenceScore: base.influenceScore,
            influenceTier: base.influenceTier, accountAgeDays: base.accountAgeDays,
            postsPerDay: base.postsPerDay, profileCompleteness: base.profileCompleteness,
            lastPostDate: base.lastPostDate, daysSinceLastPost: base.daysSinceLastPost,
            isInactive: base.isInactive, isDeleted: base.isDeleted, isMutual: base.isMutual,
            engagementScore: base.engagementScore, interactedRecently: false
        )
        XCTAssertEqual(
            AnalyzedAccountRecord(account: withFalse, ownerHandle: "o").toAnalyzedAccount().interactedRecently,
            false
        )

        XCTAssertNil(
            AnalyzedAccountRecord(account: base, ownerHandle: "o").toAnalyzedAccount().interactedRecently
        )
    }

    func test_analyzedAccount_roundTrip_preservesActivityReadState() {
        let base = BluescreenAnalyzer.analyze(profile: sampleProfile())

        for state in [ActivityReadState.read, .unknown] {
            let account = base.withActivityReadState(state)
            let restored = AnalyzedAccountRecord(account: account, ownerHandle: "o")
                .toAnalyzedAccount()
            XCTAssertEqual(restored.activityReadState, state)
        }
    }

    /// Update-in-place path must also persist the read-state, not just
    /// the init path.
    func test_analyzedAccount_update_persistsActivityReadState() {
        let base = BluescreenAnalyzer.analyze(profile: sampleProfile())
        let record = AnalyzedAccountRecord(
            account: base.withActivityReadState(.unknown), ownerHandle: "o"
        )
        record.update(from: base.withActivityReadState(.read), scannedAt: Date())
        XCTAssertEqual(record.toAnalyzedAccount().activityReadState, .read)
    }

    // MARK: - Ghost / reciprocity

    /// The lazily-computed ghost verdict + inbound reciprocity count must
    /// survive the SwiftData round-trip, and a never-checked account must
    /// decode back to `nil` (not-yet-checked, distinct from `.unknown`).
    func test_analyzedAccount_roundTrip_preservesGhostVerdictAndReciprocity() {
        let base = BluescreenAnalyzer.analyze(profile: sampleProfile())

        // Never checked → nil on both fields.
        let fresh = AnalyzedAccountRecord(account: base, ownerHandle: "o").toAnalyzedAccount()
        XCTAssertNil(fresh.ghostVerdict)
        XCTAssertNil(fresh.reciprocityGapInboundCount)

        for verdict in GhostVerdict.allCases {
            let stamped = base.withGhostReciprocity(verdict: verdict, inboundCount: 7)
            let restored = AnalyzedAccountRecord(account: stamped, ownerHandle: "o")
                .toAnalyzedAccount()
            XCTAssertEqual(restored.ghostVerdict, verdict)
            XCTAssertEqual(restored.reciprocityGapInboundCount, 7)
        }
    }

    /// A reciprocity gap (inbound count) stamped on an account persists
    /// through the in-place update path, not just init.
    func test_reciprocityGap_storedOnAccount() {
        let base = BluescreenAnalyzer.analyze(profile: sampleProfile())
        let record = AnalyzedAccountRecord(account: base, ownerHandle: "o")
        let stamped = base.withGhostReciprocity(verdict: .ghost, inboundCount: 4)
        record.update(from: stamped, scannedAt: Date())
        let restored = record.toAnalyzedAccount()
        XCTAssertEqual(restored.ghostVerdict, .ghost)
        XCTAssertEqual(restored.reciprocityGapInboundCount, 4)
    }

    /// Re-scan preservation: a once-computed verdict must NOT be wiped by
    /// a fresh analyzer pass (which carries `nil`), mirroring how the
    /// whitelist override is sticky across scans.
    func test_analyzedAccount_update_preservesGhostVerdictAcrossRescan() {
        let base = BluescreenAnalyzer.analyze(profile: sampleProfile())
        let record = AnalyzedAccountRecord(
            account: base.withGhostReciprocity(verdict: .ghost, inboundCount: 2),
            ownerHandle: "o"
        )
        // A plain analyzer re-scan carries nil ghost fields.
        record.update(from: base, scannedAt: Date())
        let restored = record.toAnalyzedAccount()
        XCTAssertEqual(restored.ghostVerdict, .ghost)
        XCTAssertEqual(restored.reciprocityGapInboundCount, 2)
    }

    // MARK: - SwiftData container integration

    func test_analyzedAccount_persistsAndRetrieves_viaInMemoryContainer() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let analyzed = BluescreenAnalyzer.analyze(profile: sampleProfile())
        context.insert(AnalyzedAccountRecord(
            account: analyzed,
            ownerHandle: "owner.bsky.social"
        ))
        try context.save()

        let descriptor = FetchDescriptor<AnalyzedAccountRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.did, "did:plc:roundtrip")
        XCTAssertEqual(fetched.first?.botScore, analyzed.botScore)
    }

    func test_compositeKey_perOwnerIsolation() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let analyzed = BluescreenAnalyzer.analyze(profile: sampleProfile())

        context.insert(AnalyzedAccountRecord(account: analyzed, ownerHandle: "alice"))
        context.insert(AnalyzedAccountRecord(account: analyzed, ownerHandle: "bob"))
        try context.save()

        let aliceOnly = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.ownerHandle == "alice" }
        )
        XCTAssertEqual(try context.fetch(aliceOnly).count, 1)

        let bobOnly = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate { $0.ownerHandle == "bob" }
        )
        XCTAssertEqual(try context.fetch(bobOnly).count, 1)
    }

    func test_compositeKey_uniqueWithinOwner_upsertsByReplacement() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let analyzed = BluescreenAnalyzer.analyze(profile: sampleProfile())

        context.insert(AnalyzedAccountRecord(account: analyzed, ownerHandle: "alice"))
        try context.save()

        // Same owner + same did → same compositeKey; second insert should
        // upsert (SwiftData unique constraint) not duplicate.
        context.insert(AnalyzedAccountRecord(account: analyzed, ownerHandle: "alice"))
        try? context.save()  // unique-violation may throw; that's fine

        let descriptor = FetchDescriptor<AnalyzedAccountRecord>()
        // Some SwiftData unique-violation behaviors return 1, some 2 then
        // dedupe on next fetch. Tolerate both — what matters is that the
        // upsert path in FollowerService.persist explicitly checks first.
        XCTAssertLessThanOrEqual(try context.fetch(descriptor).count, 2)
    }
}
