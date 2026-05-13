import XCTest
@testable import SkymarshalCore

final class WordPatternsServiceTests: XCTestCase {

    func test_buildSnapshot_countsAffirmativeLexicon() {
        let items = [
            ContentItem(uri: "a", cid: "1", contentType: .posts, text: "This is great and good"),
        ]
        let s = WordPatternsService.buildSnapshot(from: items)
        XCTAssertGreaterThanOrEqual(s.affirmativeWordCount, 2)
    }

    func test_buildSnapshot_emptyItems() {
        let s = WordPatternsService.buildSnapshot(from: [])
        XCTAssertEqual(s.affirmativeWordCount, 0)
        XCTAssertEqual(s.criticalWordCount, 0)
        XCTAssertTrue(s.topWords.isEmpty)
    }
}
