import SwiftUI

/// The full sidebar: icon rail overlays a detail panel within a fixed-width container.
///
/// Layout strategy: ZStack with .leading alignment. The detail panel is positioned
/// after a 52pt spacer (to avoid the collapsed rail). The icon rail sits on top and
/// expands from 52pt to 220pt on hover, covering the detail panel with an opaque
/// background. This keeps the sidebar width fixed so the terminal never re-layouts.
struct WorkspaceSidebarView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @EnvironmentObject private var coordinator: SessionCoordinator

    /// Per-window selection state — each window can focus a different project.
    @State private var selectedProjectId: UUID?

    var body: some View {
        ZStack(alignment: .leading) {
            // Detail layer: always present, offset past the collapsed rail
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: WorkspaceLayout.collapsedRailWidth)
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 0.5)
                detailPanel
            }

            // Icon rail: overlays the detail panel when expanded
            IconRailView(selectedProjectId: $selectedProjectId)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WorkspaceLayout.sidebarCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 1, y: 0)
        .onAppear {
            // Restore persisted project selection, or default to the first project.
            if selectedProjectId == nil {
                if let lastId = store.lastSelectedProjectId,
                   store.projects.contains(where: { $0.id == lastId }) {
                    selectedProjectId = lastId
                } else {
                    selectedProjectId = store.sortedProjects.first?.id
                }
            }
        }
        .onChange(of: selectedProjectId) { newId in
            store.lastSelectedProjectId = newId
            // When the user clicks a different project, auto-focus its last active session.
            if let projectId = newId {
                coordinator.focusLastSession(forProject: projectId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceSelectNextProject)) { notification in
            guard notification.object as? NSWindow === coordinator.containerView?.window else { return }
            selectAdjacentProject(offset: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceSelectPreviousProject)) { notification in
            guard notification.object as? NSWindow === coordinator.containerView?.window else { return }
            selectAdjacentProject(offset: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceNewSession)) { notification in
            guard notification.object as? NSWindow === coordinator.containerView?.window else { return }
            createNewSessionForSelectedProject()
        }
    }

    // MARK: - Detail Panel

    private var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return store.projects.first { $0.id == id }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let project = selectedProject {
            SessionDetailView(project: project)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Add a project")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button("Add Project", action: presentFolderPicker)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func presentFolderPicker() {
        if let id = store.addProjectViaFolderPicker() {
            selectedProjectId = id
        }
    }

    /// Create a new session in the currently selected project.
    /// If the project has a default template, creates immediately; otherwise
    /// falls back to the Shell template for Cmd+Shift+T convenience.
    private func createNewSessionForSelectedProject() {
        guard let project = selectedProject else { return }
        let template: SessionTemplate
        if let defaultId = project.defaultTemplateId,
           let defaultTemplate = store.templates.first(where: { $0.id == defaultId }) {
            template = defaultTemplate
        } else {
            template = SessionTemplate.shell
        }
        Task {
            await coordinator.createQuickSession(for: project, template: template)
        }
    }

    /// Move selection to the next or previous project in the sorted list.
    private func selectAdjacentProject(offset: Int) {
        let sorted = store.sortedProjects
        guard !sorted.isEmpty else { return }

        guard let currentId = selectedProjectId,
              let currentIndex = sorted.firstIndex(where: { $0.id == currentId }) else {
            selectedProjectId = sorted.first?.id
            return
        }

        let newIndex = (currentIndex + offset + sorted.count) % sorted.count
        selectedProjectId = sorted[newIndex].id
    }
}
