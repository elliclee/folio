import SwiftUI

/// Renders one `MarkdownBlock` as native SwiftUI. Pure and
/// platform-agnostic (no AppKit / AppViewModel), so both the macOS and
/// iOS apps share it. `.equatable()` lets unchanged blocks skip
/// re-rendering while scrolling.
public struct MarkdownBlockView: View, Equatable {
    public let block: MarkdownBlock
    public let palette: ThemePalette
    public var nested = false

    public init(block: MarkdownBlock, palette: ThemePalette, nested: Bool = false) {
        self.block = block
        self.palette = palette
        self.nested = nested
    }

    public static func == (lhs: MarkdownBlockView, rhs: MarkdownBlockView) -> Bool {
        lhs.nested == rhs.nested
            && lhs.palette == rhs.palette
            && lhs.block == rhs.block
    }

    public var body: some View {
        switch block {
        case .heading(_, let level, let text):
            Text(text)
                // Roomier leading so wrapped CJK headings don't crowd.
                .lineSpacing(MarkdownTypography.headingSize(level: level) * 0.32)
                .padding(.top, headingTopPadding(level: level))
                .padding(.bottom, headingBottomPadding(level: level))

        case .paragraph(_, let text):
            Text(text)
                .lineSpacing(MarkdownTypography.bodySize * 0.52)  // ≈1.66 line-height
                .padding(.vertical, nested ? 3 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .codeBlock(_, let language, _, let display):
            ScrollView(.horizontal) {
                Text(display)
                    .lineSpacing(MarkdownTypography.codeSize * 0.5)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.codeBlockBg)
            .overlay(alignment: .topTrailing) {
                // Small language badge, an editorial caption detail.
                if let language, !language.isEmpty {
                    Text(language.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(palette.codeBlockFg.opacity(0.45))
                        .padding(.top, 9)
                        .padding(.trailing, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(palette.codeBlockBorder, lineWidth: 1)
            )
            .padding(.vertical, 10)

        case .blockquote(_, let blocks):
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 1.25)
                    .fill(palette.accent.opacity(0.55))
                    .frame(width: 2.5)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { child in
                        MarkdownBlockView(block: child, palette: palette, nested: true)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.vertical, 2)
            }
            .background(
                palette.btnHover.opacity(0.45),
                in: UnevenRoundedRectangle(
                    cornerRadii: .init(bottomTrailing: 8, topTrailing: 8)
                )
            )
            .padding(.vertical, 10)

        case .callout(_, let kind, let blocks):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SwiftUI.Image(systemName: kind.systemImage)
                        .font(.system(size: MarkdownTypography.bodySize - 2))
                    Text(kind.label)
                        .font(.system(size: MarkdownTypography.bodySize - 1.5, weight: .semibold))
                }
                .foregroundStyle(kind.tint)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { child in
                        MarkdownBlockView(block: child, palette: palette, nested: true)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(kind.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(kind.tint.opacity(0.30), lineWidth: 1)
            )
            .padding(.vertical, 10)

        case .list(_, let items, let ordered, let startIndex):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        listMarker(item: item, ordered: ordered, index: startIndex + offset)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(item.blocks) { child in
                                MarkdownBlockView(block: child, palette: palette, nested: true)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, nested ? 2 : 8)
            .padding(.leading, nested ? 4 : 8)

        case .table(_, let header, let rows, let alignments):
            MarkdownTableView(header: header, rows: rows, alignments: alignments, palette: palette)
                .padding(.vertical, 8)

        case .thematicBreak:
            // Editorial asterism instead of a full-width rule.
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(palette.textMuted.opacity(0.6))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
        }
    }

    // Asymmetric heading spacing (top > bottom) pulls a heading toward
    // the text it introduces — Resomark's rhythm.
    private func headingTopPadding(level: Int) -> CGFloat {
        switch level {
        case 1: 24
        case 2: 20
        case 3: 16
        default: 12
        }
    }

    private func headingBottomPadding(level: Int) -> CGFloat {
        switch level {
        case 1: 12
        case 2: 10
        case 3: 8
        default: 6
        }
    }

    @ViewBuilder
    private func listMarker(item: MarkdownListItem, ordered: Bool, index: Int) -> some View {
        if let checked = item.checkbox {
            SwiftUI.Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: MarkdownTypography.bodySize - 1))
                .foregroundStyle(checked ? palette.accent : palette.textMuted)
        } else if ordered {
            Text("\(index).")
                .font(.system(size: MarkdownTypography.bodySize - 1.5, weight: .medium))
                .foregroundStyle(palette.textMuted)
                .monospacedDigit()
        } else {
            // Accent-tinted bullet ties the theme color through the text.
            Text("•")
                .font(.system(size: MarkdownTypography.bodySize, weight: .bold))
                .foregroundStyle(palette.accent.opacity(0.75))
        }
    }
}

public struct MarkdownTableView: View {
    public let header: [AttributedString]
    public let rows: [[AttributedString]]
    public let alignments: [MarkdownTableAlignment]
    public let palette: ThemePalette

    public init(
        header: [AttributedString],
        rows: [[AttributedString]],
        alignments: [MarkdownTableAlignment],
        palette: ThemePalette
    ) {
        self.header = header
        self.rows = rows
        self.alignments = alignments
        self.palette = palette
    }

    private func alignment(_ column: Int) -> MarkdownTableAlignment {
        column < alignments.count ? alignments[column] : .left
    }

    public var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(header.enumerated()), id: \.offset) { column, cell in
                    tableCell(cell, column: column, isHeader: true)
                }
            }
            .background(palette.btnHover.opacity(0.8))

            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                Divider().overlay(palette.border.opacity(0.7))
                    .gridCellColumns(max(header.count, 1))
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                        tableCell(cell, column: column, isHeader: false)
                    }
                }
                .background(rowIndex.isMultiple(of: 2) ? Color.clear : palette.btnHover.opacity(0.35))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tableCell(_ text: AttributedString, column: Int, isHeader: Bool) -> some View {
        Text(text)
            .multilineTextAlignment(alignment(column).textAlignment)
            .padding(.horizontal, 14)
            .padding(.vertical, isHeader ? 8 : 9)
            .frame(maxWidth: .infinity, alignment: alignment(column).frameAlignment)
    }
}
