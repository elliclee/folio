import Foundation

/// File-tree model and scanner, behavior-aligned with
/// `Previewer.md/src/markdown-files.ts`.
public enum MarkdownTreeNode: Identifiable, Equatable {
    case file(MarkdownFileItem)
    case directory(MarkdownDirectoryItem)

    public var id: String { path }

    public var path: String {
        switch self {
        case .file(let file): file.path
        case .directory(let directory): directory.path
        }
    }

    public var name: String {
        switch self {
        case .file(let file): file.name
        case .directory(let directory): directory.name
        }
    }

    public var isDirectory: Bool {
        if case .directory = self { return true }
        return false
    }
}

public struct MarkdownFileItem: Identifiable, Equatable {
    public let name: String
    public let path: String

    public var id: String { path }

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct MarkdownDirectoryItem: Equatable {
    public let name: String
    public let path: String
    public let children: [MarkdownTreeNode]
}

public enum MarkdownTree {
    /// Mirrors MARKDOWN_FILE_PATTERN: `\.(md|markdown|txt)$/i`.
    public static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

    /// Extensions accepted when a file is opened from Finder / Open dialog
    /// (`filterSupportedOpenPaths` only allows md/markdown).
    public static let supportedOpenExtensions: Set<String> = ["md", "markdown"]

    public static func isSupportedTreeFile(_ name: String) -> Bool {
        supportedExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// Recursively collects markdown files. Directories with no markdown
    /// descendants (or that fail to read) are pruned, directories sort
    /// before files, both alphabetically. Hidden entries (.git, …) are
    /// skipped — scanning them made large folders appear to hang.
    public static func collect(
        at directoryURL: URL,
        fileManager: FileManager = .default
    ) -> [MarkdownTreeNode] {
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }

        var nodes: [MarkdownTreeNode] = []

        for entryURL in entries {
            let values = try? entryURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let name = entryURL.lastPathComponent

            if values?.isDirectory == true {
                let children = collect(at: entryURL, fileManager: fileManager)
                if children.isEmpty {
                    continue
                }
                nodes.append(.directory(MarkdownDirectoryItem(
                    name: name,
                    path: entryURL.path,
                    children: children
                )))
            } else if values?.isRegularFile == true, isSupportedTreeFile(name) {
                nodes.append(.file(MarkdownFileItem(name: name, path: entryURL.path)))
            }
        }

        return nodes.sorted { left, right in
            if left.isDirectory != right.isDirectory {
                return left.isDirectory
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    /// Mirrors `getDefaultExpandedDirectoryPaths` (maxVisibleDepth = 3,
    /// root level counts as depth 1).
    public static func defaultExpandedDirectoryPaths(
        _ tree: [MarkdownTreeNode],
        maxVisibleDepth: Int = 3,
        currentDepth: Int = 1
    ) -> [String] {
        tree.flatMap { node -> [String] in
            guard case .directory(let directory) = node, currentDepth < maxVisibleDepth else {
                return []
            }
            return [directory.path] + defaultExpandedDirectoryPaths(
                directory.children,
                maxVisibleDepth: maxVisibleDepth,
                currentDepth: currentDepth + 1
            )
        }
    }

    /// Depth-first search for the first markdown file.
    public static func firstMarkdownFile(in tree: [MarkdownTreeNode]) -> MarkdownFileItem? {
        for node in tree {
            switch node {
            case .file(let file):
                return file
            case .directory(let directory):
                if let childFile = firstMarkdownFile(in: directory.children) {
                    return childFile
                }
            }
        }
        return nil
    }

    /// Mirrors `wrapMarkdownTreeInRootDirectory`.
    public static func wrappedInRootDirectory(
        path: String,
        children: [MarkdownTreeNode]
    ) -> [MarkdownTreeNode] {
        let trimmed = path.hasSuffix("/") && path.count > 1
            ? String(path.dropLast())
            : path
        let name = (trimmed as NSString).lastPathComponent
        return [.directory(MarkdownDirectoryItem(
            name: name.isEmpty ? trimmed : name,
            path: path,
            children: children
        ))]
    }

    /// Mirrors `findTreeFileByPath` in opened-files.ts.
    public static func findFile(in tree: [MarkdownTreeNode], byPath path: String) -> MarkdownFileItem? {
        for node in tree {
            switch node {
            case .file(let file):
                if file.path == path { return file }
            case .directory(let directory):
                if let match = findFile(in: directory.children, byPath: path) {
                    return match
                }
            }
        }
        return nil
    }
}
