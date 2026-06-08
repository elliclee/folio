import Foundation
import Observation

/// A recently opened document. `bookmark` is reserved for iOS, where
/// reopening a sandboxed file needs a security-scoped bookmark rather
/// than a path; on macOS the path is enough.
public struct RecentDocument: Codable, Equatable, Identifiable {
    public let name: String
    public let path: String
    public var bookmark: Data?

    public var id: String { path }

    public init(name: String, path: String, bookmark: Data? = nil) {
        self.name = name
        self.path = path
        self.bookmark = bookmark
    }
}

/// Pure rules for the recent-documents list (newest first, de-duplicated
/// by path, capped) — testable without any storage.
public enum RecentDocumentRules {
    public static let maxRecentDocuments = 3

    public static func remember(
        _ documents: [RecentDocument],
        _ document: RecentDocument,
        limit: Int = maxRecentDocuments
    ) -> [RecentDocument] {
        let deduped = documents.filter { $0.path != document.path }
        return Array(([document] + deduped).prefix(limit))
    }
}

/// Persists the recent-documents list in `UserDefaults`. One shared
/// instance backs every window, like `WorkspaceFoldersStore`.
@MainActor
@Observable
public final class RecentDocumentsStore {
    public static let storageKey = "folio.recentDocuments.v1"
    public static let shared = RecentDocumentsStore()

    private let defaults: UserDefaults

    public private(set) var documents: [RecentDocument] {
        didSet { save() }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([RecentDocument].self, from: data) {
            documents = Array(decoded.prefix(RecentDocumentRules.maxRecentDocuments))
        } else {
            documents = []
        }
    }

    public func remember(name: String, path: String, bookmark: Data? = nil) {
        documents = RecentDocumentRules.remember(
            documents,
            RecentDocument(name: name, path: path, bookmark: bookmark)
        )
    }

    public func clear() {
        documents = []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(documents) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
