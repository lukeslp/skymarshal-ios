import XCTest
@testable import SkymarshalCore

/// Ghost likes — like records that exist in the user's repo but which
/// `app.bsky.feed.getActorLikes` never returns, because the liked post's author
/// was deleted or suspended.
///
/// These tests cover the ways the reconciliation could be quietly wrong rather
/// than the ways it could be obviously broken. A false positive mislabels a
/// live like; an inverted URI deletes the wrong record or nothing at all; an
/// unparsed timestamp lets an item slip past a date-scoped bulk delete.
final class GhostLikeReconciliationTests: XCTestCase {

    private func record(
        recordURI: String,
        subjectURI: String = "at://did:plc:gone/app.bsky.feed.post/abc",
        subjectCID: String = "subjectcid",
        createdAt: String? = "2026-01-02T03:04:05.123Z"
    ) -> LikeRecordsResponse.Record {
        LikeRecordsResponse.Record(
            uri: recordURI,
            cid: "recordcid",
            value: LikeRecordValue(
                subject: .init(uri: subjectURI, cid: subjectCID),
                createdAt: createdAt
            )
        )
    }

    /// The feed sweep already showed this like. Reporting it again as a ghost
    /// would double-count the archive and tell the user something false about
    /// what they cannot see.
    func test_reconcile_excludesRecordsTheFeedAlreadyReturned() {
        let uri = "at://did:plc:me/app.bsky.feed.like/1"
        let ghosts = ContentService.reconcileGhostLikes(
            records: [record(recordURI: uri)],
            hydratedDeletionURIs: [uri]
        )
        XCTAssertTrue(ghosts.isEmpty)
    }

    func test_reconcile_includesRecordsTheFeedOmitted() {
        let ghosts = ContentService.reconcileGhostLikes(
            records: [record(recordURI: "at://did:plc:me/app.bsky.feed.like/1")],
            hydratedDeletionURIs: ["at://did:plc:me/app.bsky.feed.like/OTHER"]
        )
        XCTAssertEqual(ghosts.count, 1)
        XCTAssertTrue(ghosts[0].subjectUnresolved)
        XCTAssertEqual(ghosts[0].contentType, .likes)
    }

    /// The single most dangerous way to get this wrong. `deletionURI` must be
    /// the **like record**; `uri` must be the **subject post**. Swap them and
    /// the delete loop either fails every ghost or aims at a record in someone
    /// else's repo.
    func test_reconcile_deletionURIIsTheLikeRecordNotTheSubject() {
        let likeRecord = "at://did:plc:me/app.bsky.feed.like/xyz"
        let subject = "at://did:plc:gone/app.bsky.feed.post/abc"
        let ghosts = ContentService.reconcileGhostLikes(
            records: [record(recordURI: likeRecord, subjectURI: subject)],
            hydratedDeletionURIs: []
        )
        XCTAssertEqual(ghosts[0].deletionURI, likeRecord)
        XCTAssertEqual(ghosts[0].uri, subject)
    }

    /// Fractional seconds are what the official client writes. A bare
    /// `ISO8601DateFormatter` rejects them, and a nil `createdAt` escapes date
    /// predicates — which is how a date-scoped delete once selected a whole
    /// archive. Ghost likes must carry a real date like any other item.
    func test_reconcile_parsesFractionalSecondTimestamps() {
        let ghosts = ContentService.reconcileGhostLikes(
            records: [record(recordURI: "at://did:plc:me/app.bsky.feed.like/1",
                             createdAt: "2026-01-02T03:04:05.123Z")],
            hydratedDeletionURIs: []
        )
        XCTAssertNotNil(ghosts[0].createdAt, "fractional-second timestamp must parse")
    }

    /// A record with no usable timestamp still deletes, but it must not
    /// silently acquire a fake date.
    func test_reconcile_missingTimestampStaysNil() {
        let ghosts = ContentService.reconcileGhostLikes(
            records: [record(recordURI: "at://did:plc:me/app.bsky.feed.like/1",
                             createdAt: nil)],
            hydratedDeletionURIs: []
        )
        XCTAssertNil(ghosts[0].createdAt)
    }

    func test_reconcile_emptyRepoYieldsNoGhosts() {
        XCTAssertTrue(
            ContentService.reconcileGhostLikes(records: [], hydratedDeletionURIs: []).isEmpty
        )
    }

    /// Every ghost is a distinct record, so a repo full of them must not
    /// collapse through `ContentItem.id`.
    func test_reconcile_distinctSubjectsProduceDistinctItems() {
        let records = (1...5).map {
            record(
                recordURI: "at://did:plc:me/app.bsky.feed.like/\($0)",
                subjectURI: "at://did:plc:gone/app.bsky.feed.post/\($0)"
            )
        }
        let ghosts = ContentService.reconcileGhostLikes(
            records: records, hydratedDeletionURIs: []
        )
        XCTAssertEqual(Set(ghosts.map(\.id)).count, 5)
    }

    /// `subjectUnresolved` was added after 1.0.4 shipped. Backup files written
    /// before it exists must still import — a hard decode failure here would
    /// break restore for every existing user.
    func test_contentItem_decodesBackupJSONWithoutTheNewField() throws {
        let original = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/1",
            cid: "c",
            contentType: .posts,
            text: "hello"
        )
        let data = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: "subjectUnresolved")
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ContentItem.self, from: legacy)
        XCTAssertFalse(decoded.subjectUnresolved)
        XCTAssertEqual(decoded.uri, original.uri)
        XCTAssertEqual(decoded.text, "hello")
    }
}
