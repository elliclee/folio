import AppKit
import SwiftUI

/// Native AppKit plain-text editor for the split view — the counterpart
/// of the `<textarea>` in App.tsx, with real macOS text editing (undo,
/// IME, selection) for free.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let palette: ThemePalette
    let coordinator: PaneScrollCoordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.autoresizingMask = [.width]

        textView.string = text
        applyTheme(to: textView, scrollView: scrollView)

        // Observe scrolling for the editor → preview sync.
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        context.coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak scrollView] _ in
            guard let scrollView else { return }
            MainActor.assumeIsolated {
                context.coordinator.reportScroll(of: scrollView)
            }
        }

        // Install the programmatic setter for preview → editor sync.
        coordinator.scrollEditor = { [weak scrollView] offset in
            guard let scrollView else { return }
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: offset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.parent = self

        // Only push external changes (file load) into the view; edits made
        // in the view already match `text`.
        if textView.string != text {
            textView.string = text
        }

        applyTheme(to: textView, scrollView: scrollView)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        if let observer = coordinator.scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func applyTheme(to textView: NSTextView, scrollView: NSScrollView) {
        let background = NSColor(palette.editor)
        let foreground = NSColor(palette.textPrimary)

        scrollView.backgroundColor = background
        textView.backgroundColor = background
        textView.textColor = foreground
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.insertionPointColor = NSColor(palette.accent)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(palette.accent).withAlphaComponent(0.35),
        ]
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: foreground,
        ]
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var scrollObserver: NSObjectProtocol?

        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }

        nonisolated func textDidChange(_ notification: Notification) {
            MainActor.assumeIsolated {
                guard let textView = notification.object as? NSTextView else { return }
                parent.text = textView.string
            }
        }

        func reportScroll(of scrollView: NSScrollView) {
            let clipView = scrollView.contentView
            let metrics = ScrollMetrics(
                offset: clipView.bounds.origin.y,
                contentHeight: scrollView.documentView?.frame.height ?? 0,
                viewportHeight: clipView.bounds.height
            )
            parent.coordinator.editorDidScroll(metrics)
        }
    }
}
