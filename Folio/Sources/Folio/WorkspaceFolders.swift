import Foundation
import Observation

/// Pinned + recent workspace folders, ported from `workspace-folders.ts`.
/// One shared store backs every window (the Tauri version syncs windows
/// through localStorage `storage` events; here observation does it).
struct WorkspaceFolder: Codable, Equatable, Identifiable {
    let name: String
    let path: String

    var id: String { path }

    /// Mirrors `createWorkspaceFolder` / `getFolderName`.
    init(path: String) {
        self.path = path
        let trimmed = path.replacingOccurrences(
            of: "[\\\\/]+$",
            with: "",
            options: .regularExpression
        )
        let lastSegment = trimmed.split(separator: "/").last.map(String.init)
        self.name = lastSegment ?? (trimmed.isEmpty ? path : trimmed)
    }

    init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

struct WorkspaceFolderState: Codable, Equatable {
    var pinned: [WorkspaceFolder] = []
    var recent: [WorkspaceFolder] = []
}

enum WorkspaceFolderRules {
    static let maxRecentFolders = 5

    static func dedupe(_ folders: [WorkspaceFolder]) -> [WorkspaceFolder] {
        var seen = Set<String>()
        return folders.filter { seen.insert($0.path).inserted }
    }

    /// Mirrors `rememberRecentWorkspaceFolder`: most recent first, capped.
    static func rememberRecent(_ state: WorkspaceFolderState, folderPath: String) -> WorkspaceFolderState {
        let folder = WorkspaceFolder(path: folderPath)
        let recent = [folder] + state.recent.filter { $0.path != folder.path }
        return WorkspaceFolderState(
            pinned: dedupe(state.pinned),
            recent: Array(recent.prefix(maxRecentFolders))
        )
    }

    /// Mirrors `pinWorkspaceFolder`.
    static func pin(_ state: WorkspaceFolderState, folderPath: String) -> WorkspaceFolderState {
        WorkspaceFolderState(
            pinned: dedupe(state.pinned + [WorkspaceFolder(path: folderPath)]),
            recent: dedupe(state.recent)
        )
    }

    /// Mirrors `unpinWorkspaceFolder`: unpinning re-files the folder
    /// under recents so it stays reachable.
    static func unpin(_ state: WorkspaceFolderState, folderPath: String) -> WorkspaceFolderState {
        rememberRecent(
            WorkspaceFolderState(
                pinned: state.pinned.filter { $0.path != folderPath },
                recent: state.recent
            ),
            folderPath: folderPath
        )
    }

    /// Mirrors `clearRecentWorkspaceFolders`.
    static func clearRecent(_ state: WorkspaceFolderState) -> WorkspaceFolderState {
        WorkspaceFolderState(pinned: state.pinned, recent: [])
    }

    /// Mirrors `getRecentWorkspaceFolders`: hides recents already pinned.
    static func visibleRecent(_ state: WorkspaceFolderState) -> [WorkspaceFolder] {
        let pinnedPaths = Set(state.pinned.map(\.path))
        return state.recent.filter { !pinnedPaths.contains($0.path) }
    }

    /// Mirrors `normalizeWorkspaceFolderState`.
    static func normalize(_ state: WorkspaceFolderState) -> WorkspaceFolderState {
        WorkspaceFolderState(
            pinned: dedupe(state.pinned),
            recent: Array(dedupe(state.recent).prefix(maxRecentFolders))
        )
    }
}

@MainActor
@Observable
final class WorkspaceFoldersStore {
    static let storageKey = "folio.workspaceFolders.v1"
    static let shared = WorkspaceFoldersStore()

    private let defaults: UserDefaults

    private(set) var state: WorkspaceFolderState {
        didSet { save() }
    }

    var pinned: [WorkspaceFolder] { state.pinned }
    var visibleRecent: [WorkspaceFolder] { WorkspaceFolderRules.visibleRecent(state) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(WorkspaceFolderState.self, from: data) {
            state = WorkspaceFolderRules.normalize(decoded)
        } else {
            state = WorkspaceFolderState()
        }
    }

    func rememberRecent(folderPath: String) {
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: folderPath)
    }

    func pin(folderPath: String) {
        state = WorkspaceFolderRules.pin(state, folderPath: folderPath)
    }

    func unpin(folderPath: String) {
        state = WorkspaceFolderRules.unpin(state, folderPath: folderPath)
    }

    func isPinned(folderPath: String) -> Bool {
        state.pinned.contains { $0.path == folderPath }
    }

    func togglePin(folderPath: String) {
        if isPinned(folderPath: folderPath) {
            unpin(folderPath: folderPath)
        } else {
            pin(folderPath: folderPath)
        }
    }

    func clearRecent() {
        state = WorkspaceFolderRules.clearRecent(state)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(WorkspaceFolderRules.normalize(state)) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
