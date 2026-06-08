import SwiftUI
import FolioCore

/// Native sidebar: `List(.sidebar)` inside a `NavigationSplitView`, with
/// system material, native selection, disclosure triangles, and context
/// menus. Pin/unpin and "open in new window" live in right-click menus,
/// the macOS-native counterpart of the React hover buttons.
struct SidebarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let pinned = viewModel.workspaceFolders.pinned

        // Custom selection (subtle gray rounded pill) drawn by the rows
        // themselves — macOS's built-in List selection forces accent blue
        // and looser rows, which we don't want here.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if !pinned.isEmpty {
                    SidebarSectionHeader("Pinned")
                    ForEach(pinned) { folder in
                        PinnedFolderRow(folder: folder)
                    }
                    Spacer().frame(height: 6)
                }

                if !viewModel.tree.isEmpty {
                    SidebarSectionHeader(viewModel.currentFolderPath == nil ? "Files" : "Workspace")
                    ForEach(viewModel.tree) { node in
                        TreeNodeRow(node: node, depth: 0)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .overlay {
            if viewModel.isLoadingFolder {
                ProgressView("Opening Folder…")
                    .controlSize(.small)
            } else if viewModel.tree.isEmpty && pinned.isEmpty {
                // Compact empty state — no oversized icon/headline.
                VStack(spacing: 8) {
                    Text("Open a folder of Markdown documents.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Folder…") {
                        viewModel.presentOpenFolderDialog()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
    }

    /// Bottom action bar (the native place for sidebar add-buttons).
    private var sidebarFooter: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.presentOpenFolderDialog()
            } label: {
                SwiftUI.Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("Open Folder (⌘O)")

            Button {
                openFolderInNewWindow()
            } label: {
                SwiftUI.Image(systemName: "macwindow.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("Open Folder in New Window (⌘⇧O)")

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private func openFolderInNewWindow() {
        guard let url = presentWorkspaceFolderPicker(
            title: "Open Markdown Folder in New Window"
        ) else { return }

        viewModel.workspaceFolders.rememberRecent(folderPath: url.path)
        openWindow(value: WorkspaceSeed(
            folderPath: url.path,
            theme: viewModel.theme.rawValue
        ))
    }
}

private struct SidebarSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.4)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
    }
}

/// One compact sidebar row with a subtle gray rounded selection/hover
/// background — the look from the reference app, which the native
/// `List(.sidebar)` accent selection can't produce.
private struct SidebarRow<Trailing: View>: View {
    let icon: String
    let title: String
    var depth: Int = 0
    var isSelected = false
    var leadingChevron: Bool? = nil   // nil = not a directory
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let expanded = leadingChevron {
                    SwiftUI.Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 10)
                }
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.leading, CGFloat(depth) * 14 + 6)
            .padding(.trailing, 6)
            .frame(height: 24)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected ? Color.primary.opacity(0.09)
                            : isHovered ? Color.primary.opacity(0.045)
                            : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

extension SidebarRow where Trailing == EmptyView {
    init(icon: String, title: String, depth: Int = 0, isSelected: Bool = false,
         leadingChevron: Bool? = nil, action: @escaping () -> Void) {
        self.init(icon: icon, title: title, depth: depth, isSelected: isSelected,
                  leadingChevron: leadingChevron, action: action) { EmptyView() }
    }
}

private struct PinnedFolderRow: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    let folder: WorkspaceFolder

    var body: some View {
        SidebarRow(icon: "folder", title: folder.name) {
            viewModel.loadFolder(at: URL(fileURLWithPath: folder.path))
        }
        .help(folder.path)
        .contextMenu {
            Button("Open") {
                viewModel.loadFolder(at: URL(fileURLWithPath: folder.path))
            }
            Button("Open in New Window") {
                openWindow(value: WorkspaceSeed(folderPath: folder.path, theme: viewModel.theme.rawValue))
            }
            Divider()
            Button("Unpin") {
                viewModel.workspaceFolders.unpin(folderPath: folder.path)
            }
        }
    }
}

private struct TreeNodeRow: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    let node: MarkdownTreeNode
    let depth: Int

    var body: some View {
        switch node {
        case .directory(let directory):
            let isExpanded = viewModel.expandedDirectories.contains(directory.path)
            let isPinned = viewModel.workspaceFolders.isPinned(folderPath: directory.path)

            SidebarRow(icon: "folder", title: directory.name, depth: depth,
                       leadingChevron: isExpanded) {
                viewModel.toggleDirectory(directory.path)
            } trailing: {
                if isPinned {
                    SwiftUI.Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .help(directory.path)
            .contextMenu { directoryContextMenu(for: directory) }

            if isExpanded {
                ForEach(directory.children) { child in
                    TreeNodeRow(node: child, depth: depth + 1)
                }
            }

        case .file(let file):
            SidebarRow(icon: "doc.text", title: file.name, depth: depth,
                       isSelected: viewModel.activeFile?.path == file.path) {
                viewModel.loadFile(file)
            }
            .help(file.path)
        }
    }

    @ViewBuilder
    private func directoryContextMenu(for directory: MarkdownDirectoryItem) -> some View {
        let isPinned = viewModel.workspaceFolders.isPinned(folderPath: directory.path)

        Button(isPinned ? "Unpin Folder" : "Pin Folder") {
            viewModel.workspaceFolders.togglePin(folderPath: directory.path)
        }
        Button("Open in New Window") {
            openWindow(value: WorkspaceSeed(folderPath: directory.path, theme: viewModel.theme.rawValue))
        }
    }
}
