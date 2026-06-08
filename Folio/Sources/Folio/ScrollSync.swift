import Foundation

/// Scroll-sync logic ported from `scroll-position.ts`: panes sync by
/// scrollable-distance percentage, and whichever pane the user is
/// actively scrolling owns the sync until it has been idle for 180ms
/// (prevents feedback loops between the two panes).
enum ScrollSyncPane {
    case editor
    case preview
}

struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0

    var scrollableDistance: CGFloat {
        max(0, contentHeight - viewportHeight)
    }
}

/// Mirrors `syncScrollPosition`: returns the target pane's offset.
func syncedScrollOffset(source: ScrollMetrics, target: ScrollMetrics) -> CGFloat {
    let sourceDistance = source.scrollableDistance
    let targetDistance = target.scrollableDistance

    guard sourceDistance > 0, targetDistance > 0 else {
        return 0
    }

    return (source.offset / sourceDistance) * targetDistance
}

/// Mirrors `createScrollSyncController`'s active-pane guard.
@MainActor
final class ScrollSyncController {
    static let releaseDelay: TimeInterval = 0.18

    private var activePane: ScrollSyncPane?
    private var releaseTask: Task<Void, Never>?

    /// Returns true when `pane` is allowed to drive the other pane.
    func beginScroll(from pane: ScrollSyncPane) -> Bool {
        if let activePane, activePane != pane {
            return false
        }

        activePane = pane

        releaseTask?.cancel()
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.releaseDelay))
            guard !Task.isCancelled else { return }
            self?.activePane = nil
        }

        return true
    }

    func reset() {
        releaseTask?.cancel()
        releaseTask = nil
        activePane = nil
    }
}

/// Connects the two panes. Each pane registers a setter for programmatic
/// scrolling and reports its scroll events here.
@MainActor
final class PaneScrollCoordinator {
    private let controller = ScrollSyncController()

    var editorMetrics = ScrollMetrics()
    var previewMetrics = ScrollMetrics()

    /// Setters installed by the pane views (offset in points).
    var scrollEditor: ((CGFloat) -> Void)?
    var scrollPreview: ((CGFloat) -> Void)?

    var isSyncEnabled = false

    func editorDidScroll(_ metrics: ScrollMetrics) {
        editorMetrics = metrics
        guard isSyncEnabled, controller.beginScroll(from: .editor) else { return }
        scrollPreview?(syncedScrollOffset(source: metrics, target: previewMetrics))
    }

    func previewDidScroll(_ metrics: ScrollMetrics) {
        previewMetrics = metrics
        guard isSyncEnabled, controller.beginScroll(from: .preview) else { return }
        scrollEditor?(syncedScrollOffset(source: metrics, target: editorMetrics))
    }

    /// Mirrors `resetScrollPositions` when a new document loads.
    func resetScrollPositions() {
        controller.reset()
        scrollEditor?(0)
        scrollPreview?(0)
    }
}
