import CoreHaptics
import UIKit

enum Haptics {
    private static var engine: CHHapticEngine?
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()

    /// Warm generators / engine so the first tap feels immediate.
    static func prepare() {
        heavy.prepare()
        rigid.prepare()
        soft.prepare()
        notify.prepare()
        startEngineIfNeeded()
    }

    /// Hard camera click — Core Haptics when available, heavy cascade otherwise.
    static func shutter() {
        prepare()
        if playCoreShutter() { return }

        heavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) {
            rigid.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) {
            heavy.impactOccurred(intensity: 0.75)
        }
    }

    /// Soft tick while chemistry runs.
    static func developTick() {
        soft.prepare()
        soft.impactOccurred(intensity: 0.45)
    }

    static func success() {
        notify.prepare()
        notify.notificationOccurred(.success)
    }

    static func lightTap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.7)
    }

    // MARK: - Core Haptics

    private static func startEngineIfNeeded() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            do {
                let eng = try CHHapticEngine()
                eng.resetHandler = {
                    try? eng.start()
                }
                eng.stoppedHandler = { _ in
                    try? eng.start()
                }
                engine = eng
            } catch {
                engine = nil
                return
            }
        }
        try? engine?.start()
    }

    @discardableResult
    private static func playCoreShutter() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine
        else { return false }

        do {
            try engine.start()

            // Sharp mechanical click + short body thud (camera-like).
            let click = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                ],
                relativeTime: 0
            )
            let thud = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                ],
                relativeTime: 0.015,
                duration: 0.09
            )
            let settle = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ],
                relativeTime: 0.11
            )

            let pattern = try CHHapticPattern(events: [click, thud, settle], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }
}
