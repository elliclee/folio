import XCTest
@testable import Folio

final class MarkdownTreeTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("folio-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // /var/folders is a symlink to /private/var/folders; canonicalize so
        // the paths returned by directory enumeration compare equal.
        // (resolvingSymlinksInPath() can't be used: it strips /private.)
        let canonicalPath = try XCTUnwrap(
            tempDir.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath
        )
        tempDir = URL(fileURLWithPath: canonicalPath)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    private func makeFile(_ relativePath: String, contents: String = "# Test") throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    func testCollectsOnlySupportedFilesAndPrunesEmptyDirectories() throws {
        try makeFile("README.md")
        try makeFile("notes.txt")
        try makeFile("guide.markdown")
        try makeFile("image.png")
        try makeFile("empty-dir/script.swift")
        try makeFile("docs/intro.md")

        let tree = MarkdownTree.collect(at: tempDir)
        let names = tree.map(\.name)

        // Directories first, then files, case-insensitive alphabetical
        // (same as localeCompare in markdown-files.ts).
        XCTAssertEqual(names, ["docs", "guide.markdown", "notes.txt", "README.md"])
        XCTAssertFalse(names.contains("empty-dir"))
        XCTAssertFalse(names.contains("image.png"))
    }

    func testHiddenEntriesAreSkipped() throws {
        try makeFile("visible.md")
        try makeFile(".hidden.md")
        try makeFile(".git/objects/notes.md")

        let names = MarkdownTree.collect(at: tempDir).map(\.name)
        XCTAssertEqual(names, ["visible.md"])
    }

    func testSupportedTreeFileMatchingIsCaseInsensitive() {
        XCTAssertTrue(MarkdownTree.isSupportedTreeFile("README.MD"))
        XCTAssertTrue(MarkdownTree.isSupportedTreeFile("a.Markdown"))
        XCTAssertTrue(MarkdownTree.isSupportedTreeFile("a.txt"))
        XCTAssertFalse(MarkdownTree.isSupportedTreeFile("a.mdx"))
        XCTAssertFalse(MarkdownTree.isSupportedTreeFile("md"))
    }

    func testDefaultExpansionStopsAtDepthLimit() throws {
        try makeFile("a/b/c/deep.md")

        let tree = MarkdownTree.wrappedInRootDirectory(
            path: tempDir.path,
            children: MarkdownTree.collect(at: tempDir)
        )
        let expanded = Set(MarkdownTree.defaultExpandedDirectoryPaths(tree))

        // Root (depth 1) and "a" (depth 2) expand; "b" (depth 3) does not.
        XCTAssertTrue(expanded.contains(tempDir.path))
        XCTAssertTrue(expanded.contains(tempDir.appendingPathComponent("a").path))
        XCTAssertFalse(expanded.contains(tempDir.appendingPathComponent("a/b").path))
    }

    func testFirstMarkdownFileIsDepthFirst() throws {
        try makeFile("z-top.md")
        try makeFile("a-dir/inner.md")

        let tree = MarkdownTree.collect(at: tempDir)
        // "a-dir" sorts before "z-top.md", so DFS finds inner.md first.
        XCTAssertEqual(MarkdownTree.firstMarkdownFile(in: tree)?.name, "inner.md")
    }

    func testWrappedRootUsesLastPathComponent() {
        let wrapped = MarkdownTree.wrappedInRootDirectory(path: "/Users/ellic/Project Notes/", children: [])
        XCTAssertEqual(wrapped.first?.name, "Project Notes")
    }
}

final class MarkdownRendererTests: XCTestCase {
    private let renderer = MarkdownRenderer(palette: AppTheme.default.palette)

    func testRendersGfmConstructs() {
        let blocks = renderer.render("""
        # Title

        Hello **world** with `code` and ~~gone~~.

        - [x] done
        - [ ] todo

        | A | B |
        | --- | ---: |
        | 1 | 2 |

        ```swift
        let x = 1
        ```

        ---
        """)

        guard blocks.count == 6 else {
            return XCTFail("Expected 6 blocks, got \(blocks.count): \(blocks)")
        }

        guard case .heading(_, let level, _) = blocks[0] else { return XCTFail("heading") }
        XCTAssertEqual(level, 1)

        guard case .paragraph = blocks[1] else { return XCTFail("paragraph") }

        guard case .list(_, let items, let ordered, _) = blocks[2] else { return XCTFail("list") }
        XCTAssertFalse(ordered)
        XCTAssertEqual(items.map(\.checkbox), [true, false])

        guard case .table(_, let header, let rows, let alignments) = blocks[3] else { return XCTFail("table") }
        XCTAssertEqual(header.count, 2)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(alignments.count, 2)

        guard case .codeBlock(_, let language, let code, let display) = blocks[4] else { return XCTFail("code") }
        XCTAssertEqual(language, "swift")
        XCTAssertEqual(code, "let x = 1")
        XCTAssertEqual(String(display.characters), "let x = 1")

        guard case .thematicBreak = blocks[5] else { return XCTFail("hr") }
    }

    func testGfmAlertBecomesCalloutWithMarkerStripped() {
        let blocks = renderer.render("""
        > [!WARNING]
        > Back up your data first.

        > a plain quote
        """)

        guard case .callout(_, let kind, let body) = blocks.first else {
            return XCTFail("Expected a callout block")
        }
        XCTAssertEqual(kind, .warning)
        guard case .paragraph(_, let text) = body.first else {
            return XCTFail("Expected paragraph in callout")
        }
        // The [!WARNING] marker must not leak into the rendered text.
        XCTAssertEqual(String(text.characters), "Back up your data first.")

        // A blockquote without an alert marker stays a blockquote.
        guard case .blockquote = blocks.last else {
            return XCTFail("Expected plain blockquote")
        }
    }

    func testCalloutKindParsingIsCaseInsensitive() {
        XCTAssertEqual(MarkdownCalloutKind.parse("NOTE"), .note)
        XCTAssertEqual(MarkdownCalloutKind.parse("tip"), .tip)
        XCTAssertEqual(MarkdownCalloutKind.parse("Caution"), .caution)
        XCTAssertNil(MarkdownCalloutKind.parse("bogus"))
    }

    func testOrderedListKeepsStartIndex() {
        let blocks = renderer.render("""
        3. three
        4. four
        """)

        guard case .list(_, let items, let ordered, let start) = blocks.first else {
            return XCTFail("Expected ordered list")
        }
        XCTAssertTrue(ordered)
        XCTAssertEqual(start, 3)
        XCTAssertEqual(items.count, 2)
    }
}
