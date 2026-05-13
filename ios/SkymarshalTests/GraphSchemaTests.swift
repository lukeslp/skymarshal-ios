import XCTest
import SwiftData
@testable import SkymarshalCore

@available(iOS 17, *)
final class GraphSchemaTests: XCTestCase {

    func test_schema_includes_graph_models() throws {
        let container = try SkymarshalSchema.makeContainer(inMemory: true)
        let ctx = ModelContext(container)
        let snap = GraphSnapshotRecord(
            ownerHandle: "alice.bsky.social",
            kind: .accountGraph,
            completeness: .partial,
            summaryJSON: #"{"nodes":3}"#
        )
        ctx.insert(snap)
        let node = GraphNodeRecord(
            ownerHandle: "alice.bsky.social",
            snapshotId: snap.id,
            nodeId: "did:plc:test",
            displayLabel: "@bob.bsky.social",
            completeness: .partial
        )
        ctx.insert(node)
        let edge = GraphEdgeRecord(
            ownerHandle: "alice.bsky.social",
            snapshotId: snap.id,
            sourceNodeId: "did:plc:self",
            targetNodeId: "did:plc:test",
            edgeType: "follows",
            weight: 1
        )
        ctx.insert(edge)
        let cp = GraphCheckpointRecord(ownerHandle: "alice.bsky.social", scopeKind: .interactionGraph, cursorJSON: #"{"c":"x"}"#)
        ctx.insert(cp)
        try ctx.save()

        let snaps = try ctx.fetch(FetchDescriptor<GraphSnapshotRecord>())
        XCTAssertEqual(snaps.count, 1)
        XCTAssertEqual(snaps.first?.completeness, .partial)
        let nodes = try ctx.fetch(FetchDescriptor<GraphNodeRecord>())
        XCTAssertEqual(nodes.count, 1)
        let edges = try ctx.fetch(FetchDescriptor<GraphEdgeRecord>())
        XCTAssertEqual(edges.count, 1)
        let cps = try ctx.fetch(FetchDescriptor<GraphCheckpointRecord>())
        XCTAssertEqual(cps.count, 1)
    }
}
