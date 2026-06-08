import XCTest
@testable import Folio

final class WorkspaceFolderRulesTests: XCTestCase {
    // Ported from workspace-folders.test.ts.

    func testFolderNameUsesLastPathComponent() {
        XCTAssertEqual(WorkspaceFolder(path: "/Users/ellic/Project Notes").name, "Project Notes")
        XCTAssertEqual(WorkspaceFolder(path: "/tmp/docs/").name, "docs")
        XCTAssertEqual(WorkspaceFolder(path: "/").name, "/")
    }

    func testRememberRecentPutsNewestFirstAndCapsAtFive() {
        var state = WorkspaceFolderState()
        for index in 1...7 {
            state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/folder/\(index)")
        }

        XCTAssertEqual(state.recent.count, 5)
        XCTAssertEqual(state.recent.map(\.path), [
            "/folder/7", "/folder/6", "/folder/5", "/folder/4", "/folder/3",
        ])
    }

    func testRememberRecentMovesExistingFolderToFront() {
        var state = WorkspaceFolderState()
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/a")
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/b")
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/a")

        XCTAssertEqual(state.recent.map(\.path), ["/a", "/b"])
    }

    func testPinDeduplicates() {
        var state = WorkspaceFolderState()
        state = WorkspaceFolderRules.pin(state, folderPath: "/a")
        state = WorkspaceFolderRules.pin(state, folderPath: "/a")

        XCTAssertEqual(state.pinned.map(\.path), ["/a"])
    }

    func testUnpinMovesFolderBackToRecent() {
        var state = WorkspaceFolderState()
        state = WorkspaceFolderRules.pin(state, folderPath: "/a")
        state = WorkspaceFolderRules.unpin(state, folderPath: "/a")

        XCTAssertTrue(state.pinned.isEmpty)
        XCTAssertEqual(state.recent.map(\.path), ["/a"])
    }

    func testVisibleRecentExcludesPinnedFolders() {
        var state = WorkspaceFolderState()
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/a")
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/b")
        state = WorkspaceFolderRules.pin(state, folderPath: "/a")

        XCTAssertEqual(WorkspaceFolderRules.visibleRecent(state).map(\.path), ["/b"])
    }

    func testClearRecentKeepsPinned() {
        var state = WorkspaceFolderState()
        state = WorkspaceFolderRules.pin(state, folderPath: "/a")
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: "/b")
        state = WorkspaceFolderRules.clearRecent(state)

        XCTAssertEqual(state.pinned.map(\.path), ["/a"])
        XCTAssertTrue(state.recent.isEmpty)
    }
}

final class WorkspaceFoldersStoreTests: XCTestCase {
    @MainActor
    func testStateRoundTripsThroughUserDefaults() throws {
        let suiteName = "folio-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WorkspaceFoldersStore(defaults: defaults)
        store.pin(folderPath: "/pinned")
        store.rememberRecent(folderPath: "/recent")

        let reloaded = WorkspaceFoldersStore(defaults: defaults)
        XCTAssertEqual(reloaded.pinned.map(\.path), ["/pinned"])
        XCTAssertEqual(reloaded.visibleRecent.map(\.path), ["/recent"])
    }
}
