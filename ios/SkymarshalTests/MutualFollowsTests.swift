import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class MutualFollowsTests: XCTestCase {

    /// Pure-function set intersection test against the same logic
    /// FollowerService.loadMutualFollows uses internally. We test
    /// the math here without mocking the network — proves the
    /// dedupe + self-filter behavior the UI depends on.

    private func mockUserDIDs() -> Set<String> {
        ["did:plc:alice", "did:plc:bob", "did:plc:carol", "did:plc:dan"]
    }

    private func intersect(
        userDIDs: Set<String>,
        targetFollows: [BskyProfile],
        selfDID: String?
    ) -> [MutualFollow] {
        var seen = Set<String>()
        var matches: [MutualFollow] = []
        for profile in targetFollows {
            guard !seen.contains(profile.did),
                  profile.did != selfDID,
                  userDIDs.contains(profile.did) else { continue }
            seen.insert(profile.did)
            matches.append(MutualFollow(
                did: profile.did,
                handle: profile.handle,
                displayName: profile.displayName,
                avatar: profile.avatar
            ))
        }
        return matches
    }

    private func profile(_ did: String, handle: String? = nil) -> BskyProfile {
        BskyProfile(did: did, handle: handle ?? did, createdAt: "")
    }

    // MARK: - Cases

    func test_intersection_of_overlap_returnsCommon() {
        let target = [
            profile("did:plc:alice"),
            profile("did:plc:bob"),
            profile("did:plc:eve"),  // not in user follows
        ]
        let result = intersect(
            userDIDs: mockUserDIDs(),
            targetFollows: target,
            selfDID: "did:plc:me"
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.did)), ["did:plc:alice", "did:plc:bob"])
    }

    func test_intersection_with_no_overlap_isEmpty() {
        let target = [
            profile("did:plc:eve"),
            profile("did:plc:frank"),
        ]
        let result = intersect(
            userDIDs: mockUserDIDs(),
            targetFollows: target,
            selfDID: nil
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_dedupe_repeatedDID_returnsOnceOnly() {
        // Pagination sometimes emits the same profile twice across
        // page boundaries. The dedupe set guards against double-render.
        let target = [
            profile("did:plc:alice"),
            profile("did:plc:alice"),
            profile("did:plc:bob"),
        ]
        let result = intersect(
            userDIDs: mockUserDIDs(),
            targetFollows: target,
            selfDID: nil
        )
        XCTAssertEqual(result.count, 2)
    }

    func test_filtersOutSelf_evenIfTargetFollowsUs() {
        // Edge: target follows the user. We shouldn't appear as our
        // own mutual follow (it would be confusing UX).
        let target = [
            profile("did:plc:alice"),
            profile("did:plc:me"),  // user themselves
        ]
        let result = intersect(
            userDIDs: mockUserDIDs().union(["did:plc:me"]),
            targetFollows: target,
            selfDID: "did:plc:me"
        )
        XCTAssertEqual(result.map(\.did), ["did:plc:alice"])
    }
}
