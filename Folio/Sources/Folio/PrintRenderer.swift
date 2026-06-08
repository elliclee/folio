import AppKit
import FolioCore
import Markdown

/// Mirrors `getPrintDocumentTitle` in pdf-export.ts: strip the last
/// extension, keep dot-files intact, fall back to the app name.
func printDocumentTitle(_ activeFileName: String?) -> String {
    guard let activeFileName, !activeFileName.isEmpty else {
        return "Folio"
    }

    guard let dotIndex = activeFileName.lastIndex(of: "."),
          dotIndex != activeFileName.startIndex else {
        return activeFileName
    }

    return String(activeFileName[..<dotIndex])
}

/// Renders markdown into a paginating `NSAttributedString` for
/// `NSPrintOperation`, styled after the print stylesheet in
/// pdf-export.ts (white page, dark code blocks, blue inline code).
struct PrintRenderer {
    // Print palette (from getPdfExportStyles / @media print CSS).
    private static let heading = NSColor(srgbRed: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255, alpha: 1)
    private static let body = NSColor(srgbRed: 0x37 / 255, green: 0x41 / 255, blue: 0x51 / 255, alpha: 1)
    private static let codeBlockBg = NSColor(srgbRed: 0x0F / 255, green: 0x17 / 255, blue: 0x2A / 255, alpha: 1)
    private static let codeBlockFg = NSColor(srgbRed: 0xE2 / 255, green: 0xE8 / 255, blue: 0xF0 / 255, alpha: 1)
    private static let inlineCodeBg = NSColor(srgbRed: 0xDB / 255, green: 0xEA / 255, blue: 0xFE / 255, alpha: 1)
    private static let inlineCodeFg = NSColor(srgbRed: 0x1E / 255, green: 0x3A / 255, blue: 0x8A / 255, alpha: 1)
    private static let rule = NSColor(srgbRed: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255, alpha: 1)
    private static let link = NSColor(srgbRed: 0x25 / 255, green: 0x63 / 255, blue: 0xEB / 255, alpha: 1)

    private static let bodySize: CGFloat = 11.5
    private static let codeSize: CGFloat = 10

    func render(_ markdown: String) -> NSAttributedString {
        let document = Document(parsing: markdown)
        let result = NSMutableAttributedString()

        for block in document.blockChildren {
            append(block, to: result, indentLevel: 0)
        }

        return result
    }

    // MARK: - Blocks

