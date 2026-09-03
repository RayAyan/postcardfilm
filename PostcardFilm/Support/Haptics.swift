import CoreHaptics
import UIKit

/// Capture feel: punchy shutter → quiet flash/pipeline → rising develop pulses → big reveal.
enum Haptics {
    private static var engine: CHHapticEngine?
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()

    /// Warm generators / engine so the first tap feels immediate.
    static func prepare() {
        heavy.prepare()
        rigid.prepare()
        medium.prepare()
        soft.prepare()
        notify.prepare()
        startEngineIfNeeded()
    }

    /// Punchy camera click — sharp hit + brief body thud.
    static func shutter() {
        prepare()
        if playCoreShutter() { return }

        rigid.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            heavy.impactOccurred(intensity: 0.75)
        }
    }

    /// Single chemistry tick at a given intensity (0…1).
    static func developTick(intensity: Double = 0.65) {
        prepare()
        let clamped = Float(min(max(intensity, 0.2), 1.0))
        if playCoreTransient(intensity: clamped, sharpness: 0.35 + clamped * 0.45) { return }

        if clamped >= 0.75 {
            heavy.impactOccurred(intensity: CGFloat(clamped))
        } else if clamped >= 0.5 {
            medium.impactOccurred(intensity: CGFloat(clamped))
        } else {
            soft.impactOccurred(intensity: CGFloat(max(clamped, 0.45)))
        }
    }

    /// Rising surprise pulse — `progress` 0…1 maps to stronger, sharper hits.
    static func developPulse(at progress: Double) {
        let t = min(max(progress, 0), 1)
        let intensity = 0.45 + t * 0.50
        developTick(intensity: intensity)
    }

    /// Big double-thump when the print reveals.
    static func developDone() {
        prepare()
        if playCoreDevelopDone() { return }

        heavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            rigid.impactOccurred(intensity: 0.85)
        }
    }

    /// Photos save / other true successes (notification family OK here).
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
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0.01,
                duration: 0.06
            )

            let pattern = try CHHapticPattern(events: [click, thud], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private static func playCoreTransient(intensity: Float, sharpness: Float) -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine
        else { return false }

        do {
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private static func playCoreDevelopDone() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine
        else { return false }

        do {
            try engine.start()

            let hit = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85),
                ],
                relativeTime: 0
            )
            let swell = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0.02,
                duration: 0.1
            )
            let settle = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
                ],
                relativeTime: 0.12
            )

            let pattern = try CHHapticPattern(events: [hit, swell, settle], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }
}
