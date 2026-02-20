import Foundation

/// A workspace project representing a directory the user has pinned.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var rootPath: String
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        isPinned: Bool = true
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.isPinned = isPinned
    }
}
