import XCTest
import FolioCore
@testable import Folio

final class FindMatchIndexTests: XCTestCase {
    // Ported from document-find.test.ts (getNextFindMatchIndex).
    func testReturnsMinusOneWhenNoMatches() {
        XCTAssertEqual(nextFindMatchIndex(currentIndex: 2, matchCount: 0, direction: 1), -1)
    }

    func testStartsAtEdgeWhenNoCurrentMatch() {
        XCTAssertEqual(nextFindMatchIndex(currentIndex: -1, matchCount: 4, direction: 1), 0)
        XCTAssertEqual(nextFindMatchIndex(currentIndex: -1, matchCount: 4, direction: -1), 3)
    }

    func testWrapsAroundInBothDirections() {
        XCTAssertEqual(nextFindMatchIndex(currentIndex: 3, matchCount: 4, direction: 1), 0)
        XCTAssertEqual(nextFindMatchIndex(currentIndex: 0, matchCount: 4, direction: -1), 3)
        XCTAssertEqual(nextFindMatchIndex(currentIndex: 1, matchCount: 4, direction: 1), 2)
    }
}

final class FindHighlighterTests: XCTestCase {
    private let palette = AppTheme.default.palette

    // Ported from document-find.test.ts (findMarkdownMatches semantics).
    func testMatchRangesAreCaseInsensitiveAndNonOverlapping() {
        XCTAssertEqual(FindHighlighter.matchRanges(of: "aa", in: "aaaa"), [0..<2, 2..<4])
        XCTAssertEqual(FindHighlighter.matchRanges(of: "Hello", in: "hello HELLO"), [0..<5, 6..<11])
        XCTAssertEqual(FindHighlighter.matchRanges(of: "  spaced  ", in: "a spaced word"), [2..<8])
        XCTAssertEqual(FindHighlighter.matchRanges(of: "", in: "anything"), [])
        XCTAssertEqual(FindHighlighter.matchRanges(of: "   ", in: "anything"), [])
        XCTAssertEqual(FindHighlighter.matchRanges(of: "missing", in: "anything"), [])
    }

    private func render(_ markdown: String) -> [MarkdownBlock] {
        MarkdownRenderer(palette: palette).render(markdown)
    }

    func testCountsMatchesAcrossBlockTypesInDocumentOrder() {
        let blocks = render("""
        # Swift Title

        A paragraph about swift.

        - swift in a list
        - other item

        > swift in a quote

        ```
        let swift = true
        ```

        | Col |
        | --- |
        | swift cell |
        """)

        let result = FindHighlighter.apply(to: blocks, query: "swift", currentIndex: 0, palette: palette)
        XCTAssertEqual(result.matchCount, 6)
    }

    func testCurrentMatchBlockIdPointsAtTopLevelBlock() {
        let blocks = render("""
        first target

        second target
        """)

        // currentIndex 1 = the match in the second paragraph.
        let result = FindHighlighter.apply(to: blocks, query: "target", currentIndex: 1, palette: palette)

        XCTAssertEqual(result.matchCount, 2)
        XCTAssertEqual(result.currentMatchBlockId, blocks[1].id)
    }

    func testCurrentMatchInsideNestedBlockReportsTopLevelId() {
        let blocks = render("""
        intro

        - nested target here
        """)

        let result = FindHighlighter.apply(to: blocks, query: "target", currentIndex: 0, palette: palette)

        XCTAssertEqual(result.matchCount, 1)
        XCTAssertEqual(result.currentMatchBlockId, blocks[1].id)
    }

    func testHighlightAppliesBackgroundToMatches() throws {
        let blocks = render("hello world hello")
        let result = FindHighlighter.apply(to: blocks, query: "hello", currentIndex: 0, palette: palette)

        guard case .paragraph(_, let text) = result.blocks[0] else {
            return XCTFail("Expected paragraph")
        }

        let highlightedRuns = text.runs.filter { $0.backgroundColor != nil }
        XCTAssertEqual(highlightedRuns.count, 2)
    }
}

final class ScrollSyncTests: XCTestCase {
    // Ported from scroll-position.test.ts (syncScrollPosition).
    func testSyncsByScrollableDistancePercentage() {
        let source = ScrollMetrics(offset: 50, contentHeight: 200, viewportHeight: 100)
        let target = ScrollMetrics(offset: 0, contentHeight: 600, viewportHeight: 100)

        XCTAssertEqual(syncedScrollOffset(source: source, target: target), 250)
    }

    func testResetsTargetWhenEitherPaneCannotScroll() {
        let scrollable = ScrollMetrics(offset: 50, contentHeight: 200, viewportHeight: 100)
        let fixed = ScrollMetrics(offset: 0, contentHeight: 80, viewportHeight: 100)

        XCTAssertEqual(syncedScrollOffset(source: fixed, target: scrollable), 0)
        XCTAssertEqual(syncedScrollOffset(source: scrollable, target: fixed), 0)
    }

    @MainActor
    func testActivePaneGuardBlocksTheOtherPaneUntilReleased() async {
        let controller = ScrollSyncController()

        XCTAssertTrue(controller.beginScroll(from: .editor))
        XCTAssertFalse(controller.beginScroll(from: .preview))
        XCTAssertTrue(controller.beginScroll(from: .editor))

        // After the release delay the other pane may take over.
        try? await Task.sleep(for: .seconds(ScrollSyncController.releaseDelay + 0.1))
        XCTAssertTrue(controller.beginScroll(from: .preview))
    }
}

final class EditorStateTests: XCTestCase {
    // Mirrors editor-state.ts logic now embedded in AppViewModel.
    @MainActor
    func testDirtyDetectionRequiresActiveFileAndChange() {
        let viewModel = AppViewModel()

        // No active file: never dirty even when text changes.
        viewModel.markdown = "changed"
        XCTAssertFalse(viewModel.isDirty)
    }
}
