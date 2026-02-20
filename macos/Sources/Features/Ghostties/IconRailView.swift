import SwiftUI

/// The far-left icon rail showing project icons.
///
/// Collapsed: 52pt wide (icons only). Expanded: 220pt wide (icons + labels).
/// Expansion happens on hover with a 100ms delay to prevent accidental triggers.
/// The expanded state uses an opaque background to overlay the detail panel.
struct IconRailView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isExpanded = false
    @State private var hoverTimer: Timer?

    private let collapsedWidth: CGFloat = 52
    private let expandedWidth: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            projectList

            Spacer()

            addButton
        }
        .padding(.vertical, 8)
        .frame(width: isExpanded ? expandedWidth : collapsedWidth)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75),
            value: isExpanded
        )
        .onHover { hovering in
            hoverTimer?.invalidate()
            if hovering {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    isExpanded = true
                }
            } else {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                    isExpanded = false
                }
            }
        }
    }

    // MARK: - Subviews

    private var projectList: some View {
        ForEach(store.sortedProjects) { project in
            ProjectRailItem(
                project: project,
                isSelected: project.id == store.selectedProjectID,
                isExpanded: isExpanded
            )
            .onTapGesture {
                store.select(id: project.id)
            }
            .contextMenu {
                Button(project.isPinned ? "Unpin" : "Pin") {
                    store.togglePin(id: project.id)
                }
                Divider()
                Button("Remove", role: .destructive) {
                    store.removeProject(id: project.id)
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: { store.addProjectViaFolderPicker() }) {
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
}
