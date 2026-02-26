import Foundation

/// Shared layout constants for the workspace sidebar.
enum WorkspaceLayout {
    /// Width of the sidebar panel.
    static let sidebarWidth: CGFloat = 220

    /// Height reserved at top for window traffic light controls.
    static let titlebarSpacerHeight: CGFloat = 38

    /// Corner radius on the terminal's leading edge (top-left, bottom-left).
    static let terminalCornerRadius: CGFloat = 10
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
