import SwiftUI

/// A project row in the disclosure list that expands to show sessions inline.
///
/// Absorbs functionality from the former IconRailView (context menu, settings popover)
/// and SessionDetailView (session list, rename, drag/drop, new session button).
struct ProjectDisclosureRow: View {
    let project: Project
    @Binding var isExpanded: Bool
    @Binding var selectedProjectId: UUID?

    @EnvironmentObject private var store: WorkspaceStore
    @EnvironmentObject private var coordinator: SessionCoordinator

    @State private var settingsProject: Project?
    @State private var showingTemplatePicker = false
    @State private var editingSessionId: UUID?
    @State private var editingName: String = ""
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 2) {
            // Project header row (tap to expand/collapse)
            projectHeader

            // Expanded children: sessions + "New Session" button
            if isExpanded {
                ForEach(sessions) { session in
                    SessionRow(
                        session: session,
                        status: store.globalStatuses[session.id] ?? coordinator.statuses[session.id] ?? .exited,
                        isActive: coordinator.activeSessionId == session.id,
                        isEditing: editingSessionId == session.id,
                        editingName: editingSessionId == session.id ? $editingName : .constant(""),
                        isRenameFocused: $renameFieldFocused,
                        onCommitRename: { commitRename(session: session) },
                        onCancelRename: { cancelRename() }
                    )
                    .padding(.leading, 20)
                    .onTapGesture(count: 2) {
                        beginRename(session: session)
                    }
                    .onTapGesture {
                        selectedProjectId = project.id
                        coordinator.focusSession(id: session.id)
                    }
                    .contextMenu {
                        Button("Rename") {
                            beginRename(session: session)
                        }
                        Divider()
                        if coordinator.isRunning(id: session.id) {
                            Button("Stop") {
                                coordinator.closeSession(id: session.id)
                            }
                        } else {
                            Button("Relaunch") {
                                relaunchSession(session)
                            }
                            Button("Remove", role: .destructive) {
                                coordinator.clearRuntime(id: session.id)
                                store.removeSession(id: session.id)
                            }
                        }
                    }
                    .draggable(session.id.uuidString) {
                        Text(session.name)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let droppedString = items.first,
                              let droppedId = UUID(uuidString: droppedString) else { return false }
                        guard let targetIndex = sessions.firstIndex(where: { $0.id == session.id }) else { return false }
                        store.moveSession(id: droppedId, toIndex: targetIndex, inProject: project.id)
                        return true
                    }
                }

                newSessionButton
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Project Header

    private var projectHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
            selectedProjectId = project.id
        } label: {
            HStack(spacing: 8) {
                // Chevron (rotates on expand)
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)

                // Aggregate status dot
                projectIcon

                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(selectedProjectId == project.id ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Settings\u{2026}") {
                settingsProject = project
            }
            Divider()
            Button(project.isPinned ? "Unpin" : "Pin") {
                store.togglePin(id: project.id)
            }
            Divider()
            Button("Remove", role: .destructive) {
                store.removeProject(id: project.id)
            }
        }
        .popover(
            isPresented: Binding(
                get: { settingsProject?.id == project.id },
                set: { if !$0 { settingsProject = nil } }
            ),
            arrowEdge: .trailing
        ) {
            ProjectSettingsView(project: project) {
                settingsProject = nil
            }
            .environmentObject(store)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name) project\(isExpanded ? ", expanded" : ", collapsed")")
        .accessibilityHint("Double-tap to \(isExpanded ? "collapse" : "expand")")
    }

    // MARK: - Icon

    @ViewBuilder
    private var projectIcon: some View {
        Circle()
            .fill(projectStatusColor)
            .frame(width: 8, height: 8)
    }

    private var projectStatusColor: Color {
        let projectSessions = store.sessions(for: project.id)
        let hasRunning = projectSessions.contains { session in
            let status = store.globalStatuses[session.id]
                ?? coordinator.statuses[session.id]
                ?? .exited
            return status == .running
        }
        return hasRunning ? .green : Color(.tertiaryLabelColor)
    }

    // MARK: - Sessions

    private var sessions: [AgentSession] {
        store.sessions(for: project.id)
    }

    // MARK: - New Session Button

    private var newSessionButton: some View {
        Button(action: handleNewSession) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                Text("New Session")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .popover(isPresented: $showingTemplatePicker) {
            TemplatePickerView(project: project)
        }
    }

    // MARK: - Actions

    private func handleNewSession() {
        selectedProjectId = project.id
        if let defaultId = project.defaultTemplateId,
           !NSEvent.modifierFlags.contains(.option),
           let template = store.templates.first(where: { $0.id == defaultId }) {
            Task {
                await coordinator.createQuickSession(for: project, template: template)
            }
        } else {
            showingTemplatePicker = true
        }
    }

    private func relaunchSession(_ session: AgentSession) {
        guard let template = store.templates.first(where: { $0.id == session.templateId }) else {
            return
        }
        coordinator.clearRuntime(id: session.id)
        Task {
            await coordinator.createSession(session: session, template: template, project: project)
        }
    }

    // MARK: - Rename

    private func beginRename(session: AgentSession) {
        editingName = session.name
        editingSessionId = session.id
        DispatchQueue.main.async {
            renameFieldFocused = true
        }
    }

    private func commitRename(session: AgentSession) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != session.name {
            store.renameSession(id: session.id, name: trimmed)
        }
        editingSessionId = nil
    }

    private func cancelRename() {
        editingSessionId = nil
    }
}
