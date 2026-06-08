import Foundation
import Markdown
import SwiftUI

// MARK: - Block model

/// Flat block model produced from a swift-markdown `Document`,
/// rendered by `MarkdownBlockView`.
enum MarkdownBlock: Identifiable, Equatable {
    case heading(id: Int, level: Int, text: AttributedString)
    case paragraph(id: Int, text: AttributedString)
    /// `code` is the raw text (for copy/export); `display` is the themed
    /// AttributedString actually rendered (find highlights apply to it).
    case codeBlock(id: Int, language: String?, code: String, display: AttributedString)
    case blockquote(id: Int, blocks: [MarkdownBlock])
    /// GFM alert / admonition (`> [!NOTE]` …), rendered as a tinted card.
    case callout(id: Int, kind: MarkdownCalloutKind, blocks: [MarkdownBlock])
    case list(id: Int, items: [MarkdownListItem], ordered: Bool, startIndex: Int)
    case table(id: Int, header: [AttributedString], rows: [[AttributedString]], alignments: [MarkdownTableAlignment])
    case thematicBreak(id: Int)

    var id: Int {
        switch self {
        case .heading(let id, _, _),
             .paragraph(let id, _),
             .codeBlock(let id, _, _, _),
             .blockquote(let id, _),
             .callout(let id, _, _),
             .list(let id, _, _, _),
             .table(let id, _, _, _),
             .thematicBreak(let id):
            return id
        }
    }
}

/// GitHub-style alert kinds. Colors are fixed semantic hues that read on
/// every theme; icons/labels mirror GitHub's rendering.
enum MarkdownCalloutKind: String, CaseIterable {
    case note, tip, important, warning, caution

    static func parse(_ token: String) -> MarkdownCalloutKind? {
        MarkdownCalloutKind(rawValue: token.lowercased())
    }

    var label: String {
        switch self {
        case .note: "Note"
        case .tip: "Tip"
        case .important: "Important"
        case .warning: "Warning"
        case .caution: "Caution"
        }
    }

    var systemImage: String {
        switch self {
        case .note: "info.circle.fill"
        case .tip: "lightbulb.fill"
        case .important: "exclamationmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .caution: "exclamationmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .note: Color(hex: 0x3B82F6)
        case .tip: Color(hex: 0x22C55E)
        case .important: Color(hex: 0x8B5CF6)
        case .warning: Color(hex: 0xF59E0B)
        case .caution: Color(hex: 0xEF4444)
        }
    }
}

struct MarkdownListItem: Identifiable, Equatable {
    let id: Int
    let checkbox: Bool?  // nil = plain item, true/false = GFM task list state
    let blocks: [MarkdownBlock]
}

enum MarkdownTableAlignment: Equatable {
    case left, center, right

    var textAlignment: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

// MARK: - Typography (mirrors .markdown-content rules in index.css)

enum MarkdownTypography {
    /// Editorial reading scale (minor-third-ish steps off a 15.5 body).
    static let bodySize: CGFloat = 15.5
    static let codeSize: CGFloat = 13

    /// Comfortable book measure: ~68 characters at body size.
    static let readingMeasure: CGFloat = 720

    /// Even heading ratios off the body size (borrowed from Resomark):
    /// 1.867 / 1.6 / 1.4 / 1.2 / 1.067. Scales with the body size.
    static func headingSize(level: Int) -> CGFloat {
        let ratio: CGFloat = switch level {
        case 1: 1.867
        case 2: 1.6
        case 3: 1.4
        case 4: 1.2
        default: 1.067
        }
        return bodySize * ratio
    }

    static func headingWeight(level: Int) -> Font.Weight {
        level == 1 ? .bold : .semibold
    }

    /// Large display sizes read better slightly tightened.
    static func headingKern(level: Int) -> CGFloat {
        switch level {
        case 1: -0.6
        case 2: -0.3
        default: 0
        }
    }
}

// MARK: - Renderer

struct MarkdownRenderer {
    let palette: ThemePalette
    /// Heading typeface voice: serif (New York) for the warm reading
    /// themes, default sans for the tool-like themes.
    var headingDesign: Font.Design = .default

    func render(_ markdown: String) -> [MarkdownBlock] {
        let document = Document(parsing: markdown)
        var counter = 0
        return document.blockChildren.compactMap { renderBlock($0, counter: &counter) }
    }

    private func nextId(_ counter: inout Int) -> Int {
        counter += 1
        return counter
    }

    private func renderBlocks(
        _ markup: some Sequence<BlockMarkup>,
        counter: inout Int
    ) -> [MarkdownBlock] {
        markup.compactMap { renderBlock($0, counter: &counter) }
    }

