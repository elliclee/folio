import Foundation

/// What kind of document a path holds. HTML is rendered in a WebView;
/// everything else goes through the native Markdown pipeline.
public enum DocumentKind: Equatable {
    case markdown
    case html

    public static func from(path: String) -> DocumentKind {
        switch (path as NSString).pathExtension.lowercased() {
        case "html", "htm": .html
        default: .markdown
        }
    }
}

#if canImport(WebKit)
import SwiftUI
import WebKit

/// A `WKWebView` that renders a local HTML string. HTML genuinely needs a
/// browser engine, so this is the one deliberate WebView in Folio — the
/// Markdown path stays fully native. Shared by the macOS and iOS apps.
public struct HTMLWebView {
    public let html: String
    /// Directory used to resolve relative resources (CSS/images).
    public let baseURL: URL?

    public init(html: String, baseURL: URL? = nil) {
        self.html = html
        self.baseURL = baseURL
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        #if os(iOS)
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        #endif
        return webView
    }

    private func load(into webView: WKWebView, coordinator: Coordinator) {
        guard coordinator.loadedHTML != html else { return }
        coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var loadedHTML: String?
    }
}

#if os(macOS)
extension HTMLWebView: NSViewRepresentable {
    public func makeNSView(context: Context) -> WKWebView { makeWebView() }
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        load(into: nsView, coordinator: context.coordinator)
    }
}
#else
extension HTMLWebView: UIViewRepresentable {
    public func makeUIView(context: Context) -> WKWebView { makeWebView() }
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        load(into: uiView, coordinator: context.coordinator)
    }
}
#endif
#endif
