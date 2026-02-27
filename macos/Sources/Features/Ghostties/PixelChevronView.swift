import SwiftUI

/// Pixel-art chevron matching the ghost character aesthetic.
///
/// Renders an 8×8 chevron (7×5 grid) inside a 16×16 frame using `Path`,
/// following the same pattern as `GhostCharacterView`. Points right when
/// collapsed, down when expanded. Animation respects reduced motion.
struct PixelChevronView: View {
    var color: Color = Color(.tertiaryLabelColor)
    var isExpanded: Bool = false

    /// 7×5 pixel grid defining the chevron shape (points downward).
    /// Rotated -90° (270°) to point right when collapsed.
    private static let grid: [(x: Int, y: Int, w: Int, h: Int)] = [
        (0, 0, 1, 1), (6, 0, 1, 1),
        (0, 1, 2, 1), (5, 1, 2, 1),
        (1, 2, 2, 1), (4, 2, 2, 1),
        (2, 3, 3, 1),
        (3, 4, 1, 1),
    ]

    var body: some View {
        GeometryReader { geo in
            chevronPath(in: CGRect(origin: .zero, size: geo.size))
                .fill(color)
        }
        .frame(width: 8, height: 8)
        .frame(width: 16, height: 16)
        .rotationEffect(.degrees(isExpanded ? 0 : -90))
        .animation(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? nil
                : .easeInOut(duration: 0.2),
            value: isExpanded
        )
        .accessibilityHidden(true)
    }

    private func chevronPath(in rect: CGRect) -> Path {
        let cellW = rect.width / 7
        let cellH = rect.height / 5

        var path = Path()
        for pixel in Self.grid {
            let x = rect.minX + CGFloat(pixel.x) * cellW
            let y = rect.minY + CGFloat(pixel.y) * cellH
            path.addRect(CGRect(x: x, y: y, width: CGFloat(pixel.w) * cellW, height: CGFloat(pixel.h) * cellH))
        }
        return path
    }
}