    private func append(
        _ markup: BlockMarkup,
        to output: NSMutableAttributedString,
        indentLevel: Int
    ) {
        switch markup {
        case let heading as Heading:
            let size: CGFloat = switch heading.level {
            case 1: 22
            case 2: 17.5
            case 3: 14.5
            default: 12.5
            }
            let style = paragraphStyle(indentLevel: indentLevel)
            style.paragraphSpacingBefore = heading.level == 1 ? 4 : 14
            style.paragraphSpacing = 7
            output.append(inline(
                heading.inlineChildren,
                font: .boldSystemFont(ofSize: size),
                color: Self.heading,
                style: style
            ))
            output.append(newline())

        case let paragraph as Paragraph:
            let style = paragraphStyle(indentLevel: indentLevel)
            style.paragraphSpacing = 7
            style.lineHeightMultiple = 1.25
            output.append(inline(
                paragraph.inlineChildren,
                font: .systemFont(ofSize: Self.bodySize),
                color: Self.body,
                style: style
            ))
            output.append(newline())

        case let codeBlock as CodeBlock:
            appendCodeLines(codeBlock.code, language: codeBlock.language, to: output, indentLevel: indentLevel)

        case let html as HTMLBlock:
            appendCodeLines(html.rawHTML, language: "html", to: output, indentLevel: indentLevel)

        case let quote as BlockQuote:
            for child in quote.blockChildren {
                append(child, to: output, indentLevel: indentLevel + 1)
            }

        case let list as UnorderedList:
            for item in list.listItems {
                appendListItem(item, marker: marker(for: item, ordered: false, index: 0), to: output, indentLevel: indentLevel)
            }

        case let list as OrderedList:
            for (offset, item) in list.listItems.enumerated() {
                let index = Int(list.startIndex) + offset
                appendListItem(item, marker: marker(for: item, ordered: true, index: index), to: output, indentLevel: indentLevel)
            }

        case let table as Markdown.Table:
            appendTable(table, to: output, indentLevel: indentLevel)

        case is ThematicBreak:
            let style = paragraphStyle(indentLevel: indentLevel)
            style.paragraphSpacingBefore = 10
            style.paragraphSpacing = 10
            output.append(NSAttributedString(
                string: String(repeating: "─", count: 40) + "\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.bodySize),
                    .foregroundColor: Self.rule,
                    .paragraphStyle: style,
                ]
            ))

        default:
            break
        }
    }

    private func appendListItem(
        _ item: ListItem,
        marker: String,
        to output: NSMutableAttributedString,
        indentLevel: Int
    ) {
        var isFirstBlock = true
        for child in item.blockChildren {
            if isFirstBlock, let paragraph = child as? Paragraph {
                let style = paragraphStyle(indentLevel: indentLevel + 1)
                style.paragraphSpacing = 3.5
                style.lineHeightMultiple = 1.2
                // Hanging indent so wrapped lines align after the marker.
                style.firstLineHeadIndent = style.headIndent
                style.headIndent += 14

                let line = NSMutableAttributedString(
                    string: marker,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: Self.bodySize),
                        .foregroundColor: Self.body,
                        .paragraphStyle: style,
                    ]
                )
                line.append(inline(
                    paragraph.inlineChildren,
                    font: .systemFont(ofSize: Self.bodySize),
                    color: Self.body,
                    style: style
                ))
                line.append(newline())
                output.append(line)
            } else {
                append(child, to: output, indentLevel: indentLevel + 1)
            }
            isFirstBlock = false
        }
    }

    private func marker(for item: ListItem, ordered: Bool, index: Int) -> String {
        if let checkbox = item.checkbox {
            return checkbox == .checked ? "☑ " : "☐ "
        }
        return ordered ? "\(index). " : "• "
    }

    private func appendCodeLines(
        _ code: String,
        language: String?,
        to output: NSMutableAttributedString,
        indentLevel: Int
    ) {
        var code = code
        if code.hasSuffix("\n") {
            code.removeLast()
        }

        let style = paragraphStyle(indentLevel: indentLevel)
        style.paragraphSpacing = 0
        style.lineHeightMultiple = 1.3

        let attributed = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: Self.codeSize, weight: .regular),
                .foregroundColor: Self.codeBlockFg,
                .backgroundColor: Self.codeBlockBg,
                .paragraphStyle: style,
            ]
        )

        if let config = CodeHighlighter.language(named: language) {
            let nsCode = code as NSString
            var characterOffsets: [Int] = []  // map Character offsets → UTF-16
            characterOffsets.reserveCapacity(code.count + 1)
            var utf16Offset = 0
            for char in code {
                characterOffsets.append(utf16Offset)
                utf16Offset += String(char).utf16.count
            }
            characterOffsets.append(nsCode.length)

            for token in CodeHighlighter.tokenize(code, language: config)
            where token.range.upperBound < characterOffsets.count {
                let location = characterOffsets[token.range.lowerBound]
                let end = characterOffsets[token.range.upperBound]
                attributed.addAttribute(
                    .foregroundColor,
                    value: NSColor(CodeHighlighter.color(for: token.kind)),
                    range: NSRange(location: location, length: end - location)
                )
            }
        }

        // Blank padded lines above/below keep the dark band readable.
        let padAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 4, weight: .regular),
            .backgroundColor: Self.codeBlockBg,
            .paragraphStyle: style,
        ]
        let spacedStyle = paragraphStyle(indentLevel: indentLevel)
        spacedStyle.paragraphSpacing = 8

        output.append(NSAttributedString(string: " \n", attributes: padAttributes))
        output.append(attributed)
        output.append(NSAttributedString(string: "\n \n", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 4, weight: .regular),
            .backgroundColor: Self.codeBlockBg,
            .paragraphStyle: spacedStyle,
        ]))
    }

    private func appendTable(
        _ table: Markdown.Table,
        to output: NSMutableAttributedString,
        indentLevel: Int
    ) {
        let textTable = NSTextTable()
        let columnCount = max(table.head.cells.map { _ in 1 }.count, 1)
        textTable.numberOfColumns = columnCount

        var rowIndex = 0
        appendTableRow(
            cells: table.head.cells.map { $0 },
            table: textTable,
            row: rowIndex,
            columnCount: columnCount,
            isHeader: true,
            to: output
        )
        rowIndex += 1

        for row in table.body.rows {
            appendTableRow(
                cells: row.cells.map { $0 },
                table: textTable,
                row: rowIndex,
                columnCount: columnCount,
                isHeader: false,
                to: output
            )
            rowIndex += 1
        }

        // Spacer paragraph after the table.
        output.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 4),
        ]))
    }

    private func appendTableRow(
        cells: [Markdown.Table.Cell],
        table: NSTextTable,
        row: Int,
        columnCount: Int,
        isHeader: Bool,
        to output: NSMutableAttributedString
    ) {
        for column in 0..<columnCount {
            let block = NSTextTableBlock(
                table: table,
                startingRow: row,
                rowSpan: 1,
                startingColumn: column,
                columnSpan: 1
            )
            block.setBorderColor(Self.rule)
            block.setWidth(0.5, type: .absoluteValueType, for: .border)
            block.setWidth(5, type: .absoluteValueType, for: .padding)
            if isHeader {
                block.backgroundColor = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1)
            }

            let style = NSMutableParagraphStyle()
            style.textBlocks = [block]
            style.lineHeightMultiple = 1.15

            let cellContent: NSAttributedString
            if column < cells.count {
                cellContent = inline(
                    cells[column].inlineChildren,
                    font: isHeader
                        ? .boldSystemFont(ofSize: Self.bodySize - 0.5)
                        : .systemFont(ofSize: Self.bodySize - 0.5),
                    color: isHeader ? Self.heading : Self.body,
                    style: style
                )
            } else {
                cellContent = NSAttributedString(string: "")
            }

            let cell = NSMutableAttributedString(attributedString: cellContent)
            cell.append(NSAttributedString(string: "\n", attributes: [
                .paragraphStyle: style,
                .font: NSFont.systemFont(ofSize: Self.bodySize - 0.5),
            ]))
            output.append(cell)
        }
    }

    // MARK: - Inlines

    private func inline(
        _ children: some Sequence<InlineMarkup>,
        font: NSFont,
        color: NSColor,
        style: NSParagraphStyle
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        appendInline(children, font: font, color: color, style: style, to: result)
        return result
    }

    private func appendInline(
        _ children: some Sequence<InlineMarkup>,
        font: NSFont,
        color: NSColor,
        style: NSParagraphStyle,
        to output: NSMutableAttributedString
    ) {
        for child in children {
            switch child {
            case let text as Markdown.Text:
                output.append(NSAttributedString(string: text.string, attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: style,
                ]))

            case let emphasis as Emphasis:
                let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                appendInline(emphasis.inlineChildren, font: italic, color: color, style: style, to: output)

            case let strong as Strong:
                let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                appendInline(strong.inlineChildren, font: bold, color: Self.heading, style: style, to: output)

            case let strikethrough as Strikethrough:
                let plain = strikethrough.plainText
                output.append(NSAttributedString(string: plain, attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: style,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                ]))

            case let code as InlineCode:
                output.append(NSAttributedString(string: code.code, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .semibold),
                    .foregroundColor: Self.inlineCodeFg,
                    .backgroundColor: Self.inlineCodeBg,
                    .paragraphStyle: style,
                ]))

            case let link as Markdown.Link:
                let start = output.length
                appendInline(link.inlineChildren, font: font, color: Self.link, style: style, to: output)
                if let destination = link.destination, let url = URL(string: destination) {
                    output.addAttributes(
                        [.link: url, .underlineStyle: NSUnderlineStyle.single.rawValue],
                        range: NSRange(location: start, length: output.length - start)
                    )
                }

            case let image as Markdown.Image:
                let alt = image.plainText
                output.append(NSAttributedString(string: alt.isEmpty ? "[image]" : alt, attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: style,
                ]))

            case is SoftBreak:
                output.append(NSAttributedString(string: " ", attributes: [
                    .font: font, .foregroundColor: color, .paragraphStyle: style,
                ]))

            case is LineBreak:
                output.append(NSAttributedString(string: "\n", attributes: [
                    .font: font, .foregroundColor: color, .paragraphStyle: style,
                ]))

            case is InlineHTML:
                break

            default:
                output.append(NSAttributedString(string: child.plainText, attributes: [
                    .font: font, .foregroundColor: color, .paragraphStyle: style,
                ]))
            }
        }
    }

    // MARK: - Helpers

    private func paragraphStyle(indentLevel: Int) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let indent = CGFloat(indentLevel) * 16
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        return style
    }

    private func newline() -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 2)])
    }
}
