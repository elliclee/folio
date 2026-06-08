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

    /// Set when the open document is HTML — rendered in a WebView.
    private(set) var htmlDocument: String?
    private(set) var htmlBaseURL: URL?

    let recents = RecentDocumentsStore.shared

    var palette: ThemePalette { theme.palette }

    init() {
        rebuild()
        // Dev hook (parity with macOS FOLIO_OPEN): open a file at launch.
        if let path = ProcessInfo.processInfo.environment["FOLIO_OPEN"],
           FileManager.default.fileExists(atPath: path) {
            open(url: URL(fileURLWithPath: path))
        }
    }

    private func rebuild() {
        blocks = MarkdownRenderer(
            palette: theme.palette,
            headingDesign: theme.headingDesign
        ).render(markdown)
    }

    /// Surfaced to the user when a file can't be opened. `errorPresented`
    /// drives the alert via a real @Observable property (a get-only
    /// Binding closure isn't reliably tracked).
    var errorMessage: String?
    var errorPresented = false

    /// Opens a document the user picked or that another app handed us.
    /// iOS hands back security-scoped URLs; bracket the read with
    /// start/stop, try a coordinated read (Files/iCloud providers) and
    /// fall back to a direct read, then persist a bookmark for recents.
    func open(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var text: String?
        var failure: String?

        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            text = readString(at: readURL)
        }
        // Coordination can fail on some providers; try a direct read too.
        if text == nil {
            text = readString(at: url)
            if text == nil {
                failure = coordinationError?.localizedDescription
                    ?? "Couldn’t read \(url.lastPathComponent)."
            }
        }

        guard let text else {
            errorMessage = "\(failure ?? "Unknown error")\n\nscoped=\(scoped)"
            errorPresented = true
            NSLog("Folio: failed to open %@: %@", url.path, failure ?? "unknown")
            return
        }

        fileName = url.lastPathComponent
        switch DocumentKind.from(path: url.path) {
        case .html:
            htmlDocument = text
            htmlBaseURL = url.deletingLastPathComponent()
        case .markdown:
            htmlDocument = nil
            markdown = text
        }
        // `asCopy` URLs are temporary; keep a durable copy in our own
        // container so the history list can reopen it without any
        // security-scoped access later.
        let storedPath = persistCopy(name: url.lastPathComponent, text: text) ?? url.path
        recents.remember(name: url.lastPathComponent, path: storedPath, bookmark: nil)
    }

    private func persistCopy(name: String, text: String) -> String? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("FolioRecents", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(name)
        do {
            try text.write(to: dest, atomically: true, encoding: .utf8)
            return dest.path
        } catch {
            return nil
        }
    }

    private func readString(at url: URL) -> String? {
        if let decoded = try? String(contentsOf: url, encoding: .utf8) {
            return decoded
        }
        if let data = try? Data(contentsOf: url) {
            return String(decoding: data, as: UTF8.self)
        }
        return nil
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
