import SwiftUI

/// The far-left icon rail showing project icons.
///
/// Collapsed: 52pt wide (icons only). Expanded: 220pt wide (icons + labels).
/// Expansion happens on hover with a 100ms delay to prevent accidental triggers.
/// The expanded state uses an opaque background to overlay the detail panel.
struct IconRailView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Binding var selectedProjectId: UUID?
    @State private var isExpanded = false
    @State private var hoverTask: Task<Void, Never>?

    /// Project whose settings popover is currently shown (nil = hidden).
    @State private var settingsProject: Project?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            projectList

            Spacer()

            addButton
        }
        .padding(.vertical, 8)
        .frame(width: isExpanded ? WorkspaceLayout.expandedRailWidth : WorkspaceLayout.collapsedRailWidth)
        .frame(maxHeight: .infinity)
        .background(.thickMaterial)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75),
            value: isExpanded
        )
        .onHover { hovering in
            hoverTask?.cancel()
            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(hovering ? 100 : 150))
                guard !Task.isCancelled else { return }
                isExpanded = hovering
            }
        }
        .onDisappear {
            hoverTask?.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Project rail")
    }

    // MARK: - Subviews

    private var projectList: some View {
        ForEach(store.sortedProjects) { project in
            ProjectRailItem(
                project: project,
                isSelected: project.id == selectedProjectId,
                isExpanded: isExpanded
            )
            .onTapGesture {
                selectedProjectId = project.id
            }
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
        }
    }

    private var addButton: some View {
        Button(action: presentFolderPicker) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 36, height: 36)

                if isExpanded {
                    Text("Add Project")
                        .font(.system(size: 13, weight: .medium))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Add project")
    }

    // MARK: - Actions

    private func presentFolderPicker() {
        if let id = store.addProjectViaFolderPicker() {
            selectedProjectId = id
        }
    }
}
