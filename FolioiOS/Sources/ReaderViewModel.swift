import Observation
import SwiftUI
import FolioCore

/// iOS reader state. The portable rendering/theme/recents logic comes
/// from FolioCore; this view model only adds iOS file access (sandbox
/// security-scoped URLs + bookmarks).
@MainActor
@Observable
final class ReaderViewModel {
    var theme: AppTheme = .default {
        didSet { rebuild() }
    }

    private(set) var markdown: String = WelcomeDocument.text {
        didSet { rebuild() }
    }
    private(set) var blocks: [MarkdownBlock] = []
    private(set) var fileName: String?

    let recents = RecentDocumentsStore.shared

    var palette: ThemePalette { theme.palette }

    init() {
        rebuild()
    }

    private func rebuild() {
        blocks = MarkdownRenderer(
            palette: theme.palette,
            headingDesign: theme.headingDesign
        ).render(markdown)
    }

    /// Opens a document the user picked or that another app handed us.
    /// iOS hands back security-scoped URLs; we must bracket the read with
    /// start/stop and persist a bookmark so recents can reopen it.
    func open(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            markdown = text
            fileName = url.lastPathComponent
            let bookmark = try? url.bookmarkData()
            recents.remember(name: url.lastPathComponent, path: url.path, bookmark: bookmark)
        } catch {
            NSLog("Folio: failed to open %@: %@", url.path, error.localizedDescription)
        }
    }

    func openRecent(_ document: RecentDocument) {
        if let data = document.bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                bookmarkDataIsStale: &isStale
            ) {
                open(url: url)
                return
            }
        }
        open(url: URL(fileURLWithPath: document.path))
    }
}

enum WelcomeDocument {
    static let text = """
    # Folio

    A **local-first** Markdown reader for iOS, sharing its renderer with
    the macOS app via *FolioCore*.

    ## Getting started

    - Tap the folder icon to open a `.md` file from the Files app
    - Or "Open with Folio" from another app's share sheet
    - Pick a reading theme from the palette menu

    > Comfortable long-form reading, with themes for different lighting
    > conditions and writing styles.

    ```swift
    let greeting = "Hello, Folio!"
    print(greeting)
    ```

    | Feature | Status |
    | --- | --- |
    | Native rendering | ✅ |
    | Reading themes | ✅ |
    """
}
