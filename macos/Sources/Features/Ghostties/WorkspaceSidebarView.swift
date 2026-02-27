import SwiftUI

/// Single-column disclosure-style sidebar showing projects with expandable session lists.
///
/// Replaces the previous two-column ZStack layout (icon rail + detail panel) with a
/// Finder/Arc-style list where projects are expandable rows that reveal sessions inline.
/// Multiple projects can be expanded simultaneously.
struct WorkspaceSidebarView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @EnvironmentObject private var coordinator: SessionCoordinator

    /// Per-window selection state — each window can focus a different project.
    @State private var selectedProjectId: UUID?

    /// Tracks which projects are expanded (per-window, not persisted).
    @State private var expandedProjectIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Titlebar toolbar: action buttons right of traffic lights
            titlebarToolbar

            // Scrollable disclosure list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.sortedProjects) { project in
                        ProjectDisclosureRow(
                            project: project,
                            isExpanded: expandedBinding(for: project.id),
                            selectedProjectId: $selectedProjectId
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .accessibilityLabel("Projects")

            Spacer(minLength: 0)
        }
        .background(.clear)
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
            // Auto-expand the project containing the active session.
            autoExpandActiveProject()
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

    // MARK: - Titlebar Toolbar

    private var titlebarToolbar: some View {
        HStack {
            Spacer()
            Button(action: presentFolderPicker) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .focusable()
            .accessibilityLabel("Add project")

            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .focusable()
            .accessibilityLabel("Toggle sidebar")
        }
        .padding(.horizontal, 12)
        .frame(height: WorkspaceLayout.titlebarSpacerHeight)
    }

    // MARK: - Helpers

    private func expandedBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedProjectIds.contains(id) },
            set: { if $0 { expandedProjectIds.insert(id) } else { expandedProjectIds.remove(id) } }
        )
    }

    /// Auto-expand the project that contains the currently active session.
    private func autoExpandActiveProject() {
        guard let activeId = coordinator.activeSessionId,
              let session = store.sessions.first(where: { $0.id == activeId }) else { return }
        expandedProjectIds.insert(session.projectId)
    }

    // MARK: - Actions

    private var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return store.projects.first { $0.id == id }
    }

    private func toggleSidebar() {
        NSApp.sendAction(
            #selector(TerminalController.toggleWorkspaceSidebar(_:)),
            to: nil, from: nil
        )
    }

    private func presentFolderPicker() {
        if let id = store.addProjectViaFolderPicker() {
            selectedProjectId = id
            expandedProjectIds.insert(id)
        }
    }

    /// Create a new session in the currently selected project.
    private func createNewSessionForSelectedProject() {
        guard let project = selectedProject else { return }
        let template: SessionTemplate
        if let defaultId = project.defaultTemplateId,
           let defaultTemplate = store.templates.first(where: { $0.id == defaultId }) {
            template = defaultTemplate
        } else {
            template = SessionTemplate.shell
        }
        // Auto-expand the target project so the new session is visible.
        expandedProjectIds.insert(project.id)
        Task {
            await coordinator.createQuickSession(for: project, template: template)
        }
    }

    /// Move selection to the next or previous project in the sorted list,
    /// auto-expanding the target project.
    private func selectAdjacentProject(offset: Int) {
        let sorted = store.sortedProjects
        guard !sorted.isEmpty else { return }

        guard let currentId = selectedProjectId,
              let currentIndex = sorted.firstIndex(where: { $0.id == currentId }) else {
            selectedProjectId = sorted.first?.id
            if let id = sorted.first?.id { expandedProjectIds.insert(id) }
            return
        }

        let newIndex = (currentIndex + offset + sorted.count) % sorted.count
        let targetId = sorted[newIndex].id
        selectedProjectId = targetId
        expandedProjectIds.insert(targetId)
    }
}