    private func renderBlock(_ markup: BlockMarkup, counter: inout Int) -> MarkdownBlock? {
        switch markup {
        case let heading as Heading:
            return .heading(
                id: nextId(&counter),
                level: heading.level,
                text: renderHeadingInline(heading.inlineChildren, level: heading.level)
            )

        case let paragraph as Paragraph:
            return .paragraph(
                id: nextId(&counter),
                text: renderInline(paragraph.inlineChildren, baseSize: MarkdownTypography.bodySize)
            )

        case let codeBlock as CodeBlock:
            var code = codeBlock.code
            if code.hasSuffix("\n") {
                code.removeLast()
            }
            return .codeBlock(
                id: nextId(&counter),
                language: codeBlock.language,
                code: code,
                display: codeDisplay(code, language: codeBlock.language)
            )

        case is HTMLBlock:
            // Raw HTML blocks render as plain monospace text for now.
            let html = (markup as! HTMLBlock).rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            return .codeBlock(
                id: nextId(&counter),
                language: "html",
                code: html,
                display: codeDisplay(html, language: "html")
            )

        case let quote as BlockQuote:
            if let kind = calloutKind(of: quote) {
                var blocks = renderBlocks(quote.blockChildren, counter: &counter)
                stripCalloutMarker(from: &blocks)
                return .callout(id: nextId(&counter), kind: kind, blocks: blocks)
            }
            return .blockquote(
                id: nextId(&counter),
                blocks: renderBlocks(quote.blockChildren, counter: &counter)
            )

        case let list as UnorderedList:
            return .list(
                id: nextId(&counter),
                items: renderListItems(list.listItems, counter: &counter),
                ordered: false,
                startIndex: 1
            )

        case let list as OrderedList:
            return .list(
                id: nextId(&counter),
                items: renderListItems(list.listItems, counter: &counter),
                ordered: true,
                startIndex: Int(list.startIndex)
            )

        case let table as Markdown.Table:
            let alignments = table.columnAlignments.map { alignment -> MarkdownTableAlignment in
                switch alignment {
                case .center: .center
                case .right: .right
                default: .left
                }
            }
            // Header cells read as compact column labels.
            let header = table.head.cells.map {
                renderInline($0.inlineChildren, baseSize: MarkdownTypography.bodySize - 2, bold: true)
            } as [AttributedString]
            let rows = table.body.rows.map { row in
                row.cells.map {
                    renderInline($0.inlineChildren, baseSize: MarkdownTypography.bodySize - 0.5)
                } as [AttributedString]
            } as [[AttributedString]]
            return .table(id: nextId(&counter), header: header, rows: rows, alignments: alignments)

        case is ThematicBreak:
            return .thematicBreak(id: nextId(&counter))

        default:
            return nil
        }
    }

    private func renderListItems(
        _ items: LazyMapSequence<MarkupChildren, ListItem>,
        counter: inout Int
    ) -> [MarkdownListItem] {
        items.map { item in
            let checkbox: Bool? = switch item.checkbox {
            case .checked: true
            case .unchecked: false
            case nil: nil
            }
            return MarkdownListItem(
                id: nextId(&counter),
                checkbox: checkbox,
                blocks: renderBlocks(item.blockChildren, counter: &counter)
            )
        }
    }

    /// Detects a leading `[!TYPE]` alert marker on a blockquote.
    private func calloutKind(of quote: BlockQuote) -> MarkdownCalloutKind? {
        guard let paragraph = quote.child(at: 0) as? Paragraph,
              let token = leadingAlertToken(paragraph.plainText) else {
            return nil
        }
        return MarkdownCalloutKind.parse(token)
    }

    /// Returns the TYPE in a leading `[!TYPE]` marker, else nil.
    private func leadingAlertToken(_ text: String) -> String? {
        var rest = Substring(text)
        while let first = rest.first, first == " " || first == "\t" { rest = rest.dropFirst() }
        guard rest.hasPrefix("[!"), let close = rest.firstIndex(of: "]") else {
            return nil
        }
        let token = rest[rest.index(rest.startIndex, offsetBy: 2)..<close]
        return token.allSatisfy(\.isLetter) && !token.isEmpty ? String(token) : nil
    }

    /// Removes the `[!TYPE]` marker (and any following whitespace) from the
    /// first paragraph of an already-rendered callout body.
    private func stripCalloutMarker(from blocks: inout [MarkdownBlock]) {
        guard let index = blocks.firstIndex(where: { if case .paragraph = $0 { return true } else { return false } }),
              case .paragraph(let id, var text) = blocks[index] else {
            return
        }

        let plain = Array(String(text.characters))
        var i = 0
        while i < plain.count, plain[i] == " " || plain[i] == "\t" { i += 1 }
        guard i + 1 < plain.count, plain[i] == "[", plain[i + 1] == "!" else { return }
        guard let close = plain[i...].firstIndex(of: "]") else { return }
        var dropCount = close + 1
        while dropCount < plain.count, plain[dropCount] == " " || plain[dropCount] == "\t" || plain[dropCount] == "\n" {
            dropCount += 1
        }

        let upper = text.index(text.startIndex, offsetByCharacters: dropCount)
        text.removeSubrange(text.startIndex..<upper)

        if text.characters.isEmpty {
            blocks.remove(at: index)
        } else {
            blocks[index] = .paragraph(id: id, text: text)
        }
    }

