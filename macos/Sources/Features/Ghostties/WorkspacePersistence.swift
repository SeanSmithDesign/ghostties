import Foundation
import OSLog

/// Reads and writes workspace state (projects) to a JSON file
/// at ~/Library/Application Support/Ghostties/workspace.json.
struct WorkspacePersistence {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.seansmithdesign.ghostties",
        category: "WorkspacePersistence"
    )

    /// The directory where workspace data is stored.
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ghostties", isDirectory: true)
    }

    private static var fileURL: URL {
        directory.appendingPathComponent("workspace.json")
    }

    // MARK: - Persistence Model

    /// Top-level container for everything we persist.
    struct State: Codable {
        var projects: [Project]
    }

    // MARK: - Read / Write

    static func load() -> State {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return State(projects: [])
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(State.self, from: data)
        } catch {
            logger.error("Failed to load workspace state: \(error.localizedDescription)")
            return State(projects: [])
        }
    }

    static func save(_ state: State) {
        let url = fileURL
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save workspace state: \(error.localizedDescription)")
        }
    }
}
