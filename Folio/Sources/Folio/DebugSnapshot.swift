import AppKit

/// Debug helper: `FOLIO_SNAPSHOT=/tmp/shot.png` writes a PNG of the
/// main window ~2s after launch. The app renders its own window, so this
/// works without the Screen Recording permission `screencapture` needs.
enum DebugSnapshot {
    static func armIfRequested() {
        guard let outputPath = ProcessInfo.processInfo.environment["FOLIO_SNAPSHOT"] else {
            return
        }

        let delay = ProcessInfo.processInfo.environment["FOLIO_SNAPSHOT_DELAY"]
            .flatMap(Double.init) ?? 3

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            capture(to: outputPath)
        }
    }

    private static func capture(to outputPath: String) {
        guard
            let window = NSApp.windows.first(where: { $0.isVisible }),
            let contentView = window.contentView,
            let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds)
        else {
            NSLog("DebugSnapshot: no visible window to capture")
            return
        }

        logSidebarDiagnostics(in: contentView)

        contentView.cacheDisplay(in: contentView.bounds, to: bitmap)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            NSLog("DebugSnapshot: failed to encode PNG")
            return
        }

        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            NSLog("DebugSnapshot: wrote %@", outputPath)
        } catch {
            NSLog("DebugSnapshot: %@", error.localizedDescription)
        }
    }

    /// Snapshot compositing can't render NSVisualEffectView backdrops, so
    /// also log what the sidebar actually contains.
    private static func logSidebarDiagnostics(in root: NSView) {
        var tableViews: [NSTableView] = []
        var stack: [NSView] = [root]
        while let view = stack.popLast() {
            if let table = view as? NSTableView {
                tableViews.append(table)
            }
            stack.append(contentsOf: view.subviews)
        }

        for table in tableViews {
            NSLog(
                "DebugSnapshot: sidebar table rows=%d visibleRect=%@",
                table.numberOfRows,
                NSStringFromRect(table.visibleRect)
            )
        }
        if tableViews.isEmpty {
            NSLog("DebugSnapshot: no NSTableView found in window")
        }
    }
}
