import SwiftUI
import FolioCore

/// Rendered markdown reading pane, equivalent to the preview pane
/// (`.markdown-content`) in App.tsx.
struct PreviewView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        // Derive content from the view model here; the scroll-owning
        // subview keeps its own @State, so user-scroll invalidations don't
        // re-run this find/highlight work every frame.
        let findResult = viewModel.findResult
        return PreviewScrollView(
            blocks: findResult?.blocks ?? viewModel.renderedBlocks,
            palette: viewModel.palette,
            currentMatchBlockId: findResult?.currentMatchBlockId,
            coordinator: viewModel.scrollCoordinator
        )
    }
}

/// Owns the scroll position. Isolating it here means the user scrolling
/// only re-evaluates this view, and `.equatable()` lets unchanged blocks
/// skip re-rendering during those frames.
private struct PreviewScrollView: View {
    let blocks: [MarkdownBlock]
    let palette: ThemePalette
    let currentMatchBlockId: Int?
    let coordinator: PaneScrollCoordinator

    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block, palette: palette)
                        .equatable()
                }
            }
            .scrollTargetLayout()
            .frame(maxWidth: MarkdownTypography.readingMeasure, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.bottom, 56)
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(
                offset: geometry.contentOffset.y,
                contentHeight: geometry.contentSize.height,
                viewportHeight: geometry.containerSize.height
            )
        } action: { _, metrics in
            coordinator.previewDidScroll(metrics)
        }
        .background(palette.preview)
        .textSelection(.enabled)
        .onAppear {
            coordinator.scrollPreview = { offset in
                scrollPosition.scrollTo(y: offset)
            }
        }
        .onChange(of: currentMatchBlockId) { _, blockId in
            if let blockId {
                withAnimation(.easeOut(duration: 0.15)) {
                    scrollPosition.scrollTo(id: blockId, anchor: .center)
                }
            }
        }
    }
}
