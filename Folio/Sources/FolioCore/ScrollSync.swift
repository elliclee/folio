import Foundation

/// Scroll-sync logic ported from `scroll-position.ts`: panes sync by
/// scrollable-distance percentage, and whichever pane the user is
/// actively scrolling owns the sync until it has been idle for 180ms
/// (prevents feedback loops between the two panes).
public enum ScrollSyncPane {
    case editor
    case preview
}

public struct ScrollMetrics: Equatable {
    public var offset: CGFloat = 0
    public var contentHeight: CGFloat = 0
    public var viewportHeight: CGFloat = 0

    public init(offset: CGFloat = 0, contentHeight: CGFloat = 0, viewportHeight: CGFloat = 0) {
        self.offset = offset
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
    }

    public var scrollableDistance: CGFloat {
        max(0, contentHeight - viewportHeight)
    }
}

/// Mirrors `syncScrollPosition`: returns the target pane's offset.
public func syncedScrollOffset(source: ScrollMetrics, target: ScrollMetrics) -> CGFloat {
    let sourceDistance = source.scrollableDistance
    let targetDistance = target.scrollableDistance

    guard sourceDistance > 0, targetDistance > 0 else {
        return 0
    }

    return (source.offset / sourceDistance) * targetDistance
}

/// Mirrors `createScrollSyncController`'s active-pane guard.
@MainActor
public final class ScrollSyncController {
    public static let releaseDelay: TimeInterval = 0.18

    private var activePane: ScrollSyncPane?
    private var releaseTask: Task<Void, Never>?

    public init() {}

    /// Returns true when `pane` is allowed to drive the other pane.
    public func beginScroll(from pane: ScrollSyncPane) -> Bool {
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

    public func reset() {
        releaseTask?.cancel()
        releaseTask = nil
        activePane = nil
    }
}

/// Connects the two panes. Each pane registers a setter for programmatic
/// scrolling and reports its scroll events here.
@MainActor
public final class PaneScrollCoordinator {
    private let controller = ScrollSyncController()

    public var editorMetrics = ScrollMetrics()
    public var previewMetrics = ScrollMetrics()

    /// Setters installed by the pane views (offset in points).
    public var scrollEditor: ((CGFloat) -> Void)?
    public var scrollPreview: ((CGFloat) -> Void)?

    public var isSyncEnabled = false

    public init() {}

    public func editorDidScroll(_ metrics: ScrollMetrics) {
        editorMetrics = metrics
        guard isSyncEnabled, controller.beginScroll(from: .editor) else { return }
        scrollPreview?(syncedScrollOffset(source: metrics, target: previewMetrics))
    }

    public func previewDidScroll(_ metrics: ScrollMetrics) {
        previewMetrics = metrics
        guard isSyncEnabled, controller.beginScroll(from: .preview) else { return }
        scrollEditor?(syncedScrollOffset(source: metrics, target: editorMetrics))
    }

    /// Mirrors `resetScrollPositions` when a new document loads.
    public func resetScrollPositions() {
        controller.reset()
        scrollEditor?(0)
        scrollPreview?(0)
    }
}
