import SwiftUI

/// Phase 1: Hardcoded placeholder sidebar for the workspace.
/// This will be replaced with dynamic project/session content in Phase 2.
struct WorkspaceSidebarView: View {
    var body: some View {
        List {
            Section("Projects") {
                Label("Project A", systemImage: "folder.fill")
                Label("Project B", systemImage: "folder.fill")
                Label("Project C", systemImage: "folder.fill")
            }

            Section("Sessions") {
                Label("Shell", systemImage: "terminal.fill")
                Label("Claude Code", systemImage: "sparkles")
                Label("Dev Server", systemImage: "server.rack")
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 300)
    }
}
