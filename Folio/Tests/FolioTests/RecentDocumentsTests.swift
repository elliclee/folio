import XCTest
import FolioCore

final class RecentDocumentRulesTests: XCTestCase {
    private func doc(_ path: String) -> RecentDocument {
        RecentDocument(name: (path as NSString).lastPathComponent, path: path)
    }

    func testNewestFirstAndCappedAtThree() {
        var list: [RecentDocument] = []
        for i in 1...5 {
            list = RecentDocumentRules.remember(list, doc("/notes/\(i).md"))
        }
        XCTAssertEqual(list.map(\.path), ["/notes/5.md", "/notes/4.md", "/notes/3.md"])
    }

    func testReopeningMovesToFrontWithoutDuplicating() {
        var list: [RecentDocument] = []
        list = RecentDocumentRules.remember(list, doc("/a.md"))
        list = RecentDocumentRules.remember(list, doc("/b.md"))
        list = RecentDocumentRules.remember(list, doc("/a.md"))

        XCTAssertEqual(list.map(\.path), ["/a.md", "/b.md"])
    }
}

final class RecentDocumentsStoreTests: XCTestCase {
    @MainActor
    func testRoundTripsThroughUserDefaultsCappedAtThree() throws {
        let suite = "folio-recents-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentDocumentsStore(defaults: defaults)
        for i in 1...4 {
            store.remember(name: "\(i).md", path: "/docs/\(i).md")
        }

        let reloaded = RecentDocumentsStore(defaults: defaults)
        XCTAssertEqual(reloaded.documents.map(\.path), ["/docs/4.md", "/docs/3.md", "/docs/2.md"])
    }
}
