import UIKit

/// Raises screen brightness for selfie screen-flash capture, then restores it exactly once.
@MainActor
enum ScreenFlash {
    private static var savedBrightness: CGFloat?

    /// Force brightness to 1.0. Idempotent if already active — keeps the original saved value.
    static func begin() {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
        }
        UIScreen.main.brightness = 1.0
    }

    /// Restore the brightness from the matching `begin()`. Safe to call when not active.
    static func end() {
        guard let previous = savedBrightness else { return }
        savedBrightness = nil
        UIScreen.main.brightness = previous
    }
}
