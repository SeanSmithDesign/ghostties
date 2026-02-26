import AppKit
import SwiftUI
import GhosttyKit

/// Bridges the SwiftUI sidebar to Ghostty's terminal surface system.
///
/// Sessions work like **vertical tabs**: each session owns a terminal surface tree
/// (which may contain splits), and the sidebar switches which tree occupies the
/// terminal area. Only one session is visible at a time. Background sessions keep
/// their processes running — the coordinator holds strong references to their trees.
///
/// When the user creates splits via Ghostty shortcuts (Cmd+D), those splits live in
/// the controller's `surfaceTree`. Before switching sessions, we snapshot the current
/// tree back into `sessionTrees` so splits are preserved across switches.
///
/// Each window gets its own coordinator instance, injected via `.environmentObject()`.
/// The coordinator discovers its window controller lazily through the view hierarchy.
@MainActor
final class SessionCoordinator: ObservableObject {
    private let ghostty: Ghostty.App

    /// Weak reference to the container NSView — used to find the window controller.
    weak var containerView: NSView?

    /// The currently displayed session. Nil before any session is created.
    @Published private(set) var activeSessionId: UUID?

    /// Maps session IDs to their full split trees. Trees are kept alive here even
    /// when not displayed — this preserves both the surfaces and any user-created
    /// splits. The active session's tree may be stale (the controller owns the
    /// live version); call `snapshotActiveTree()` to sync before reading.
    private(set) var sessionTrees: [UUID: SplitTree<Ghostty.SurfaceView>] = [:]

    /// Per-window runtime status. Views should prefer `WorkspaceStore.shared.globalStatuses`
    /// for cross-window visibility; this local copy is kept for backward compatibility.
    @Published private(set) var statuses: [UUID: SessionStatus] = [:]

    /// Cache resolved command paths to avoid repeated shell spawns.
    nonisolated(unsafe) private static var resolvedPaths: [String: String] = [:]

    /// Tracks the last focused session per project per window, so clicking a
    /// project in the icon rail can restore the correct terminal session.
    private(set) var lastActiveSessionPerProject: [UUID: UUID] = [:]

    init(ghostty: Ghostty.App) {
        self.ghostty = ghostty
        observeLifecycle()
        observeProjectRemoval()
    }

    // MARK: - Session Creation

