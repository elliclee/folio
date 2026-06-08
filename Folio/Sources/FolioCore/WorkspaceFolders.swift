import Foundation
import Observation

/// Pinned + recent workspace folders, ported from `workspace-folders.ts`.
/// One shared store backs every window (the Tauri version syncs windows
/// through localStorage `storage` events; here observation does it).
public struct WorkspaceFolder: Codable, Equatable, Identifiable {
    public let name: String
    public let path: String

    public var id: String { path }

    /// Mirrors `createWorkspaceFolder` / `getFolderName`.
    public init(path: String) {
        self.path = path
        let trimmed = path.replacingOccurrences(
            of: "[\\\\/]+$",
            with: "",
            options: .regularExpression
        )
        let lastSegment = trimmed.split(separator: "/").last.map(String.init)
        self.name = lastSegment ?? (trimmed.isEmpty ? path : trimmed)
    }

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct WorkspaceFolderState: Codable, Equatable {
    public var pinned: [WorkspaceFolder] = []
    public var recent: [WorkspaceFolder] = []

    public init(pinned: [WorkspaceFolder] = [], recent: [WorkspaceFolder] = []) {
        self.pinned = pinned
        self.recent = recent
    }
}

public enum WorkspaceFolderRules {
    public static let maxRecentFolders = 5

    public static func dedupe(_ folders: [WorkspaceFolder]) -> [WorkspaceFolder] {
        var seen = Set<String>()
        return folders.filter { seen.insert($0.path).inserted }
    }

    /// Mirrors `rememberRecentWorkspaceFolder`: most recent first, capped.
    public static func rememberRecent(_ state: WorkspaceFolderState, folderPath: String) -> WorkspaceFolderState {
        let folder = WorkspaceFolder(path: folderPath)
        let recent = [folder] + state.recent.filter { $0.path != folder.path }
        return WorkspaceFolderState(
            pinned: dedupe(state.pinned),
            recent: Array(recent.prefix(maxRecentFolders))
        )
    }

    /// Mirrors `pinWorkspaceFolder`.
    public static func pin(_ state: WorkspaceFolderState, folderPath: String) -> WorkspaceFolderState {
        WorkspaceFolderState(
            pinned: dedupe(state.pinned + [WorkspaceFolder(path: folderPath)]),
            recent: dedupe(state.recent)
        )
    }

    /// Mirrors `unpinWorkspaceFolder`: unpinning re-files the folder
    /// under recents so it stays reachable.
    public static func unpin(_ state: WorkspaceFolderState, folderPath: String) -> WorkspaceFolderState {
        rememberRecent(
            WorkspaceFolderState(
                pinned: state.pinned.filter { $0.path != folderPath },
                recent: state.recent
            ),
            folderPath: folderPath
        )
    }

    /// Mirrors `clearRecentWorkspaceFolders`.
    public static func clearRecent(_ state: WorkspaceFolderState) -> WorkspaceFolderState {
        WorkspaceFolderState(pinned: state.pinned, recent: [])
    }

    /// Mirrors `getRecentWorkspaceFolders`: hides recents already pinned.
    public static func visibleRecent(_ state: WorkspaceFolderState) -> [WorkspaceFolder] {
        let pinnedPaths = Set(state.pinned.map(\.path))
        return state.recent.filter { !pinnedPaths.contains($0.path) }
    }

    /// Mirrors `normalizeWorkspaceFolderState`.
    public static func normalize(_ state: WorkspaceFolderState) -> WorkspaceFolderState {
        WorkspaceFolderState(
            pinned: dedupe(state.pinned),
            recent: Array(dedupe(state.recent).prefix(maxRecentFolders))
        )
    }
}

@MainActor
@Observable
public final class WorkspaceFoldersStore {
    public static let storageKey = "folio.workspaceFolders.v1"
    public static let shared = WorkspaceFoldersStore()

    private let defaults: UserDefaults

    private(set) var state: WorkspaceFolderState {
        didSet { save() }
    }

    public var pinned: [WorkspaceFolder] { state.pinned }
    public var visibleRecent: [WorkspaceFolder] { WorkspaceFolderRules.visibleRecent(state) }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(WorkspaceFolderState.self, from: data) {
            state = WorkspaceFolderRules.normalize(decoded)
        } else {
            state = WorkspaceFolderState()
        }
    }

    public func rememberRecent(folderPath: String) {
        state = WorkspaceFolderRules.rememberRecent(state, folderPath: folderPath)
    }

    public func pin(folderPath: String) {
        state = WorkspaceFolderRules.pin(state, folderPath: folderPath)
    }

    public func unpin(folderPath: String) {
        state = WorkspaceFolderRules.unpin(state, folderPath: folderPath)
    }

    public func isPinned(folderPath: String) -> Bool {
        state.pinned.contains { $0.path == folderPath }
    }

    public func togglePin(folderPath: String) {
        if isPinned(folderPath: folderPath) {
            unpin(folderPath: folderPath)
        } else {
            pin(folderPath: folderPath)
        }
    }

    public func clearRecent() {
        state = WorkspaceFolderRules.clearRecent(state)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(WorkspaceFolderRules.normalize(state)) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
