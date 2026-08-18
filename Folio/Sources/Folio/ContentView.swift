import SwiftUI
import FolioCore

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isOutlineOpen = false

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = viewModel.palette

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 380)
        } detail: {
            VStack(spacing: 0) {
                if viewModel.isFindOpen {
                    FindBarView()
                    Divider().overlay(palette.border)
                }

                main(palette: palette)
            }
            .background(palette.window)
            .overlay(alignment: .bottom) {
                if let message = viewModel.copyConfirmation {
                    toast(message, palette: palette)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: viewModel.copyConfirmation)
        }
        .preferredColorScheme(viewModel.theme.colorScheme)
        .navigationTitle(viewModel.activeFile?.name ?? "Folio")
        .navigationSubtitle(viewModel.isDirty ? "Edited" : "")
        .toolbar {
            ToolbarItemGroup {
                let outline = viewModel.outline
                Button {
                    isOutlineOpen.toggle()
                } label: {
                    Label("Document Outline", systemImage: "text.book.closed")
                }
                .help("Document Outline")
                .disabled(outline.isEmpty)
                .popover(isPresented: $isOutlineOpen, arrowEdge: .bottom) {
                    OutlinePopover(outline: outline, isPresented: $isOutlineOpen)
                        .environment(viewModel)
                }

                Picker("View Mode", selection: $viewModel.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Preview or Split editing")

                // The toolbar suppresses item titles — which is why the
                // buttons around this one show icons only — so a plain
                // `Picker` here renders as a popup button with no text at
                // all: accessibility reports the right selection, but
                // nothing is drawn. Driving the menu by hand and forcing
                // the label style keeps the theme name visible.
                Menu {
                    Picker("Theme", selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(viewModel.theme.label, systemImage: "paintpalette")
                }
                .labelStyle(.titleAndIcon)
                .help("Reading theme")

                Button {
                    viewModel.openFind()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Find in Document (⌘F)")

                Button {
                    viewModel.copyMarkdown()
                } label: {
                    Label("Copy Markdown", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.markdown.isEmpty)
                .help("Copy Markdown (⇧⌘C)")

                Button {
                    viewModel.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.activeFile == nil || !viewModel.isDirty || viewModel.isSaving)
                .help("Save (⌘S)")

                Button {
                    viewModel.printDocument()
                } label: {
                    Label("Export PDF", systemImage: "printer")
                }
                .help("Print / Save as PDF (⌘P)")
            }
        }
        .onAppear {
            viewModel.scrollCoordinator.isSyncEnabled = viewModel.viewMode == .split
        }
    }

    @ViewBuilder
    private func main(palette: ThemePalette) -> some View {
        @Bindable var viewModel = viewModel

        // Pane headers only appear in split mode, where they distinguish
        // the two panes; the window title already names the document.
        HSplitView {
            if viewModel.viewMode == .split {
                VStack(spacing: 0) {
                    paneHeader(icon: "square.and.pencil", title: "EDITOR", palette: palette)
                    MarkdownEditor(
                        text: $viewModel.markdown,
                        palette: palette,
                        coordinator: viewModel.scrollCoordinator
                    )
                }
                .frame(minWidth: 280)
                .background(palette.editor)
            }

            VStack(spacing: 0) {
                if viewModel.viewMode == .split {
                    paneHeader(icon: "doc.richtext", title: "PREVIEW", palette: palette)
                }
                PreviewView()
            }
            .frame(minWidth: 320, maxWidth: .infinity)
        }
    }

    /// Brief confirmation for actions with no visible result of their own.
    private func toast(_ message: String, palette: ThemePalette) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(palette.border))
            .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
            .padding(.bottom, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func paneHeader(icon: String, title: String, palette: ThemePalette) -> some View {
        HStack(spacing: 6) {
            SwiftUI.Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.55)
            Spacer()
        }
        .foregroundStyle(palette.textMuted)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

/// Popover showing the document outline. Clicking a heading scrolls the
/// preview to it and dismisses the popover.
private struct OutlinePopover: View {
    @Environment(AppViewModel.self) private var viewModel
    let outline: [OutlineItem]
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(outline) { item in
                    OutlinePopoverRow(item: item) {
                        viewModel.requestScroll(to: item.id)
                        isPresented = false
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360,
               minHeight: 80, maxHeight: 420)
    }
}

private struct OutlinePopoverRow: View {
    let item: OutlineItem
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Subtle left-border accent for h1
                if item.level == 1 {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 2, height: 14)
                        .padding(.trailing, 8)
                } else {
                    Color.clear.frame(width: CGFloat(item.level - 1) * 14)
                }
                Text(item.title)
                    .font(.system(size: item.level == 1 ? 13 : 12))
                    .fontWeight(item.level == 1 ? .semibold : .regular)
                    .foregroundStyle(item.level == 1 ? .primary : .secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