    /// Create a new terminal session from a template within a project.
    ///
    /// Resolves the command path off the main thread (with a 3-second timeout),
    /// then creates a Ghostty surface and makes it the sole occupant of the
    /// terminal area. The previous session's tree is snapshotted before the switch.
    @discardableResult
    func createSession(
        session: AgentSession,
        template: SessionTemplate,
        project: Project
    ) async -> Bool {
        guard let ghosttyApp = ghostty.app else { return false }

        // Resolve command off main thread with timeout.
        let resolvedCommand: String? = await {
            guard let cmd = template.command else { return nil }
            let resolveTask = Task.detached { Self.resolveCommand(cmd) }
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(3))
                resolveTask.cancel()
            }
            let result = await resolveTask.value
            timeoutTask.cancel()
            return result
        }()

        var config = Ghostty.SurfaceConfiguration()
        config.workingDirectory = project.rootPath
        config.command = resolvedCommand
        config.environmentVariables = template.environmentVariables

        let newView = Ghostty.SurfaceView(ghosttyApp, baseConfig: config)
        let newTree = SplitTree(view: newView)

        // Snapshot the outgoing session's tree (captures any user-created splits).
        snapshotActiveTree()

        sessionTrees[session.id] = newTree
        setStatus(.running, for: session.id)
        activeSessionId = session.id
        lastActiveSessionPerProject[session.projectId] = session.id

        showSession(newTree, focusView: newView)
        return true
    }

    /// Create a session using the project's default or specified template with auto-generated naming.
    ///
    /// Shared helper used by ProjectDisclosureRow, WorkspaceSidebarView, and TemplatePickerView
    /// to avoid duplicating session-creation logic.
    @discardableResult
    func createQuickSession(for project: Project, template: SessionTemplate) async -> Bool {
        let store = WorkspaceStore.shared
        let count = store.sessions(for: project.id).count
        let name = "\(template.name) \(count + 1)"
        let session = store.addSession(name: name, templateId: template.id, projectId: project.id)
        return await createSession(session: session, template: template, project: project)
    }

    // MARK: - Session Switching

    /// Switch the terminal area to show a specific session.
    ///
    /// Snapshots the current session's tree (preserving splits) before switching.
    /// This is the "vertical tab" behavior — clicking a session in the sidebar
    /// replaces the terminal content with the target session's full split tree.
    func focusSession(id: UUID) {
        guard let tree = sessionTrees[id] else { return }

        // Snapshot the outgoing session's tree first.
        snapshotActiveTree()

        activeSessionId = id
        showSession(tree, focusView: tree.first)

        // Record this session as the last active one for its project.
        if let session = WorkspaceStore.shared.sessions.first(where: { $0.id == id }) {
            lastActiveSessionPerProject[session.projectId] = id
        }
    }

    /// Focus the last active session for a given project, or the first running session if none.
    ///
    /// Called when the user clicks a project in the icon rail to auto-switch the terminal
    /// to the most recently used session in that project.
    func focusLastSession(forProject projectId: UUID) {
        // Try the remembered session first.
        if let lastId = lastActiveSessionPerProject[projectId],
           sessionTrees[lastId] != nil {
            focusSession(id: lastId)
            return
        }

        // Fall back to the first running session in this project.
        let projectSessions = WorkspaceStore.shared.sessions(for: projectId)
        if let running = projectSessions.first(where: { sessionTrees[$0.id] != nil }) {
            focusSession(id: running.id)
        }
    }

    // MARK: - Lifecycle

    /// Check if a session has a live surface.
    func isRunning(id: UUID) -> Bool {
        sessionTrees[id] != nil && statuses[id] == .running
    }

    /// Close a session's surface tree. All processes in the tree are terminated.
    func closeSession(id: UUID) {
        guard let tree = sessionTrees[id] else { return }

        // Remove from our tracking first, then close surfaces via the controller.
        sessionTrees.removeValue(forKey: id)
        setStatus(.exited, for: id)

        // If this was the active session, switch to another running session.
        if activeSessionId == id {
            switchToNextSession()
        }

        // Tell Ghostty to close each surface in the tree (kills processes).
        guard let controller = terminalController else { return }
        for surface in tree {
            controller.closeSurface(surface, withConfirmation: false)
        }
    }

    /// Clean up runtime state for a session (after removing from the store).
    func clearRuntime(id: UUID) {
        sessionTrees.removeValue(forKey: id)
        statuses.removeValue(forKey: id)
        WorkspaceStore.shared.removeSessionStatus(id: id)
    }

    // MARK: - Private

    /// Discovers the terminal controller through the view hierarchy.
    private var terminalController: BaseTerminalController? {
        containerView?.window?.windowController as? BaseTerminalController
    }

    /// Snapshot the active session's current tree from the controller.
    ///
    /// The controller owns the live tree (including any splits the user created
    /// via Ghostty shortcuts). We must capture it before every switch so that
    /// returning to this session restores the user's split layout.
    private func snapshotActiveTree() {
        guard let currentId = activeSessionId,
              let controller = terminalController,
              sessionTrees[currentId] != nil else { return }
        sessionTrees[currentId] = controller.surfaceTree
    }

    /// Replace the terminal area with a session's full split tree.
    ///
    /// Uses `replaceSurfaceTree` (the canonical safe setter) instead of direct
    /// `surfaceTree` assignment to avoid bypassing undo registration.
    /// We pass `undoAction: nil` because session switching is a sidebar navigation
    /// action, not an undoable edit.
    private func showSession(_ tree: SplitTree<Ghostty.SurfaceView>, focusView: Ghostty.SurfaceView?) {
        guard let controller = terminalController else { return }
        let oldFocused = controller.focusedSurface

        controller.replaceSurfaceTree(
            tree,
            moveFocusTo: focusView,
            moveFocusFrom: oldFocused
        )
    }

    /// Switch to the next available running session, or show nothing.
    private func switchToNextSession() {
        if let (nextId, nextTree) = sessionTrees.first(where: { statuses[$0.key] == .running }) {
            activeSessionId = nextId
            showSession(nextTree, focusView: nextTree.first)
        } else {
            activeSessionId = nil
        }
    }

    /// Close all sessions belonging to a project. Called before the project is
    /// removed from the store, so that running terminals are properly terminated.
    func closeAllSessions(forProject projectId: UUID) {
        let projectSessions = WorkspaceStore.shared.sessions.filter { $0.projectId == projectId }
        for session in projectSessions {
            if sessionTrees[session.id] != nil {
                closeSession(id: session.id)
            }
            clearRuntime(id: session.id)
        }
        lastActiveSessionPerProject.removeValue(forKey: projectId)
    }

    /// Observe project removal notifications so we can close running sessions
    /// before the store deletes the project's session records.
    private func observeProjectRemoval() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(projectWillBeRemoved(_:)),
            name: .workspaceProjectWillBeRemoved,
            object: nil
        )
    }

    @objc private func projectWillBeRemoved(_ notification: Notification) {
        guard let projectId = notification.userInfo?["projectId"] as? UUID else { return }
        closeAllSessions(forProject: projectId)
    }

    /// Observe Ghostty surface close notifications to track session lifecycle.
    private func observeLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(surfaceDidClose(_:)),
            name: Ghostty.Notification.ghosttyCloseSurface,
            object: nil
        )
    }

    @objc private func surfaceDidClose(_ notification: Notification) {
        // Defer processing by one run-loop tick. BaseTerminalController also observes
        // ghosttyCloseSurface and updates the live surfaceTree synchronously, but
        // NotificationCenter delivery order depends on registration order and is not
        // guaranteed. By dispatching async we ensure the controller has already
        // removed the closed surface before we snapshot its tree.
        DispatchQueue.main.async { [weak self] in
            self?.handleSurfaceClose(notification)
        }
    }

    private func handleSurfaceClose(_ notification: Notification) {
        guard let closedSurface = notification.object as? Ghostty.SurfaceView else { return }

        // Find which session owns this surface by scanning all stored trees.
        guard let sessionId = sessionId(for: closedSurface) else { return }

        let processAlive = notification.userInfo?["process_alive"] as? Bool ?? false

        // For the active session, read the live tree from the controller (which
        // BaseTerminalController has already updated to remove the closed surface).
        // For background sessions, remove the surface from our stored tree.
        if sessionId == activeSessionId {
            if let controller = terminalController {
                let liveTree = controller.surfaceTree
                if liveTree.isEmpty {
                    sessionTrees.removeValue(forKey: sessionId)
                    setStatus(processAlive ? .killed : .exited, for: sessionId)
                    switchToNextSession()
                } else {
                    sessionTrees[sessionId] = liveTree
                }
            }
        } else {
            // Background session: remove the closed surface's node from our stored tree.
            if let tree = sessionTrees[sessionId],
               let node = tree.root?.node(view: closedSurface) {
                let updated = tree.removing(node)
                if updated.isEmpty {
                    sessionTrees.removeValue(forKey: sessionId)
                    setStatus(processAlive ? .killed : .exited, for: sessionId)
                } else {
                    sessionTrees[sessionId] = updated
                }
            }
        }
    }

    /// Resolve a bare command name to its absolute path using the user's login shell.
    ///
    /// Ghostty launches commands via `/usr/bin/login ... --noprofile --norc`, so the
    /// user's PATH from shell profiles isn't available. This spawns a login shell to
    /// get the full PATH, then searches for the binary. Returns the original command
    /// if resolution fails or the command is already absolute.
    nonisolated private static func resolveCommand(_ command: String) -> String {
        guard !command.hasPrefix("/") else { return command }

        // Check cache first.
        if let cached = resolvedPaths[command] { return cached }

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // Fast path: check common CLI tool installation directories directly.
        // This avoids spawning a subprocess, which can fail silently in the
        // macOS GUI app context (minimal environment, no TTY).
        let commonPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ]
        for dir in commonPaths {
            let candidate = (dir as NSString).appendingPathComponent(command)
            if fm.isExecutableFile(atPath: candidate) {
                resolvedPaths[command] = candidate
                return candidate
            }
        }

        // Slow path: spawn a login shell to discover the full PATH.
        // Covers binaries in unusual locations not in the common list above.
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: shell)
        task.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return command
        }

        guard task.terminationStatus == 0 else { return command }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let pathString = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !pathString.isEmpty else { return command }

        for dir in pathString.split(separator: ":").map(String.init) {
            let candidate = (dir as NSString).appendingPathComponent(command)
            if fm.isExecutableFile(atPath: candidate) {
                resolvedPaths[command] = candidate
                return candidate
            }
        }

        return command
    }

    /// Find which session owns a given surface by searching all stored trees.
    private func sessionId(for surface: Ghostty.SurfaceView) -> UUID? {
        // Check the active session's live tree first (from the controller).
        if let activeId = activeSessionId,
           let controller = terminalController,
           controller.surfaceTree.contains(where: { $0 === surface }) {
            return activeId
        }
        // Check stored trees for background sessions.
        for (id, tree) in sessionTrees where id != activeSessionId {
            if tree.contains(where: { $0 === surface }) {
                return id
            }
        }
        return nil
    }

    /// Update a session's status locally and in the global store.
    private func setStatus(_ status: SessionStatus, for id: UUID) {
        statuses[id] = status
        WorkspaceStore.shared.updateSessionStatus(id: id, status: status)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Clean up this coordinator's session entries from the global store.
        // SessionCoordinator is always deallocated on the main thread (UI object),
        // so assumeIsolated is safe here.
        MainActor.assumeIsolated {
            for id in statuses.keys {
                WorkspaceStore.shared.removeSessionStatus(id: id)
            }
        }
    }
}
