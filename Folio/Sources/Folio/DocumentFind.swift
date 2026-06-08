import Foundation
import SwiftUI

/// Find-in-document logic. Match cycling is ported from
/// `document-find.ts`; unlike the Tauri version (which counts matches in
/// the raw markdown but highlights via the webview's window.find), this
/// implementation matches and highlights on the *rendered* text, so the
/// count always agrees with what is highlighted.

/// Mirrors `getNextFindMatchIndex`: wraps around in both directions.
func nextFindMatchIndex(currentIndex: Int, matchCount: Int, direction: Int) -> Int {
    guard matchCount > 0 else {
        return -1
    }

    if currentIndex < 0 {
        return direction == 1 ? 0 : matchCount - 1
    }

    return (currentIndex + direction + matchCount) % matchCount
}

struct FindHighlightResult {
    var blocks: [MarkdownBlock]
    var matchCount: Int
    /// Top-level block containing the current match, for scroll-to.
    var currentMatchBlockId: Int?
}

enum FindHighlighter {
    /// Case-insensitive, non-overlapping (same as `findMarkdownMatches`).
    static func matchRanges(of needle: String, in text: String) -> [Range<Int>] {
        let needle = needle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            return []
        }

        let haystack = text.lowercased()
        var ranges: [Range<Int>] = []
        var searchStart = haystack.startIndex

        while searchStart < haystack.endIndex,
              let found = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            let start = haystack.distance(from: haystack.startIndex, to: found.lowerBound)
            let end = haystack.distance(from: haystack.startIndex, to: found.upperBound)
            ranges.append(start..<end)
            searchStart = found.upperBound
        }

        return ranges
    }

    /// Walks the rendered blocks in document order, highlighting every
    /// match and emphasizing the current one.
    static func apply(
        to blocks: [MarkdownBlock],
        query: String,
        currentIndex: Int,
        palette: ThemePalette
    ) -> FindHighlightResult {
        var walker = Walker(query: query, currentIndex: currentIndex, palette: palette)
        let highlighted = blocks.map { block -> MarkdownBlock in
            let blockId = block.id
            let result = walker.highlight(block)
            if walker.currentMatchTopLevelBlockId == nil, walker.sawCurrentMatch {
                walker.currentMatchTopLevelBlockId = blockId
            }
            return result
        }

        return FindHighlightResult(
            blocks: highlighted,
            matchCount: walker.cursor,
            currentMatchBlockId: walker.currentMatchTopLevelBlockId
        )
    }

    private struct Walker {
        let query: String
        let currentIndex: Int
        let palette: ThemePalette
        var cursor = 0
        var sawCurrentMatch = false
        var currentMatchTopLevelBlockId: Int?

        mutating func highlight(_ block: MarkdownBlock) -> MarkdownBlock {
            switch block {
            case .heading(let id, let level, let text):
                return .heading(id: id, level: level, text: highlight(text))

            case .paragraph(let id, let text):
                return .paragraph(id: id, text: highlight(text))

            case .codeBlock(let id, let language, let code, let display):
                return .codeBlock(id: id, language: language, code: code, display: highlight(display))

            case .blockquote(let id, let blocks):
                return .blockquote(id: id, blocks: blocks.map { highlight($0) })

            case .callout(let id, let kind, let blocks):
                return .callout(id: id, kind: kind, blocks: blocks.map { highlight($0) })

            case .list(let id, let items, let ordered, let startIndex):
                let highlightedItems = items.map { item in
                    MarkdownListItem(
                        id: item.id,
                        checkbox: item.checkbox,
                        blocks: item.blocks.map { highlight($0) }
                    )
                }
                return .list(id: id, items: highlightedItems, ordered: ordered, startIndex: startIndex)

            case .table(let id, let header, let rows, let alignments):
                return .table(
                    id: id,
                    header: header.map { highlight($0) },
                    rows: rows.map { row in row.map { highlight($0) } },
                    alignments: alignments
                )

            case .thematicBreak:
                return block
            }
        }

        private mutating func highlight(_ text: AttributedString) -> AttributedString {
            let plain = String(text.characters)
            let ranges = FindHighlighter.matchRanges(of: query, in: plain)
            guard !ranges.isEmpty else {
                return text
            }

            var result = text
            for range in ranges {
                let isCurrent = cursor == currentIndex
                if isCurrent {
                    sawCurrentMatch = true
                }
                cursor += 1

                let lower = result.index(result.startIndex, offsetByCharacters: range.lowerBound)
                let upper = result.index(result.startIndex, offsetByCharacters: range.upperBound)
                if isCurrent {
                    result[lower..<upper].backgroundColor = palette.accent
                    result[lower..<upper].foregroundColor = palette.accentFg
                } else {
                    result[lower..<upper].backgroundColor = palette.accent.opacity(0.28)
                }
            }

            return result
        }
    }
}
