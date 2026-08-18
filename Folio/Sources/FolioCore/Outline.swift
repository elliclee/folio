import Foundation

/// A heading in the document outline. `id` is the rendered block's id, so
/// tapping an item can scroll the preview straight to that heading.
public struct OutlineItem: Identifiable, Equatable {
    public let id: Int
    public let level: Int
    public let title: String

    public init(id: Int, level: Int, title: String) {
        self.id = id
        self.level = level
        self.title = title
    }
}

public enum MarkdownOutline {
    /// Collects the document's headings (top-level blocks) into a flat,
    /// level-tagged outline.
    public static func from(_ blocks: [MarkdownBlock]) -> [OutlineItem] {
        blocks.compactMap { block in
            guard case .heading(let id, let level, let text) = block else {
                return nil
            }
            let title = String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : OutlineItem(id: id, level: level, title: title)
        }
    }
}
