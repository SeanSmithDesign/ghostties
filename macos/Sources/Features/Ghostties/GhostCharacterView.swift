import SwiftUI

/// Renders a `GhostCharacter` pixel grid as a crisp vector shape.
///
/// Uses `GeometryReader` to fill whatever frame the parent provides, so the
/// ghost scales cleanly at any size. At 20pt render size each "pixel" is ~1.67pt,
/// which snaps to full pixels on @2x Retina.
struct GhostCharacterView: View {
    let character: GhostCharacter
    var color: Color = .primary

    var body: some View {
        GeometryReader { geo in
            character.drawPath(in: CGRect(origin: .zero, size: geo.size))
                .fill(color)
        }
        .accessibilityLabel("\(character.rawValue) ghost")
    }
}
