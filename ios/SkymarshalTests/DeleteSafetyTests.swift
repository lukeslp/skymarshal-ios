import XCTest
import SwiftData
import os
@testable import SkymarshalCore

/// Covers the 2026-06-10 delete-path hardening: breadcrumb trimming,
/// the consecutive-failure circuit breaker, Retry-After plumbing,
/// refresh-failure triage, and the wall-clock estimator.
@available(iOS 17, *)
final class DeleteSafetyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DeleteBatchRecovery.clear()
    }

    override func tearDown() {
        DeleteBatchRecovery.clear()
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Breadcrumb trimming

    func test_breadcrumb_markCompleted_trimsAndAutoClears() {
        DeleteBatchRecovery.store(ownerKey: "me.bsky.social", itemIDs: ["a", "b", "c"])

        DeleteBatchRecovery.markCompleted(["a"])
        XCTAssertEqual(DeleteBatchRecovery.current()?.itemIDs, ["b", "c"])

        DeleteBatchRecovery.markCompleted(["b", "c"])
        XCTAssertNil(DeleteBatchRecovery.current())
    }

    func test_breadcrumb_markCompleted_noBreadcrumbIsNoOp() {
        DeleteBatchRecovery.markCompleted(["a"])
        XCTAssertNil(DeleteBatchRecovery.current())
    }

    func test_breadcrumb_deleteLoop_trimsSuccessesAndKeepsUnconfirmed() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { request in
            request.bodyString.contains("bad")
                ? (500, Data("{\"error\":\"failed\"}".utf8))
                : (200, Data("{}".utf8))
        }
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let service = ContentService(client: client, container: container)
        let good = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/good",
            cid: "1",
            contentType: .posts
        )
        let bad = ContentItem(
            uri: "at://did:plc:me/app.bsky.feed.post/bad",
            cid: "2",
            contentType: .posts
        )
        await service.setLoadedContent([good, bad])
        DeleteBatchRecovery.store(ownerKey: "me.bsky.social", itemIDs: [good.id, bad.id])

        _ = await service.delete(itemIDs: [good.id, bad.id])

        // The success is confirmed gone; the failure's fate stays in the
        // breadcrumb so the next launch can prompt a reconcile.
        XCTAssertEqual(DeleteBatchRecovery.current()?.itemIDs, [bad.id])
    }

    // MARK: - Circuit breaker

    func test_deleteLoop_haltsAfterConsecutiveFailures() async throws {
        let client = makeClient()
        await client.setSession(makeSession())
        TestURLProtocol.handler = { _ in (500, Data("{\"error\":\"failed\"}".utf8)) }
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let service = ContentService(client: client, container: container)

        let items = (0..<15).map { i in
            ContentItem(
                uri: "at://did:plc:me/app.bsky.feed.post/p\(i)",
                cid: "\(i)",
                contentType: .posts
            )
        }
        await service.setLoadedContent(items)

        let result = await service.delete(itemIDs: items.map(\.id))

        XCTAssertEqual(result.deleted, 0)
        // 10 real failures + 1 halt explanation; items 11-15 never attempted.
        XCTAssertEqual(result.errors.count, ContentService.maxConsecutiveDeleteFailures + 1)
        XCTAssertTrue(result.errors.last?.contains("not attempted") ?? false)
        let remaining = await service.loadedSnapshot
        XCTAssertEqual(remaining.count, items.count)
    }

    // MARK: - Retry-After plumbing

    func test_retryAfterHeader_parsesDeltaSeconds() {
        let http = HTTPURLResponse(
            url: URL(string: "https://bsky.social")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "37"]
        )!
        XCTAssertEqual(ATProtoClient.retryAfterSeconds(from: http), 37)
    }

    func test_ratelimitResetHeader_parsesEpochDelta() {
        let reset = Date().timeIntervalSince1970 + 120
        let http = HTTPURLResponse(
            url: URL(string: "https://bsky.social")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["ratelimit-reset": String(Int(reset))]
        )!
        let parsed = ATProtoClient.retryAfterSeconds(from: http)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed ?? 0, 120, accuracy: 5)
    }

    func test_retryAfterHeader_absentMeansNil() {
        let http = HTTPURLResponse(
            url: URL(string: "https://bsky.social")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!
        XCTAssertNil(ATProtoClient.retryAfterSeconds(from: http))
    }

    func test_withBackoff_honorsServerWaitOverLadder() async throws {
        // Server says wait 1s; the ladder's first step is also 1s, but the
        // point is the override path executes and the call still succeeds
        // on retry.
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        let start = Date()
        let result: String = try await RateLimit.withBackoff {
            let n = attempts.withLock { $0 += 1; return $0 }
            if n == 1 {
                throw ATProtoError(
                    status: 429,
                    message: "Too Many Requests",
                    retryAfterSeconds: 1
                )
            }
            return "ok"
        }
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(attempts.withLock { $0 }, 2)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.9)
    }

    // MARK: - Refresh-failure triage

    func test_refreshTriage_definitiveRejectionOnlyFor400And401() {
        XCTAssertTrue(ATProtoClient.isDefinitiveAuthRejection(
            ATProtoError(status: 400, message: "ExpiredToken")
        ))
        XCTAssertTrue(ATProtoClient.isDefinitiveAuthRejection(
            ATProtoError(status: 401, message: "AuthenticationRequired")
        ))
        XCTAssertFalse(ATProtoClient.isDefinitiveAuthRejection(
            ATProtoError(status: 502, message: "Bad Gateway")
        ))
        XCTAssertFalse(ATProtoClient.isDefinitiveAuthRejection(
            URLError(.timedOut)
        ))
        XCTAssertFalse(ATProtoClient.isDefinitiveAuthRejection(
            URLError(.notConnectedToInternet)
        ))
    }

    // MARK: - Wall-clock estimator

    func test_pacingEstimate_smallBatchIsFast() {
        XCTAssertEqual(DeletePacing.estimatedSeconds(for: 0), 0)
        XCTAssertEqual(
            DeletePacing.estimatedSeconds(for: 100),
            100 * DeletePacing.perItemNetworkSeconds,
            accuracy: 0.001
        )
        XCTAssertEqual(DeletePacing.formattedEstimate(for: 100), "under 2 minutes")
    }

    func test_pacingEstimate_largeBatchReportsHours() {
        // 10,000 paced deletes: 300 burst + 9,700 at ~1.1s ≈ 3 hours.
        let seconds = DeletePacing.estimatedSeconds(for: 10_000)
        XCTAssertGreaterThan(seconds, 2.5 * 3600)
        XCTAssertTrue(DeletePacing.formattedEstimate(for: 10_000).contains("hours"))
    }

    func test_pacingEstimate_midBatchReportsMinutes() {
        XCTAssertTrue(DeletePacing.formattedEstimate(for: 1_000).contains("minutes"))
    }

    // MARK: - Helpers

    private func makeClient() -> ATProtoClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return ATProtoClient(
            session: URLSession(configuration: configuration),
            persistSessionToKeychain: false
        )
    }

    private func makeSession() -> Session {
        Session(
            did: "did:plc:me",
            handle: "me.bsky.social",
            accessJwt: "access",
            refreshJwt: "refresh"
        )
    }
}
