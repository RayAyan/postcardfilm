import SwiftUI

/// Cream milk chemistry reveal over a finished Polaroid print.
struct DevelopingOverlay: View {
    var reduceMotion: Bool
    var duration: TimeInterval = 5
    var onFinished: (() -> Void)?

    @State private var milk = 1.0
    /// Starts at the Polaroid's leading edge (not off-card left).
    @State private var sweep: CGFloat = 0
    @State private var labelOpacity = 0.0
    @State private var labelTracking: CGFloat = 6
    @State private var pulse = false
    @State private var didFinish = false

    var body: some View {
        ZStack {
            // Opaque milk — print sits underneath and slowly comes up
            AppTheme.paper
                .opacity(milk)

            GeometryReader { geo in
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.5),
                        AppTheme.paper.opacity(0.3),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.5)
                .offset(x: sweep * geo.size.width)
                .blendMode(.plusLighter)
                .opacity(reduceMotion ? 0 : milk * 0.9)
            }
            .clipped()

            VStack(spacing: 10) {
                Text(Brand.developing)
                    .font(AppType.display(20, weight: .medium))
                    .appChromeText()
                    .tracking(labelTracking)
                    .foregroundStyle(AppTheme.graphite)
                    .opacity(labelOpacity * milk)

                Capsule()
                    .fill(AppTheme.graphite.opacity(0.2))
                    .frame(width: 72, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.graphite.opacity(0.65))
                            .frame(width: pulse ? 72 : 12, height: 3)
                    }
                    .opacity(labelOpacity * milk)
            }
            .accessibilityLabel("Developing")
        }
        .clipped()
        .allowsHitTesting(true)
        .onAppear { run() }
    }

    private func run() {
        if reduceMotion {
            milk = 0
            finishOnce()
            return
        }

        Haptics.developTick()

        withAnimation(.easeOut(duration: 0.4)) {
            labelOpacity = 1
            labelTracking = 1.2
        }

        let clearDuration = max(duration - 0.2, 1)
        withAnimation(.easeInOut(duration: clearDuration)) {
            milk = 0
            sweep = 1.2
        }

        withAnimation(.easeInOut(duration: clearDuration)) {
            pulse = true
        }

        let tickTimes = [duration * 0.3, duration * 0.6, duration * 0.9]
        for delay in tickTimes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Haptics.developTick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            finishOnce()
        }
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        Haptics.success()
        onFinished?()
    }
}
