import SwiftUI

/// Renders a Markdown image: remote URLs stream via `AsyncImage`, local
/// (relative) paths resolve against the document's base URL and load from
/// disk. Falls back to a labelled placeholder when it can't load.
public struct MarkdownImageView: View {
    let source: String
    let alt: String
    let baseURL: URL?
    let palette: ThemePalette

    public init(source: String, alt: String, baseURL: URL?, palette: ThemePalette) {
        self.source = source
        self.alt = alt
        self.baseURL = baseURL
        self.palette = palette
    }

    private var resolvedURL: URL? {
        if let url = URL(string: source), let scheme = url.scheme, !scheme.isEmpty {
            return url  // http/https/file
        }
        // Relative path → resolve against the document's directory.
        return baseURL?.appendingPathComponent(source)
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if let url = resolvedURL, let scheme = url.scheme, scheme == "http" || scheme == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    styled(image)
                case .empty:
                    placeholder(systemImage: "photo", text: "Loading…")
                case .failure:
                    placeholder(systemImage: "photo.badge.exclamationmark", text: alt.isEmpty ? "Image unavailable" : alt)
                @unknown default:
                    placeholder(systemImage: "photo", text: alt)
                }
            }
        } else if let url = resolvedURL, let local = PlatformImageLoader.image(at: url) {
            styled(local)
        } else {
            placeholder(systemImage: "photo", text: alt.isEmpty ? "Image" : alt)
        }
    }

    private func styled(_ image: SwiftUI.Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.border, lineWidth: 1)
            )
    }

    private func placeholder(systemImage: String, text: String) -> some View {
        HStack(spacing: 8) {
            SwiftUI.Image(systemName: systemImage)
            Text(text).lineLimit(1)
        }
        .font(.system(size: MarkdownTypography.bodySize - 2))
        .foregroundStyle(palette.textMuted)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(palette.btnHover.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Loads a local image file into a SwiftUI `Image` on either platform.
enum PlatformImageLoader {
    static func image(at url: URL) -> SwiftUI.Image? {
        guard url.isFileURL, let data = try? Data(contentsOf: url) else { return nil }
        #if canImport(AppKit)
        if let nsImage = NSImage(data: data) { return Image(nsImage: nsImage) }
        #elseif canImport(UIKit)
        if let uiImage = UIImage(data: data) { return Image(uiImage: uiImage) }
        #endif
        return nil
    }
}

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
