import Foundation

/// Three-state sidebar visibility model.
///
/// - `pinned`: Sidebar open, terminal pushed right (floating card).
/// - `closed`: Sidebar hidden, terminal fills window flush.
/// - `overlay`: Sidebar floats on top of full-width terminal (hover-to-reveal).
enum SidebarMode: Int, Codable {
    case pinned
    case closed
    case overlay
}

/// Shared layout constants for the workspace sidebar.
enum WorkspaceLayout {
    /// Width of the sidebar panel.
    static let sidebarWidth: CGFloat = 220

    /// Height reserved at top for window traffic light controls.
    static let titlebarSpacerHeight: CGFloat = 38

    /// Corner radius on the floating terminal panel (all four corners).
    static let terminalCornerRadius: CGFloat = 12

    /// Inset around the terminal panel when sidebar is visible (floating card effect).
    static let terminalInset: CGFloat = 8

    /// Width of the invisible hover trigger strip at the left edge (closed mode).
    static let overlayTriggerWidth: CGFloat = 10
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
