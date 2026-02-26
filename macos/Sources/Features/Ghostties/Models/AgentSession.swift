import Foundation

/// Persistent metadata for a terminal session.
///
/// This is the Codable record stored in workspace.json. Runtime state (the actual
/// SurfaceView reference, live status) lives in SessionCoordinator and is NOT persisted.
///
/// On app restart, previously active sessions appear as "Exited" with a relaunch option.
struct AgentSession: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var templateId: UUID
    var projectId: UUID

    /// Explicit ordering within a project. Nil means this session predates
    /// drag-and-drop reorder and will be sorted alphabetically.
    var sortOrder: Int?

    init(
        id: UUID = UUID(),
        name: String,
        templateId: UUID,
        projectId: UUID,
        sortOrder: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.templateId = templateId
        self.projectId = projectId
        self.sortOrder = sortOrder
    }

    // Custom decoder so existing workspace.json files (without sortOrder)
    // load without error.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.templateId = try container.decode(UUID.self, forKey: .templateId)
        self.projectId = try container.decode(UUID.self, forKey: .projectId)
        self.sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
    }
}

// MARK: - Runtime State

/// Live status of a running session. Not persisted.
enum SessionStatus {
    /// Process is alive and running.
    case running
    /// Process exited naturally (process_alive was false when surface closed).
    case exited
    /// Surface was closed while the process was still running (force-killed by user).
    case killed
}
