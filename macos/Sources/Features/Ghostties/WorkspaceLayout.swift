import Foundation

/// Shared layout constants for the workspace sidebar.
enum WorkspaceLayout {
    /// Width of the collapsed icon rail (icons only).
    static let collapsedRailWidth: CGFloat = 52

    /// Width of the expanded icon rail (icons + labels).
    static let expandedRailWidth: CGFloat = 220

    /// Total width of the sidebar container (matches expanded rail).
    static let sidebarWidth: CGFloat = 220

    /// Inset from top, leading, and bottom window edges for the floating panel.
    static let sidebarInset: CGFloat = 8

    /// Corner radius of the floating sidebar container.
    static let sidebarCornerRadius: CGFloat = 12

    /// Gap between the sidebar trailing edge and terminal content (replaces divider).
    static let sidebarTerminalGap: CGFloat = 6
}

// MARK: - Workspace Notifications

extension Notification.Name {
    /// Posted by TerminalController when the user presses Cmd+Shift+].
    /// The notification object is the originating NSWindow.
    static let workspaceSelectNextProject = Notification.Name("com.seansmithdesign.ghostties.workspace.selectNextProject")

    /// Posted by TerminalController when the user presses Cmd+Shift+[.
    /// The notification object is the originating NSWindow.
    static let workspaceSelectPreviousProject = Notification.Name("com.seansmithdesign.ghostties.workspace.selectPreviousProject")

    /// Posted by WorkspaceStore just before a project is removed.
    /// userInfo contains "projectId" (UUID). Coordinators observe this to close
    /// running sessions before the store deletes the project's records.
    static let workspaceProjectWillBeRemoved = Notification.Name("com.seansmithdesign.ghostties.workspace.projectWillBeRemoved")

    /// Posted by TerminalController when the user presses Cmd+Shift+T.
    /// The notification object is the originating NSWindow.
    static let workspaceNewSession = Notification.Name("com.seansmithdesign.ghostties.workspace.newSession")
}
