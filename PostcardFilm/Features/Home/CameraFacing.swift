import AVFoundation

/// Pure helpers for camera facing / selfie mirroring. Kept free of AVCaptureSession
/// so XCTest can cover toggle and mirror rules without a live camera graph.
enum CameraFacing {
    /// Opposite facing position (back ↔ front).
    static func toggled(_ position: AVCaptureDevice.Position) -> AVCaptureDevice.Position {
        position == .back ? .front : .back
    }

    /// Preview and capture should be mirrored only for the front (selfie) camera.
    static func shouldMirrorPreview(for position: AVCaptureDevice.Position) -> Bool {
        position == .front
    }
}
