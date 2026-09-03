import SwiftUI

/// Cream milk chemistry reveal — Polaroid fade, not a wipe.
struct DevelopingOverlay: View {
    var reduceMotion: Bool
    /// How long “developing…” stays up before the label fades out.
    var labelHold: TimeInterval = 1.5
    /// How long milk takes to clear after the label is gone (print fades in).
    var fadeDuration: TimeInterval = 3.0
    /// Hold opaque milk until the print exists.
    var printReady: Bool = true
    var onFinished: (() -> Void)?

    @State private var milk = 1.0
    @State private var labelOpacity = 0.0
    @State private var labelTracking: CGFloat = 6
    @State private var didFinish = false
    @State private var labelPhaseDone = false
    @State private var fadeScheduled = false
    @State private var hapticWorkItems: [DispatchWorkItem] = []

    /// Full chemistry window used for countdown haptics (label + fade).
    private var chemistryWindow: TimeInterval {
        labelHold + fadeDuration
    }

    var body: some View {
        ZStack {
            AppTheme.paper
                .opacity(milk)

            Text(Brand.developing)
                .font(AppType.display(20, weight: .medium))
                .appChromeText()
                .tracking(labelTracking)
                .foregroundStyle(AppTheme.graphite)
                .opacity(labelOpacity)
                .accessibilityLabel("Developing")
        }
        .clipped()
        .allowsHitTesting(true)
        .onAppear { run() }
        .onChange(of: printReady) { _, ready in
            if ready { scheduleFadeIfNeeded() }
        }
        .onDisappear { cancelPendingWork() }
    }

    private func run() {
        if reduceMotion {
            if printReady {
                milk = 0
                finishOnce()
            }
            return
        }

        scheduleDevelopHaptics()

        withAnimation(.easeOut(duration: 0.35)) {
            labelOpacity = 1
            labelTracking = 1.2
        }

        let labelItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.35)) {
                labelOpacity = 0
            }
            labelPhaseDone = true
            scheduleFadeIfNeeded()
        }
        hapticWorkItems.append(labelItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + labelHold, execute: labelItem)

        scheduleFadeIfNeeded()
    }

    /// Start the 3s milk fade only after label hold AND print ready.
    private func scheduleFadeIfNeeded() {
        guard !didFinish, !fadeScheduled else { return }

        if reduceMotion {
            guard printReady else { return }
            milk = 0
            finishOnce()
            return
        }

        guard printReady, labelPhaseDone else { return }
        fadeScheduled = true

        withAnimation(.easeInOut(duration: fadeDuration)) {
            milk = 0
        }

        let doneItem = DispatchWorkItem {
            finishOnce()
        }
        hapticWorkItems.append(doneItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration, execute: doneItem)
    }

    /// Rising chemistry pulses across the full label+fade window.
    private func scheduleDevelopHaptics() {
        let fractions: [Double] = [0, 0.2, 0.4, 0.6, 0.8]
        for fraction in fractions {
            let item = DispatchWorkItem {
                Haptics.developPulse(at: fraction)
            }
            hapticWorkItems.append(item)
            if fraction == 0 {
                item.perform()
            } else {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + chemistryWindow * fraction,
                    execute: item
                )
            }
        }
    }

    private func cancelPendingWork() {
        hapticWorkItems.forEach { $0.cancel() }
        hapticWorkItems.removeAll()
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        cancelPendingWork()
        Haptics.developDone()
        onFinished?()
    }
}
