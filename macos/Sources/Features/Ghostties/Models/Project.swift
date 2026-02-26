import Foundation

/// A workspace project representing a directory the user has pinned.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var rootPath: String
    var isPinned: Bool

    /// The pixel-art ghost character displayed in the icon rail.
    /// Nil means the project predates the ghost system (shows initial fallback).
    var ghostCharacter: GhostCharacter?

    /// The default template to use when creating sessions with a single click.
    /// Nil means always show the template picker.
    var defaultTemplateId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        isPinned: Bool = true,
        ghostCharacter: GhostCharacter? = nil,
        defaultTemplateId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.isPinned = isPinned
        self.ghostCharacter = ghostCharacter
        self.defaultTemplateId = defaultTemplateId
    }

    // Custom decoder so existing workspace.json files (without ghost/template fields)
    // load without error. New fields default to nil when missing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.rootPath = try container.decode(String.self, forKey: .rootPath)
        self.isPinned = try container.decode(Bool.self, forKey: .isPinned)
        self.ghostCharacter = try container.decodeIfPresent(GhostCharacter.self, forKey: .ghostCharacter)
        self.defaultTemplateId = try container.decodeIfPresent(UUID.self, forKey: .defaultTemplateId)
    }
}
