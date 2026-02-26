import SwiftUI

/// One of 12 pixel-art ghost characters assignable to a project.
///
/// Each case owns a 12×12 boolean grid that defines its silhouette.
/// `drawPath(in:)` renders the grid as filled rectangles within a SwiftUI
/// `Path`, producing crisp vector art at any size. At a 20pt render size
/// each "pixel" is ~1.67pt — sharp at @2x Retina.
enum GhostCharacter: String, CaseIterable, Codable {
    case blinky
    case pinky
    case inky
    case clyde
    case specter
    case wisp
    case phantom
    case shade
    case haunt
    case wraith
    case banshee
    case polter

    /// 12×12 boolean grid defining the ghost's silhouette.
    /// `true` = filled pixel, `false` = transparent.
    var pixelGrid: [[Bool]] {
        switch self {
        case .blinky:
            return [
                [false, false, false, true,  true,  true,  true,  true,  true,  false, false, false],
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [false, true,  true,  false, false, true,  true,  false, false, true,  true,  false],
                [false, true,  true,  false, false, true,  true,  false, false, true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, true,  true,  false, false, true,  true,  false, true,  true],
                [true,  false, false, false, true,  false, false, true,  false, false, false, true],
            ]
        case .pinky:
            return [
                [false, false, false, false, true,  true,  true,  true,  false, false, false, false],
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [false, true,  false, false, true,  true,  true,  true,  false, false, true,  false],
                [false, true,  false, false, true,  true,  true,  true,  false, false, true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  false, false, false, false, false, false, false, false, false, false, true],
            ]
        case .inky:
            return [
                [false, false, false, true,  true,  true,  true,  true,  true,  false, false, false],
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [false, true,  true,  true,  false, false, false, false, true,  true,  true,  false],
                [false, true,  true,  true,  false, false, false, false, true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  false, true,  true,  false, true,  true,  false, true,  true,  false, true],
                [true,  false, false, true,  false, false, false, false, true,  false, false, true],
            ]
        case .clyde:
            return [
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, true,  true,  true,  true,  false, true,  true,  true],
                [true,  false, false, false, false, true,  true,  false, false, false, false, true],
            ]
        case .specter:
            return [
                [false, false, false, true,  true,  true,  true,  true,  true,  false, false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  false, false, false, true,  true,  true,  true,  false, false, false, true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  false, false, false, false, true,  true,  false, false, false, false, true],
            ]
        case .wisp:
            return [
                [false, false, false, false, true,  true,  true,  true,  false, false, false, false],
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [false, false, true,  true,  false, true,  true,  false, true,  true,  false, false],
                [false, false, false, true,  false, false, false, false, true,  false, false, false],
            ]
        case .phantom:
            return [
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, false, true,  false, false, true,  true,  true,  true],
                [true,  true,  true,  false, false, true,  false, false, true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  false, false, false, false, true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  false, true,  true,  true,  false, false, true,  true,  true,  false, true],
                [true,  false, false, true,  false, false, false, false, true,  false, false, true],
            ]
        case .shade:
            return [
                [false, false, false, true,  true,  true,  true,  true,  true,  false, false, false],
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  true,  true,  true,  true,  false, false, true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, true,  true,  true,  true,  true,  true,  false, true,  true],
                [true,  false, false, false, true,  false, false, true,  false, false, false, true],
            ]
        case .haunt:
            return [
                [false, false, false, true,  true,  true,  true,  true,  true,  false, false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  false, false, true,  true,  true,  true,  true,  true,  false, false, true],
                [true,  false, false, true,  true,  true,  true,  true,  true,  false, false, true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  false, false, false, false, false, false, false, false, false, false, true],
            ]
        case .wraith:
            return [
                [false, false, false, false, true,  true,  true,  true,  false, false, false, false],
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [false, false, true,  true,  true,  false, false, true,  true,  true,  false, false],
                [false, false, false, true,  false, false, false, false, true,  false, false, false],
            ]
        case .banshee:
            return [
                [false, false, true,  true,  true,  true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  false, false, false, true,  true,  true,  true,  false, false, false, true],
                [true,  false, false, false, true,  true,  true,  true,  false, false, false, true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, false, false, false, false, false, true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  false, false, true,  true,  true,  true,  false, false, true,  true],
                [true,  false, false, false, false, true,  true,  false, false, false, false, true],
            ]
        case .polter:
            return [
                [false, false, false, true,  true,  true,  true,  true,  true,  false, false, false],
                [false, true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  false],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  true,  true,  false, false, true,  true,  false, false, true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true],
                [true,  true,  true,  true,  false, false, false, false, true,  true,  true,  true],
                [true,  false, false, false, false, false, false, false, false, false, false, true],
            ]
        }
    }

    /// Render the pixel grid as a SwiftUI `Path` within the given rectangle.
    ///
    /// Each `true` cell becomes a filled rectangle. The grid scales to fill
    /// the rect, so the path renders crisply at any size.
    func drawPath(in rect: CGRect) -> Path {
        let grid = pixelGrid
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0 else { return Path() }

        let cellW = rect.width / CGFloat(cols)
        let cellH = rect.height / CGFloat(rows)

        var path = Path()
        for row in 0..<rows {
            for col in 0..<cols {
                guard grid[row][col] else { continue }
                let x = rect.minX + CGFloat(col) * cellW
                let y = rect.minY + CGFloat(row) * cellH
                path.addRect(CGRect(x: x, y: y, width: cellW, height: cellH))
            }
        }
        return path
    }

    /// Pick a random ghost that isn't already in use, or any random ghost if all 12 are taken.
    static func randomUnused(excluding used: Set<GhostCharacter>) -> GhostCharacter {
        let available = allCases.filter { !used.contains($0) }
        return (available.isEmpty ? allCases : available).randomElement()!
    }
}
