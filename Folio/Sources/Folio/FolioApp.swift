import SwiftUI

/// Per-window seed: which folder to open and which theme to inherit —
/// the counterpart of the Tauri `?folder=…&theme=…` workspace-window URL.
struct WorkspaceSeed: Codable, Hashable {
    /// WindowGroup(for:) focuses an existing window when an equal value
    /// is presented again; the unique id forces a fresh window each time.
    var id = UUID()
    var folderPath: String?
    var theme: String?

    var isEmpty: Bool { folderPath == nil && theme == nil }
}

@main
struct FolioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Without an app bundle (plain `swift run` executable) the process
        // starts as a background app; promote it before SwiftUI builds the
        // first scene or no window is created at all.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        DebugSnapshot.armIfRequested()
    }

    var body: some Scene {
        WindowGroup(for: WorkspaceSeed.self) { $seed in
            WorkspaceWindow(seed: seed)
        } defaultValue: {
            WorkspaceSeed()
        }
        .defaultSize(width: 1280, height: 860)
        .commands {
            AppCommands()
        }
    }
}

/// One document window with its own view model (each Tauri workspace
/// window had its own webview state in the same way).
struct WorkspaceWindow: View {
    @State private var viewModel: AppViewModel
    @Environment(\.controlActiveState) private var controlActiveState

    init(seed: WorkspaceSeed) {
        _viewModel = State(initialValue: AppViewModel(seed: seed))
    }

    var body: some View {
        // Window frame persistence (the Tauri window-state.json feature)
        // comes for free: SwiftUI WindowGroup autosaves each window's
        // frame and AppKit validates it against the monitors on restore.
        ContentView()
            .environment(viewModel)
            .frame(minWidth: 640, minHeight: 420)
            .focusedSceneValue(\.appViewModel, viewModel)
            .onChange(of: controlActiveState, initial: true) { _, state in
                // Track the key window so Finder-opened documents land in
                // the window the user is actually using.
                if state == .key {
                    OpenFileRouter.shared.setActive(viewModel)
                }
            }
    }
}

// MARK: - Focused-window plumbing for menu commands

struct AppViewModelFocusedKey: FocusedValueKey {
    typealias Value = AppViewModel
}

extension FocusedValues {
    var appViewModel: AppViewModel? {
        get { self[AppViewModelFocusedKey.self] }
        set { self[AppViewModelFocusedKey.self] = newValue }
    }
}

// MARK: - Menu commands (act on the focused window's view model)

struct AppCommands: Commands {
    @FocusedValue(\.appViewModel) private var viewModel
    @Environment(\.openWindow) private var openWindow

    private var workspaceFolders = WorkspaceFoldersStore.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            // ⌘N "New Window" stays available via WindowGroup defaults.
            Button("New Window") {
                openWindow(value: WorkspaceSeed(theme: viewModel?.theme.rawValue))
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Open Folder…") {
                viewModel?.presentOpenFolderDialog()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(viewModel == nil)

            Button("Open File…") {
                viewModel?.presentOpenFileDialog()
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
            .disabled(viewModel == nil)

            // Mirrors the Tauri "Open Folder in New Window" menu item
            // (⌘⇧O), inheriting the focused window's theme.
            Button("Open Folder in New Window…") {
                guard let url = presentWorkspaceFolderPicker(
                    title: "Open Markdown Folder in New Window"
                ) else { return }

                workspaceFolders.rememberRecent(folderPath: url.path)
                openWindow(value: WorkspaceSeed(
                    folderPath: url.path,
                    theme: viewModel?.theme.rawValue
                ))
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            // Mirrors the Tauri File > Recent Folders submenu.
            Menu("Recent Folders") {
                if workspaceFolders.visibleRecent.isEmpty {
                    Button("No Recent Folders") {}
                        .disabled(true)
                } else {
                    ForEach(workspaceFolders.visibleRecent) { folder in
                        Button(folder.name) {
                            if let viewModel {
                                viewModel.loadFolder(at: URL(fileURLWithPath: folder.path))
                            } else {
                                openWindow(value: WorkspaceSeed(folderPath: folder.path))
                            }
                        }
                    }

                    Divider()

                    Button("Clear Recent Folders") {
                        workspaceFolders.clearRecent()
                    }
                }
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                viewModel?.save()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(viewModel?.activeFile == nil || viewModel?.isDirty != true)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                viewModel?.printDocument()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(viewModel == nil)
        }

        // Mirrors the Edit > Find menu item in the Tauri version.
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find") {
                viewModel?.openFind()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(viewModel == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Preview") {
                viewModel?.viewMode = .preview
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(viewModel == nil)

            Button("Split") {
                viewModel?.viewMode = .split
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(viewModel == nil)
        }
    }
}

/// Shared folder-picker used by menu commands and the sidebar.
@MainActor
func presentWorkspaceFolderPicker(title: String) -> URL? {
    let panel = NSOpenPanel()
    panel.title = title
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK else {
        return nil
    }

    return panel.url
}
