import SwiftUI
import UniformTypeIdentifiers
import FolioCore

struct ContentView: View {
    @Environment(ReaderViewModel.self) private var viewModel
    @State private var isImporting = false

    private func documentIcon(_ name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "html", "htm": "globe"
        default: "doc.text"
        }
    }

    // Union of broad text types AND extension-derived types: on devices
    // with no app declaring the markdown UTI, .md gets a dynamic type that
    // doesn't conform to public.text, so the by-extension types are what
    // actually keep .md selectable. A file is enabled if it matches any.
    // The app now declares net.daringfireball.markdown (UTImportedType),
    // so it resolves to a real type that conforms to public.plain-text —
    // .md is reliably selectable. Plain text + html cover the rest.
    private var importedContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .html]
        if let markdown = UTType("net.daringfireball.markdown") {
            types.insert(markdown, at: 0)
        }
        for ext in ["md", "markdown", "mdown", "mkd", "htm"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
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
                // Dedicated history menu: recently opened documents.
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if viewModel.recents.documents.isEmpty {
                            Text("No Recent Documents")
                        } else {
                            ForEach(viewModel.recents.documents) { document in
                                Button {
                                    viewModel.openRecent(document)
                                } label: {
                                    Label(document.name, systemImage: documentIcon(document.name))
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                viewModel.recents.clear()
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .disabled(viewModel.recents.documents.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Theme", selection: $viewModel.theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme)
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
        .sheet(isPresented: $isImporting) {
            DocumentPicker(contentTypes: importedContentTypes) { url in
                viewModel.open(url: url)
            }
            .ignoresSafeArea()
        }
        .alert("Couldn’t open file", isPresented: $viewModel.errorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
