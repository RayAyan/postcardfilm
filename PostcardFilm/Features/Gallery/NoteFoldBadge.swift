import SwiftUI

/// Bottom-trailing dog-ear fold — the cream corner turned in to show a flat burnt-orange
/// underside, as the cue for prints with a back note.
struct NoteFoldBadge: View {
    private let size: CGFloat = 24

    /// Colour of the folded-back corner flap (#C65D2E).
    static let burntOrange = Color(red: 198 / 255, green: 93 / 255, blue: 46 / 255)

    var body: some View {
        ZStack {
            // Corner past the crease is gone — paint it in the gallery backdrop so the card reads as cut.
            Path { path in
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size, y: size))
                path.addLine(to: CGPoint(x: 0, y: size))
                path.closeSubpath()
            }
            .fill(AppTheme.surface)

            // Flap folded inward: right angle points toward the photo, hypotenuse on the crease.
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size))
                path.closeSubpath()
            }
            .fill(Self.burntOrange)
            .shadow(color: .black.opacity(0.22), radius: 1.5, x: -0.5, y: -0.5)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
