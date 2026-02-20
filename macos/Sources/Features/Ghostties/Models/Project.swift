import Foundation

/// A workspace project representing a directory the user has pinned or recently opened.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var rootPath: String
    var isPinned: Bool
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        isPinned: Bool = false,
        lastOpenedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.isPinned = isPinned
        self.lastOpenedAt = lastOpenedAt
    }

    /// The first letter of the project name, used as a fallback icon in the rail.
    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
