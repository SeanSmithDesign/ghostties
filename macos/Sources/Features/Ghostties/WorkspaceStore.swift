import Foundation
import AppKit
import SwiftUI

/// Central state manager for workspace projects.
///
/// Created once and shared across all windows via @EnvironmentObject.
/// All windows see the same project list so sidebar state stays in sync.
final class WorkspaceStore: ObservableObject {
    /// Shared instance used by all windows. Created once on first access.
    static let shared = WorkspaceStore()

    @Published private(set) var projects: [Project] = []
    @Published var selectedProjectID: UUID?

    /// Maximum number of recent (unpinned) projects to keep.
    private let maxRecents = 10

    init() {
        let state = WorkspacePersistence.load()
        self.projects = state.projects
        self.selectedProjectID = state.projects.first?.id
    }

    // MARK: - Computed

    /// Pinned projects first (by name), then recent unpinned (by lastOpenedAt descending).
    var sortedProjects: [Project] {
        let pinned = projects.filter(\.isPinned).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let recent = projects.filter { !$0.isPinned }.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        return pinned + recent
    }

    var selectedProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: - Actions

    func addProject(at url: URL) {
        // Don't add duplicates (same path).
        let path = url.path
        if let index = projects.firstIndex(where: { $0.rootPath == path }) {
            projects[index].lastOpenedAt = Date()
            projects[index].isPinned = true
            selectedProjectID = projects[index].id
            persist()
            return
        }

        let project = Project(
            name: url.lastPathComponent,
            rootPath: path,
            isPinned: true
        )
        projects.append(project)
        selectedProjectID = project.id
        trimRecents()
        persist()
    }

    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        if selectedProjectID == id {
            selectedProjectID = projects.first?.id
        }
        persist()
    }

    func togglePin(id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].isPinned.toggle()
        persist()
    }

    func select(id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectID = id
        // Touch lastOpenedAt so unpinned projects bubble up.
        if let index = projects.firstIndex(where: { $0.id == id }) {
            projects[index].lastOpenedAt = Date()
            persist()
        }
    }

    /// Present an NSOpenPanel folder picker and add the chosen project.
    func addProjectViaFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder"
        panel.prompt = "Add Project"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addProject(at: url)
    }

    // MARK: - Private

    private func trimRecents() {
        let recent = projects.filter { !$0.isPinned }.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        if recent.count > maxRecents {
            let idsToRemove = Set(recent.dropFirst(maxRecents).map(\.id))
            projects.removeAll { idsToRemove.contains($0.id) }
        }
    }

    private func persist() {
        let state = WorkspacePersistence.State(projects: projects)
        WorkspacePersistence.save(state)
    }
}
