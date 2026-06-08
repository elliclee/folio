import AppKit
import FolioCore
import XCTest
@testable import Folio

final class CodeHighlighterTests: XCTestCase {
    private func tokens(_ code: String, _ language: String) -> [CodeToken] {
        guard let config = CodeHighlighter.language(named: language) else {
            XCTFail("Missing language: \(language)")
            return []
        }
        return CodeHighlighter.tokenize(code, language: config)
    }

    private func token(_ code: String, _ language: String, kind: CodeTokenKind) -> [String] {
        let chars = Array(code)
        return tokens(code, language)
            .filter { $0.kind == kind }
            .map { String(chars[$0.range]) }
    }

    func testSwiftTokenKinds() {
        let code = """
        // greet the user
        let name: String = "world"
        var count = 42
        """

        XCTAssertEqual(token(code, "swift", kind: .comment), ["// greet the user"])
        XCTAssertEqual(token(code, "swift", kind: .keyword), ["let", "var"])
        XCTAssertEqual(token(code, "swift", kind: .type), ["String"])
        XCTAssertEqual(token(code, "swift", kind: .string), ["\"world\""])
        XCTAssertEqual(token(code, "swift", kind: .number), ["42"])
    }

    func testPythonHashCommentsAndLiterals() {
        let code = """
        # setup
        enabled = True
        def run(self): return None
        """

        XCTAssertEqual(token(code, "python", kind: .comment), ["# setup"])
        XCTAssertEqual(Set(token(code, "python", kind: .literal)), ["True", "None"])
        XCTAssertEqual(Set(token(code, "py", kind: .keyword)), ["def", "self", "return"])
    }

    func testJavaScriptTemplateStringsSpanLines() {
        let code = "const s = `line1\nline2`;"
        XCTAssertEqual(token(code, "js", kind: .string), ["`line1\nline2`"])
        XCTAssertEqual(token(code, "ts", kind: .keyword), ["const"])
    }

    func testStringEscapesDoNotTerminateEarly() {
        XCTAssertEqual(
            token(#"let s = "a \" b""#, "swift", kind: .string),
            [#""a \" b""#]
        )
    }

    func testBlockCommentsSpanLines() {
        let code = "before /* multi\nline */ after"
        XCTAssertEqual(token(code, "c", kind: .comment), ["/* multi\nline */"])
    }

    func testUnknownLanguageIsNotHighlighted() {
        XCTAssertNil(CodeHighlighter.language(named: "brainfuck"))
        XCTAssertNil(CodeHighlighter.language(named: nil))
        XCTAssertNil(CodeHighlighter.language(named: ""))
    }

    func testUnicodeNumberCharactersDoNotHangTheTokenizer() {
        // ①, ², ３ pass Character.isNumber but are not hex digits; the
        // tokenizer used to loop forever on them (app froze on open).
        let code = "let steps = \"① first ② second\" // ½ done ²\nprint(３)"
        let all = tokens(code, "swift")
        XCTAssertFalse(all.isEmpty)
        XCTAssertEqual(token(code, "swift", kind: .keyword), ["let"])

        // Same character class inside an HTML block's tokenizer path.
        XCTAssertNotNil(CodeHighlighter.language(named: "html").map {
            CodeHighlighter.tokenize("<p>步骤①</p>", language: $0)
        })
    }

    func testAsciiNumbersStillTokenize() {
        XCTAssertEqual(token("x = 0xFF + 42", "swift", kind: .number), ["0xFF", "42"])
    }

    func testOversizedCodeBlocksSkipHighlighting() {
        let big = String(repeating: "let x = 1\n", count: 25_000)  // 250k chars
        XCTAssertGreaterThan(big.count, CodeHighlighter.maxTokenizedCharacters)
        XCTAssertEqual(tokens(big, "swift"), [])
    }

    func testTokenRangesAreOrderedAndNonOverlapping() {
        let all = tokens("let x = \"a\" // c\nvar y = 1", "swift")
        for (left, right) in zip(all, all.dropFirst()) {
            XCTAssertLessThanOrEqual(left.range.upperBound, right.range.lowerBound)
        }
    }
}

final class PrintTests: XCTestCase {
    // Ported from pdf-export.test.ts (getPrintDocumentTitle).
    func testPrintDocumentTitleStripsLastExtension() {
        XCTAssertEqual(printDocumentTitle(nil), "Folio")
        XCTAssertEqual(printDocumentTitle(""), "Folio")
        XCTAssertEqual(printDocumentTitle("notes.md"), "notes")
        XCTAssertEqual(printDocumentTitle("archive.notes.markdown"), "archive.notes")
        XCTAssertEqual(printDocumentTitle("README"), "README")
        XCTAssertEqual(printDocumentTitle(".hidden"), ".hidden")
    }

    func testPrintRendererProducesStyledRuns() throws {
        let output = PrintRenderer().render("""
        # Heading

        Body text with `inline code`.

        ```swift
        let x = 1
        ```

        | A | B |
        | --- | --- |
        | 1 | 2 |
        """)

        XCTAssertGreaterThan(output.length, 0)

        let text = output.string
        XCTAssertTrue(text.contains("Heading"))
        XCTAssertTrue(text.contains("Body text with"))
        XCTAssertTrue(text.contains("let x = 1"))

        var sawBoldHeading = false
        var sawMonospacedCode = false
        var sawTableBlock = false

        output.enumerateAttributes(in: NSRange(location: 0, length: output.length)) { attributes, range, _ in
            let run = (output.string as NSString).substring(with: range)
            if let font = attributes[.font] as? NSFont {
                if run.contains("Heading"), font.pointSize == 22 {
                    sawBoldHeading = true
                }
                // Syntax highlighting splits the code line into several
                // runs; any monospaced run from inside it counts.
                if run.contains("x ="), font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
                    sawMonospacedCode = true
                }
            }
            if let style = attributes[.paragraphStyle] as? NSParagraphStyle, !style.textBlocks.isEmpty {
                sawTableBlock = true
            }
        }

        XCTAssertTrue(sawBoldHeading, "expected 22pt heading run")
        XCTAssertTrue(sawMonospacedCode, "expected monospaced code run")
        XCTAssertTrue(sawTableBlock, "expected NSTextTable cell runs")
    }

    func testPreviewCodeDisplayGetsTokenColors() throws {
        let blocks = MarkdownRenderer(palette: AppTheme.default.palette).render("""
        ```swift
        // note
        let x = "hi"
        ```
        """)

        guard case .codeBlock(_, _, _, let display) = blocks[0] else {
            return XCTFail("Expected code block")
        }

        // Comment, keyword, and string runs should differ from the base fg.
        let distinctColors = Set(display.runs.compactMap { run -> String? in
            guard let color = run.foregroundColor else { return nil }
            return String(describing: color)
        })
        XCTAssertGreaterThanOrEqual(distinctColors.count, 3)
    }
}
