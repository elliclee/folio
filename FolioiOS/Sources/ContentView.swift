import SwiftUI
import UniformTypeIdentifiers
import FolioCore

struct ContentView: View {
    @Environment(ReaderViewModel.self) private var viewModel
    @State private var isImporting = false

    private var importedContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .html]
        if let markdown = UTType(filenameExtension: "md") { types.append(markdown) }
        if let markdownLong = UTType(filenameExtension: "markdown") { types.append(markdownLong) }
        return types
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = viewModel.palette

        NavigationStack {
            Group {
                if let html = viewModel.htmlDocument {
                    // HTML genuinely needs a browser engine — the one
                    // WebView in Folio. Markdown stays fully native below.
                    HTMLWebView(html: html, baseURL: viewModel.htmlBaseURL)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.blocks) { block in
                                MarkdownBlockView(block: block, palette: palette)
                                    .equatable()
                            }
                        }
                        .frame(maxWidth: MarkdownTypography.readingMeasure, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .background(palette.preview)
                    .textSelection(.enabled)
                }
            }
            .navigationTitle(viewModel.fileName ?? "Folio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Theme", selection: $viewModel.theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme)
                            }
                        }
                        if !viewModel.recents.documents.isEmpty {
                            Section("Recent") {
                                ForEach(viewModel.recents.documents) { document in
                                    Button(document.name) {
                                        viewModel.openRecent(document)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "textformat")
                    }
                }
            }
        }
        .tint(palette.accent)
        .preferredColorScheme(viewModel.theme.colorScheme)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: importedContentTypes
        ) { result in
            if case .success(let url) = result {
                viewModel.open(url: url)
            }
        }
    }
}
