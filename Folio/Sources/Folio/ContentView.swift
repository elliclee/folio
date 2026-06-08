import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
        }
        .preferredColorScheme(viewModel.theme.colorScheme)
        .navigationTitle(viewModel.activeFile?.name ?? "Folio")
        .navigationSubtitle(viewModel.isDirty ? "Edited" : "")
        .toolbar {
            ToolbarItemGroup {
                Picker("View Mode", selection: $viewModel.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Preview or Split editing")

                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .help("Reading theme")

                Button {
                    viewModel.openFind()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Find in Document (⌘F)")

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
