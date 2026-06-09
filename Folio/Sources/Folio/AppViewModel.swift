import AppKit
import FolioCore
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable, Identifiable {
    case preview
    case split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: "Preview"
        case .split: "Split"
        }
    }

    var systemImage: String {
        switch self {
        case .preview: "doc.richtext"
        case .split: "rectangle.split.2x1"
        }
    }
}

@MainActor
@Observable
final class AppViewModel {
    var theme: AppTheme = .default {
        didSet { rebuildRenderedBlocks() }
    }

    var tree: [MarkdownTreeNode] = []
    var expandedDirectories: Set<String> = []
    var activeFile: MarkdownFileItem?
    var currentFolderPath: String?
    var viewMode: ViewMode = .preview {
        didSet { scrollCoordinator.isSyncEnabled = viewMode == .split }
    }

    var markdown: String = DefaultMarkdown.content {
        didSet { rebuildRenderedBlocks() }
    }

    private(set) var savedMarkdown: String = DefaultMarkdown.content
    private(set) var isSaving = false

    /// Rendered once per markdown/theme change, shared by preview + find.
    private(set) var renderedBlocks: [MarkdownBlock] = []

    // Find state (mirrors App.tsx find handling).
    var isFindOpen = false
    var findQuery = "" {
        didSet { resetFindMatchIndex() }
    }
    private(set) var findMatchIndex = -1

    let scrollCoordinator = PaneScrollCoordinator()
    let workspaceFolders: WorkspaceFoldersStore
    let recentDocuments: RecentDocumentsStore

    /// Document outline (headings) for the navigator.
    var outline: [OutlineItem] { MarkdownOutline.from(renderedBlocks) }

    /// Directory used to resolve relative image paths in the preview.
    var documentBaseURL: URL? {
        activeFile.map { URL(fileURLWithPath: $0.path).deletingLastPathComponent() }
    }

    /// A tap-to-scroll request; the token makes repeated taps on the same
    /// heading distinct so the preview re-scrolls.
    struct ScrollRequest: Equatable { let blockID: Int; let token: Int }
    private(set) var scrollRequest: ScrollRequest?
    private var scrollToken = 0

    func requestScroll(to blockID: Int) {
        scrollToken += 1
        scrollRequest = ScrollRequest(blockID: blockID, token: scrollToken)
    }

    /// FOLIO_* env seeds apply once, to the first window only.
    private static var didApplyEnvironmentSeeds = false

    init(
        seed: WorkspaceSeed = WorkspaceSeed(),
        workspaceFolders: WorkspaceFoldersStore? = nil,
        recentDocuments: RecentDocumentsStore? = nil
    ) {
        self.workspaceFolders = workspaceFolders ?? WorkspaceFoldersStore.shared
        self.recentDocuments = recentDocuments ?? RecentDocumentsStore.shared

        if let theme = seed.theme.flatMap(AppTheme.init(rawValue:)) {
            self.theme = theme
        }

        rebuildRenderedBlocks()

        if let folderPath = seed.folderPath {
            loadFolder(at: URL(fileURLWithPath: folderPath))
        }

        if seed.isEmpty {
            applyEnvironmentSeedsIfFirstWindow()
        }
    }

    /// Dev hooks (see README): FOLIO_OPEN / _THEME / _VIEWMODE /
    /// _FIND / _EXPORT_PDF. An argv path can't be used for OPEN because
    /// AppKit turns it into an odoc open-document event and then skips
    /// creating the main window.
    private func applyEnvironmentSeedsIfFirstWindow() {
        guard !Self.didApplyEnvironmentSeeds else { return }
        Self.didApplyEnvironmentSeeds = true

        let environment = ProcessInfo.processInfo.environment

        if let theme = environment["FOLIO_THEME"].flatMap(AppTheme.init(rawValue:)) {
            self.theme = theme
        }

        if let openPath = environment["FOLIO_OPEN"] {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: openPath, isDirectory: &isDirectory) {
                let url = URL(fileURLWithPath: openPath)
                if isDirectory.boolValue {
                    loadFolder(at: url)
                } else {
                    openFileFromSystem(at: url)
                }
            }
        }

        if let mode = environment["FOLIO_VIEWMODE"].flatMap(ViewMode.init(rawValue:)) {
            viewMode = mode
        }

