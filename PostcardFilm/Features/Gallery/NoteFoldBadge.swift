import SwiftUI

/// Bottom-trailing dog-ear fold — soft yellow page corner cue for prints with a back note.
struct NoteFoldBadge: View {
    private let size: CGFloat = 22

    private var softYellow: Color {
        Color(red: 1, green: 236 / 255, blue: 170 / 255)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Soft yellow fold with paper depth.
            Path { path in
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size, y: size))
                path.addLine(to: CGPoint(x: 0, y: size))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [softYellow, AppTheme.paperDeep.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: size, y: 0))
                    path.addLine(to: CGPoint(x: size, y: size))
                    path.addLine(to: CGPoint(x: 0, y: size))
                    path.closeSubpath()
                }
                .stroke(AppTheme.graphite.opacity(0.28), lineWidth: 0.75)
            }

            // Shade along the crease so the fold reads as a turned page.
            Path { path in
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size, y: size))
                path.addLine(to: CGPoint(x: 0, y: size))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.14),
                    ],
                    startPoint: UnitPoint(x: 0.85, y: 0.15),
                    endPoint: .bottomLeading
                )
            )

            Path { path in
                path.move(to: CGPoint(x: size * 0.18, y: size))
                path.addLine(to: CGPoint(x: size, y: size * 0.18))
            }
            .stroke(AppTheme.graphite.opacity(0.22), lineWidth: 0.8)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.32), radius: 2, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
