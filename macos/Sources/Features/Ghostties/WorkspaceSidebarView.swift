import SwiftUI

/// The full sidebar: icon rail overlays a detail panel within a fixed-width container.
///
/// Layout strategy: ZStack with .leading alignment. The detail panel is positioned
/// after a 52pt spacer (to avoid the collapsed rail). The icon rail sits on top and
/// expands from 52pt to 220pt on hover, covering the detail panel with an opaque
/// background. This keeps the sidebar width fixed so the terminal never re-layouts.
struct WorkspaceSidebarView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        ZStack(alignment: .leading) {
            // Detail layer: always present, offset past the collapsed rail
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: 52)
                Divider()
                detailPanel
            }

            // Icon rail: overlays the detail panel when expanded
            IconRailView()
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let project = store.selectedProject {
            VStack(alignment: .leading, spacing: 0) {
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                Divider()

                // Phase 3: this becomes SessionDetailView with real session data
                List {
                    Section("Sessions") {
                        Label("Shell", systemImage: "terminal.fill")
                        Label("Claude Code", systemImage: "sparkles")
                    }
                }
                .listStyle(.sidebar)
            }
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

            Button("Add Project") {
                store.addProjectViaFolderPicker()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
