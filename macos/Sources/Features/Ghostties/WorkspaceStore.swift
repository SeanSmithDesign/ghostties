import Foundation
import SwiftUI

/// Central state manager for workspace projects.
///
/// Manages the global project list shared across all windows.
/// Per-window state (like which project is selected) lives in the view layer.
@MainActor
final class WorkspaceStore: ObservableObject {
    /// Shared instance used by all windows. Created once on first access.
    static let shared = WorkspaceStore()

    @Published private(set) var projects: [Project] = []

    private init() {
        let state = WorkspacePersistence.load()
        self.projects = state.projects
    }

    // MARK: - Computed

    /// Pinned projects first (by name), then unpinned (by name).
    var sortedProjects: [Project] {
        let pinned = projects.filter(\.isPinned)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let unpinned = projects.filter { !$0.isPinned }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return pinned + unpinned
    }

    // MARK: - Actions

    func addProject(at url: URL) {
        let path = url.standardizedFileURL.path
        // Don't add duplicates (same path).
        if let index = projects.firstIndex(where: { $0.rootPath == path }) {
            projects[index].isPinned = true
            persist()
            return
        }

        let project = Project(
            name: url.lastPathComponent,
            rootPath: path,
            isPinned: true
        )
        projects.append(project)
        persist()
    }

    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        persist()
    }

    func togglePin(id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].isPinned.toggle()
        persist()
    }

    // MARK: - Private

    private func persist() {
        let state = WorkspacePersistence.State(projects: projects)
        WorkspacePersistence.save(state)
    }
}
