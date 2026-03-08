import SwiftUI

/// Whether the ghost is rendered filled or as an outline stroke.
enum GhostStyle {
    case filled
    case outline
}

/// Renders a `GhostCharacter` pixel grid as a crisp vector shape.
///
/// Uses `GeometryReader` to fill whatever frame the parent provides, so the
/// ghost scales cleanly at any size. At 20pt render size each "pixel" is ~1.67pt,
/// which snaps to full pixels on @2x Retina.
struct GhostCharacterView: View {
    let character: GhostCharacter
    var color: Color = .primary
    var style: GhostStyle = .filled

    var body: some View {
        GeometryReader { geo in
            let path = character.drawPath(in: CGRect(origin: .zero, size: geo.size))
            switch style {
            case .filled:
                path.fill(color)
            case .outline:
                path.stroke(color, lineWidth: 1)
            }
        }
        .accessibilityLabel("\(character.rawValue) ghost")
    }
}
