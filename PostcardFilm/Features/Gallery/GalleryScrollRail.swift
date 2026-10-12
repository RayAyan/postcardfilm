import SwiftUI

/// Modern trailing scrubber — tracks scroll, expands smoothly on press.
struct GalleryScrollRail: View {
    let itemCount: Int
    let progress: CGFloat
    let isNeeded: Bool
    var onScrubActive: (Bool) -> Void = { _ in }
    var onScrub: (CGFloat) -> Void

    @State private var isDragging = false

    private let restingWidth: CGFloat = 6
    private let activeWidth: CGFloat = 14
    private let hitWidth: CGFloat = 40
    private let minThumbHeight: CGFloat = 44
    private let activeThumbScale: CGFloat = 1.08

    var body: some View {
        GeometryReader { geo in
            let trackInset: CGFloat = 2
            let trackHeight = max(geo.size.height - trackInset * 2, 1)
            let baseThumb = thumbHeight(for: trackHeight)
            let thumbHeight = isDragging ? baseThumb * activeThumbScale : baseThumb
            let travel = max(trackHeight - thumbHeight, 0)
            let clamped = min(max(progress, 0), 1)
            let thumbY = trackInset + travel * clamped
            let width = isDragging ? activeWidth : restingWidth

            ZStack(alignment: .topTrailing) {
                // Soft track
                Capsule(style: .continuous)
                    .fill(AppTheme.surfaceRaised.opacity(isDragging ? 0.95 : 0.7))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 1)
                    )
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, trackInset)

                // Thumb
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.paper.opacity(isDragging ? 1 : 0.88),
                                AppTheme.paperDeep.opacity(isDragging ? 0.95 : 0.75),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.graphite.opacity(0.22), lineWidth: 0.75)
                    )
                    .shadow(color: .black.opacity(isDragging ? 0.35 : 0.18), radius: isDragging ? 4 : 2, y: 1)
                    .frame(width: width, height: thumbHeight)
                    .offset(y: thumbY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 3)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.16), value: isDragging)
            // Spring thumb follow only while finger-scrolling the grid — not during rail scrub.
            .animation(
                isDragging ? nil : .interactiveSpring(response: 0.22, dampingFraction: 0.86),
                value: clamped
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onScrubActive(true)
                        }
                        let y = value.location.y - trackInset - thumbHeight / 2
                        let fraction = travel > 0 ? y / travel : 0
                        onScrub(min(max(fraction, 0), 1))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onScrubActive(false)
                    }
            )
            .accessibilityLabel("gallery scroll")
            .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = itemCount > 1 ? 1 / CGFloat(itemCount - 1) : 0.1
                switch direction {
                case .increment:
                    onScrub(min(clamped + step, 1))
                case .decrement:
                    onScrub(max(clamped - step, 0))
                @unknown default:
                    break
                }
            }
        }
        .frame(width: hitWidth)
        .opacity(isNeeded ? 1 : 0)
        .allowsHitTesting(isNeeded)
        .accessibilityHidden(!isNeeded)
    }

    private func thumbHeight(for trackHeight: CGFloat) -> CGFloat {
        let ratio = itemCount > 0 ? min(1, 10 / CGFloat(max(itemCount, 1))) : 1
        return max(minThumbHeight, trackHeight * max(ratio, 0.14))
    }
}
