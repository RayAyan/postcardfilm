import AVFoundation

/// Pure flash decision for capture. No AVCaptureSession — XCTest can cover it.
enum FlashPlan {
    /// Flash off — no hardware fire, no screen light.
    case none
    /// Back camera: set `AVCapturePhotoSettings.flashMode = .on`.
    case hardware
    /// Front camera: white overlay + full screen brightness during exposure.
    case screen

    static func resolve(isFlashOn: Bool, position: AVCaptureDevice.Position) -> FlashPlan {
        guard isFlashOn else { return .none }
        return position == .front ? .screen : .hardware
    }
}

/// Ordered capture attempts for resilient photo taking.
/// Attempt 1–2 keep the desired flash; attempt 3 forces flash off as a last resort.
enum CaptureAttemptLadder {
    enum FlashPreference: Equatable {
        case desired
        case forceOff
    }

    static let maxAttempts = 3

    /// Which flash preference to use for a 1-based attempt index.
    static func preference(forAttempt attempt: Int) -> FlashPreference {
        attempt >= maxAttempts ? .forceOff : .desired
    }

    /// Maps preference + plan to the AVCaptureDevice.FlashMode used for hardware.
    static func hardwareFlashMode(
        preference: FlashPreference,
        plan: FlashPlan
    ) -> AVCaptureDevice.FlashMode {
        switch preference {
        case .forceOff:
            return .off
        case .desired:
            return plan == .hardware ? .on : .off
        }
    }
}