        if let query = environment["FOLIO_FIND"], !query.isEmpty {
            openFind()
            findQuery = query
        }

        // FOLIO_OPEN_AFTER=3:/path — load the folder N seconds after
        // launch, on the live UI (reproduces the picker flow, which
        // behaves differently from loading during init).
        if let spec = environment["FOLIO_OPEN_AFTER"],
           let colon = spec.firstIndex(of: ":"),
           let delay = Double(spec[..<colon]) {
            let path = String(spec[spec.index(after: colon)...])
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                NSLog("OPEN_AFTER: loading %@", path)
                self?.loadFolder(at: URL(fileURLWithPath: path))
                NSLog("OPEN_AFTER: loadFolder returned")
            }
        }

        if let pdfPath = environment["FOLIO_EXPORT_PDF"], !pdfPath.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                PrintExporter.exportPDF(
                    markdown: self.markdown,
                    fileName: self.activeFile?.name,
                    to: URL(fileURLWithPath: pdfPath)
                )
            }
        }
    }

    var palette: ThemePalette { theme.palette }

    /// Mirrors `hasUnsavedChanges` in editor-state.ts.
    var isDirty: Bool {
        activeFile != nil && markdown != savedMarkdown
    }

    var findResult: FindHighlightResult? {
        guard isFindOpen, !findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return FindHighlighter.apply(
            to: renderedBlocks,
            query: findQuery,
            currentIndex: findMatchIndex,
            palette: palette
        )
    }

    private func rebuildRenderedBlocks() {
        renderedBlocks = MarkdownRenderer(
            palette: theme.palette,
            headingDesign: theme.headingDesign
        ).render(markdown)
        resetFindMatchIndex()
    }

    // MARK: - Find

    func openFind() {
        isFindOpen = true
    }

    func closeFind() {
        isFindOpen = false
        findQuery = ""
        findMatchIndex = -1
    }

    func moveFindMatch(direction: Int) {
        let matchCount = findResult?.matchCount ?? 0
        findMatchIndex = nextFindMatchIndex(
            currentIndex: findMatchIndex,
            matchCount: matchCount,
            direction: direction
        )
    }

    private func resetFindMatchIndex() {
        guard isFindOpen else { return }
        let matchCount = FindHighlighter.apply(
            to: renderedBlocks,
            query: findQuery,
            currentIndex: -1,
            palette: palette
        ).matchCount
        findMatchIndex = matchCount > 0 ? 0 : -1
    }

    // MARK: - Printing

    func printDocument() {
        PrintExporter.printDocument(
            markdown: markdown,
            fileName: activeFile?.name,
            window: NSApp.keyWindow
        )
    }

    // MARK: - Saving

    func save() {
        guard let activeFile, isDirty, !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try markdown.write(toFile: activeFile.path, atomically: true, encoding: .utf8)
            savedMarkdown = markdown
        } catch {
            presentError(error.localizedDescription, title: "Save File")
        }
    }

    /// Mirrors `confirmDiscardChanges` in App.tsx (native NSAlert in place
    /// of the Tauri confirm dialog).
    func confirmDiscardChanges(nextAction: String) -> Bool {
        guard isDirty else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Unsaved changes"
        alert.informativeText = "You have unsaved changes. Discard them and continue \(nextAction)?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentError(_ text: String, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .critical
        alert.runModal()
    }

    // MARK: - Folder / file loading

    func presentOpenFolderDialog() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        loadFolder(at: url)
    }

    func presentOpenFileDialog() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = MarkdownTree.supportedOpenExtensions
            .compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        openFileFromSystem(at: url)
    }

    /// Folder scans run off the main thread — synchronous recursive
    /// scanning froze the UI on large folders. The generation counter
    /// drops stale results when another folder is picked mid-scan.
    private var folderScanGeneration = 0
    private(set) var isLoadingFolder = false

    func loadFolder(at url: URL) {
        guard confirmDiscardChanges(nextAction: "opening a different folder") else {
            return
        }

        workspaceFolders.rememberRecent(folderPath: url.path)

        folderScanGeneration += 1
        let generation = folderScanGeneration
        isLoadingFolder = true

        Task.detached(priority: .userInitiated) {
            let children = MarkdownTree.collect(at: url)

            await MainActor.run { [weak self] in
                guard let self, generation == self.folderScanGeneration else {
                    return
                }

                self.isLoadingFolder = false
                let workspaceTree = MarkdownTree.wrappedInRootDirectory(
                    path: url.path,
                    children: children
                )

                self.currentFolderPath = url.path
                self.tree = workspaceTree
                self.expandedDirectories = Set(
                    MarkdownTree.defaultExpandedDirectoryPaths(workspaceTree)
                )

                if let firstFile = MarkdownTree.firstMarkdownFile(in: children) {
                    self.loadFile(firstFile, skipConfirm: true)
                } else {
                    self.activeFile = nil
                    self.markdown = DefaultMarkdown.content
                    self.savedMarkdown = DefaultMarkdown.content
                }
            }
        }
    }

    /// Opening a single file shows the file immediately, then fills the
    /// sidebar with its parent directory's tree in the background
    /// (mirrors `loadTreeForFilePath` in App.tsx without blocking).
    func openFileFromSystem(at url: URL) {
        let standalone = MarkdownFileItem(name: url.lastPathComponent, path: url.path)
        guard loadFile(standalone) else {
            return
        }

        tree = [.file(standalone)]
        expandedDirectories = []
        currentFolderPath = nil

        folderScanGeneration += 1
        let generation = folderScanGeneration
        let directoryURL = url.deletingLastPathComponent()

        Task.detached(priority: .userInitiated) {
            let markdownTree = MarkdownTree.collect(at: directoryURL)

            await MainActor.run { [weak self] in
                guard let self, generation == self.folderScanGeneration,
                      !markdownTree.isEmpty else {
                    return
                }

                self.tree = markdownTree
                self.expandedDirectories = Set(
                    MarkdownTree.defaultExpandedDirectoryPaths(markdownTree)
                )

                if let matched = MarkdownTree.findFile(in: markdownTree, byPath: url.path) {
                    self.activeFile = matched
                }
            }
        }
    }

    /// Returns false when the user cancelled the discard-changes
    /// confirmation or the file could not be read (so native list
    /// selection can be reverted).
    @discardableResult
    func loadFile(_ file: MarkdownFileItem, skipConfirm: Bool = false) -> Bool {
        // Mirrors `shouldConfirmBeforeReplacingFile` in editor-state.ts.
        let needsConfirm = !skipConfirm
            && activeFile != nil
            && activeFile?.path != file.path
            && isDirty

        if needsConfirm, !confirmDiscardChanges(nextAction: "opening \(file.name)") {
            return false
        }

        do {
            let text = try String(contentsOfFile: file.path, encoding: .utf8)
            scrollCoordinator.resetScrollPositions()
            markdown = text
            savedMarkdown = text
            activeFile = file
            recentDocuments.remember(name: file.name, path: file.path)
            return true
        } catch {
            presentError(error.localizedDescription, title: "Open File")
            return false
        }
    }

    func openRecentDocument(_ document: RecentDocument) {
        loadFile(MarkdownFileItem(name: document.name, path: document.path))
    }

    func toggleDirectory(_ path: String) {
        if expandedDirectories.contains(path) {
            expandedDirectories.remove(path)
        } else {
            expandedDirectories.insert(path)
        }
    }
}

enum DefaultMarkdown {
    static let content = """
    # Welcome to Folio

    A **local-first** Markdown reader built natively with Swift and SwiftUI.

    ## Getting Started

    - Open a folder of Markdown documents with **⌘O**
    - Pick a reading theme from the toolbar
    - Switch to Split view to edit, **⌘S** saves
    - Find in the document with **⌘F**

    ## Markdown Support

    GitHub Flavored Markdown is supported, including:

    1. Tables
    2. ~~Strikethrough~~
    3. Task lists
    4. `inline code` and fenced code blocks

    ```swift
    let greeting = "Hello, Folio!"
    print(greeting)
    ```

    > Comfortable long-form reading, with themes for different
    > lighting conditions and writing styles.

    | Feature | Status |
    | --- | --- |
    | Native rendering | ✅ |
    | Reading themes | ✅ |
    | Split editing | ✅ |

    ---

    Happy reading!
    """
}
