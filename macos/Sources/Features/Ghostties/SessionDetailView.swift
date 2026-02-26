import SwiftUI

/// Shows the session list for a selected project in the detail panel.
///
/// Displays active and exited sessions with status indicators, supports
/// click-to-focus, inline rename (double-click), drag-and-drop reorder,
/// context menu actions, and a "New Session" button within the scroll area.
struct SessionDetailView: View {
    let project: Project

    @EnvironmentObject private var store: WorkspaceStore
    @EnvironmentObject private var coordinator: SessionCoordinator

    @State private var showingTemplatePicker = false
    @State private var showingSettings = false
    @State private var editingSessionId: UUID?
    @State private var editingName: String = ""
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(.quaternary)
                .frame(height: 0.5)
            sessionList
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(project.rootPath)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Project settings")
            .popover(isPresented: $showingSettings) {
                ProjectSettingsView(project: project) {
                    showingSettings = false
                }
                .environmentObject(store)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Session List

    private var sessions: [AgentSession] {
        store.sessions(for: project.id)
    }

    @ViewBuilder
    private var sessionList: some View {
        if sessions.isEmpty {
            emptySessionState
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
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
                        .onTapGesture(count: 2) {
                            beginRename(session: session)
                        }
                        .onTapGesture {
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
                            // Drag preview: a lightweight label.
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

                    // "+ New Session" scrolls with the session list (not bottom-pinned).
                    newSessionButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }

    private var emptySessionState: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)

            Text("No sessions")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            newSessionButton
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - New Session Button

    private var newSessionButton: some View {
        Button(action: handleNewSession) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                Text("New Session")
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .popover(isPresented: $showingTemplatePicker) {
            TemplatePickerView(project: project)
        }
    }

    // MARK: - Actions

    private func handleNewSession() {
        // If a default template is set, create session immediately.
        // Option-click always shows the picker.
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
        // Defer focus to next run loop so the TextField is in the hierarchy.
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

// MARK: - Session Row

struct SessionRow: View {
    let session: AgentSession
    let status: SessionStatus
    var isActive: Bool = false
    var isEditing: Bool = false
    @Binding var editingName: String
    var isRenameFocused: FocusState<Bool>.Binding
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusIndicator

            if isEditing {
                TextField("Session name", text: $editingName)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused(isRenameFocused)
                    .onSubmit { onCommitRename() }
                    .onExitCommand { onCancelRename() }
                    .onChange(of: isRenameFocused.wrappedValue) { focused in
                        // Commit on focus loss (clicking away).
                        if !focused, isEditing { onCommitRename() }
                    }
            } else {
                Text(session.name)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 32)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name), \(statusLabel)\(isActive ? ", active" : "")")
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .exited: return Color(.tertiaryLabelColor)
        case .killed: return .red
        }
    }

    private var statusLabel: String {
        switch status {
        case .running: return "running"
        case .exited: return "exited"
        case .killed: return "killed"
        }
    }
}
