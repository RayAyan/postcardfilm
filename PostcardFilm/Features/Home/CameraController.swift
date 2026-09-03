@preconcurrency import AVFoundation
import UIKit

@MainActor
final class CameraController: NSObject, ObservableObject {
    enum FlashMode: String, CaseIterable {
        case off
        case on
        case auto

        var avMode: AVCaptureDevice.FlashMode {
            switch self {
            case .off: return .off
            case .on: return .on
            case .auto: return .auto
            }
        }

        var symbolName: String {
            switch self {
            case .off: return "bolt.slash"
            case .on, .auto: return "bolt.fill"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .off: return "Flash off"
            case .on: return "Flash on"
            case .auto: return "Flash auto"
            }
        }

        func next() -> FlashMode {
            switch self {
            case .off: return .on
            case .on: return .auto
            case .auto: return .off
            }
        }
    }

    @Published var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published var flashMode: FlashMode = .off
    @Published var isSessionRunning = false
    @Published var lastError: String?
    @Published private(set) var isConfigured = false
    /// True while an input swap is in flight — flip control should stay disabled.
    @Published private(set) var isSwitchingCamera = false

    // Session graph is mutated on `sessionQueue`; mark unsafe for MainActor isolation.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<UIImage, Error>?
    private let sessionQueue = DispatchQueue(label: "com.postcardpolaroid.camera")
    private var interruptionObserver: NSObjectProtocol?

    /// True when photo capture can safely be called (live video connection).
    var canCapturePhoto: Bool {
        session.isRunning
            && photoOutput.connection(with: .video)?.isEnabled == true
            && photoOutput.connection(with: .video)?.isActive == true
    }

    func requestPermissionIfNeeded() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission = granted ? .authorized : .denied
        } else {
            permission = status
        }
        if permission == .authorized {
            await configureAndStart()
        }
    }

    func configureAndStart(position: AVCaptureDevice.Position? = nil) async {
        let target = position ?? self.position
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.configureSessionLocked(position: target)
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                let running = self.session.isRunning
                Task { @MainActor in
                    // Publish facing only after the new input is live so preview
                    // never mirrors/unmirrors the *previous* camera mid-switch.
                    self.position = target
                    self.isConfigured = true
                    self.isSessionRunning = running
                    self.observeInterruptionEnded()
                    continuation.resume()
                }
            }
        }
    }

    nonisolated private func configureSessionLocked(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        session.inputs.forEach { session.removeInput($0) }
        // Keep photoOutput instance; only remove other outputs.
        session.outputs.forEach { output in
            if output !== photoOutput {
                session.removeOutput(output)
            }
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            Task { @MainActor in self.lastError = "No camera available" }
            return
        }
        session.addInput(input)

        if session.outputs.contains(photoOutput) == false, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in self.isSessionRunning = self.session.isRunning }
        }
    }

    /// Restart after background / session interruption without rebuilding the graph when possible.
    func resume() async {
        guard permission == .authorized else { return }
        if isConfigured {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                sessionQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    let running = self.session.isRunning
                    Task { @MainActor in
                        self.isSessionRunning = running
                        continuation.resume()
                    }
                }
            }
        } else {
            await configureAndStart()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in self.isSessionRunning = false }
        }
    }

    func flipCamera() {
        guard !isSwitchingCamera else { return }
        let next = CameraFacing.toggled(position)
        isSwitchingCamera = true
        Task {
            await configureAndStart(position: next)
            isSwitchingCamera = false
        }
    }

    func cycleFlash() {
        flashMode = flashMode.next()
    }

    private func observeInterruptionEnded() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.resume()
            }
        }
    }

    func takePhoto() async throws -> UIImage {
        // Wait briefly for the session to become capture-ready (config is async).
        for _ in 0 ..< 20 {
            if canCapturePhoto { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        guard canCapturePhoto else {
            #if targetEnvironment(simulator)
            // Simulator camera graph often never activates — still exercise Developing pipeline.
            return Self.simulatorPlaceholderImage()
            #else
            throw CameraError.notReady
            #endif
        }

        let flash = flashMode
        let useBack = position == .back

        return try await withCheckedThrowingContinuation { continuation in
            // Avoid double-resume if a previous capture hung.
            if let pending = self.captureContinuation {
                pending.resume(throwing: CameraError.busy)
                self.captureContinuation = nil
            }
            self.captureContinuation = continuation

            let settings = AVCapturePhotoSettings()
            if useBack,
               let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               device.hasFlash
            {
                settings.flashMode = flash.avMode
            }

            self.sessionQueue.async { [weak self] in
                guard let self else { return }
                // Re-check on the session queue immediately before calling into AVFoundation.
                let connection = self.photoOutput.connection(with: .video)
                guard self.session.isRunning,
                      connection?.isEnabled == true,
                      connection?.isActive == true
                else {
                    Task { @MainActor in
                        self.finishCapture(throwing: CameraError.notReady)
                    }
                    return
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func finishCapture(throwing error: Error) {
        captureContinuation?.resume(throwing: error)
        captureContinuation = nil
    }

    private func finishCapture(returning image: UIImage) {
        captureContinuation?.resume(returning: image)
        captureContinuation = nil
    }

    #if targetEnvironment(simulator)
    /// Deterministic stand-in so Developing / grade / gallery can be tested without a camera graph.
    nonisolated static func simulatorPlaceholderImage() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0.75, green: 0.55, blue: 0.45, alpha: 1).cgColor,
                UIColor(red: 0.35, green: 0.45, blue: 0.55, alpha: 1).cgColor,
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            let label = "Simulator capture" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            ]
            let textSize = label.size(withAttributes: attrs)
            label.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attrs
            )
        }
    }
    #endif
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                finishCapture(throwing: error)
                return
            }
            guard
                let data = photo.fileDataRepresentation(),
                let image = UIImage(data: data)
            else {
                finishCapture(throwing: CameraError.decodeFailed)
                return
            }
            // Front camera: match mirrored preview (WYSIWYG selfie).
            let output = CameraFacing.shouldMirrorPreview(for: self.position)
                ? image.flippedHorizontally()
                : image
            finishCapture(returning: output)
        }
    }
}

enum CameraError: LocalizedError {
    case notReady
    case busy
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Camera isn’t ready yet. Try again in a moment."
        case .busy:
            return "Another capture is already in progress."
        case .decodeFailed:
            return "Could not read the photo."
        }
    }
}