    private func codeDisplay(_ code: String, language: String?) -> AttributedString {
        var display = AttributedString(code)
        display.font = .system(size: MarkdownTypography.codeSize, design: .monospaced)
        display.foregroundColor = palette.codeBlockFg

        if let config = CodeHighlighter.language(named: language) {
            for token in CodeHighlighter.tokenize(code, language: config) {
                let lower = display.index(display.startIndex, offsetByCharacters: token.range.lowerBound)
                let upper = display.index(display.startIndex, offsetByCharacters: token.range.upperBound)
                display[lower..<upper].foregroundColor = CodeHighlighter.color(for: token.kind)
            }
        }

        return display
    }

    // MARK: Inline rendering

    func renderInline(
        _ children: some Sequence<InlineMarkup>,
        baseSize: CGFloat,
        bold: Bool = false
    ) -> AttributedString {
        var context = InlineContext(
            size: baseSize,
            bold: bold,
            italic: false,
            strikethrough: false,
            foreground: bold ? palette.textPrimary : palette.textSecondary,
            link: nil
        )
        return renderInline(children, context: &context)
    }

    func renderHeadingInline(
        _ children: some Sequence<InlineMarkup>,
        level: Int
    ) -> AttributedString {
        var context = InlineContext(
            size: MarkdownTypography.headingSize(level: level),
            bold: true,
            italic: false,
            strikethrough: false,
            foreground: level >= 5 ? palette.textSecondary : palette.textPrimary,
            link: nil,
            weight: MarkdownTypography.headingWeight(level: level),
            design: headingDesign,
            kern: MarkdownTypography.headingKern(level: level)
        )
        return renderInline(children, context: &context)
    }

    private struct InlineContext {
        var size: CGFloat
        var bold: Bool
        var italic: Bool
        var strikethrough: Bool
        var foreground: Color
        var link: URL?
        /// Explicit weight/design/kern override the body defaults
        /// (used by headings).
        var weight: Font.Weight?
        var design: Font.Design = .default
        var kern: CGFloat = 0

        init(
            size: CGFloat,
            bold: Bool,
            italic: Bool,
            strikethrough: Bool,
            foreground: Color,
            link: URL?,
            weight: Font.Weight? = nil,
            design: Font.Design = .default,
            kern: CGFloat = 0
        ) {
            self.size = size
            self.bold = bold
            self.italic = italic
            self.strikethrough = strikethrough
            self.foreground = foreground
            self.link = link
            self.weight = weight
            self.design = design
            self.kern = kern
        }
    }

    private func renderInline(
        _ children: some Sequence<InlineMarkup>,
        context: inout InlineContext
    ) -> AttributedString {
        var result = AttributedString()

        for child in children {
            switch child {
            case let text as Markdown.Text:
                result += styled(text.string, context)

            case let emphasis as Emphasis:
                var inner = context
                inner.italic = true
                result += renderInline(emphasis.inlineChildren, context: &inner)

            case let strong as Strong:
                var inner = context
                inner.bold = true
                inner.foreground = palette.textPrimary
                result += renderInline(strong.inlineChildren, context: &inner)

            case let strikethrough as Strikethrough:
                var inner = context
                inner.strikethrough = true
                result += renderInline(strikethrough.inlineChildren, context: &inner)

            case let code as InlineCode:
                var piece = AttributedString(code.code)
                piece.font = .system(size: context.size - 1.5, design: .monospaced)
                piece.foregroundColor = palette.inlineCodeFg
                piece.backgroundColor = palette.inlineCodeBg
                result += piece

            case let link as Markdown.Link:
                var inner = context
                inner.foreground = palette.accent
                inner.link = link.destination.flatMap(URL.init(string:))
                result += renderInline(link.inlineChildren, context: &inner)

            case let image as Markdown.Image:
                // Native image loading lands in a later milestone; show alt text.
                let alt = image.plainText
                result += styled(alt.isEmpty ? "[image]" : alt, context)

            case is SoftBreak:
                result += styled(" ", context)

            case is LineBreak:
                result += styled("\n", context)

            case let html as InlineHTML:
                if html.rawHTML == "<br>" || html.rawHTML == "<br/>" || html.rawHTML == "<br />" {
                    result += styled("\n", context)
                }
                // Other inline HTML tags are dropped, matching a
                // sanitizing HTML-less renderer.

            default:
                result += styled(child.plainText, context)
            }
        }

        return result
    }

    private func styled(_ string: String, _ context: InlineContext) -> AttributedString {
        var piece = AttributedString(string)
        let weight = context.weight ?? (context.bold ? .semibold : .regular)
        var font = Font.system(size: context.size, weight: weight, design: context.design)
        if context.italic {
            font = font.italic()
        }
        piece.font = font
        piece.foregroundColor = context.foreground
        if context.kern != 0 {
            piece.kern = context.kern
        }
        if context.strikethrough {
            piece.strikethroughStyle = .single
        }
        if let link = context.link {
            piece.link = link
            piece.underlineStyle = .single
        }
        return piece
    }
}
