import AppKit
import Observation

/// Routes Finder "open document" events (double-clicked .md files, drag
/// onto the Dock icon) to the right window — the native counterpart of
/// the Tauri `PendingOpenFiles` + `open-markdown-files` event machinery.
@MainActor
@Observable
final class OpenFileRouter {
    static let shared = OpenFileRouter()

    /// The view model of the key window (tracked via controlActiveState).
    private weak var activeViewModel: AppViewModel?

    /// Files that arrived before any window existed (app launched by
    /// double-clicking a document).
    private var pendingURLs: [URL] = []

    /// Mirrors `filterSupportedOpenPaths` in opened-files.ts: only
    /// md/markdown arrive through file associations.
    static func supportedURLs(from urls: [URL]) -> [URL] {
        urls.filter {
            MarkdownTree.supportedOpenExtensions.contains($0.pathExtension.lowercased())
        }
    }

    func open(urls: [URL]) {
        let supported = Self.supportedURLs(from: urls)
        NSLog("OpenFileRouter: received %d url(s), %d supported", urls.count, supported.count)
        guard let url = supported.first else {
            return
        }

        if let activeViewModel {
            activeViewModel.openFileFromSystem(at: url)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingURLs.append(contentsOf: supported)
        }
    }

    /// Called when a window becomes key (and once on appear).
    func setActive(_ viewModel: AppViewModel) {
        activeViewModel = viewModel
        drainPending()
    }

    private func drainPending() {
        guard let url = pendingURLs.first, let activeViewModel else {
            return
        }

        pendingURLs.removeAll()
        activeViewModel.openFileFromSystem(at: url)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            OpenFileRouter.shared.open(urls: urls)
        }
    }
}
