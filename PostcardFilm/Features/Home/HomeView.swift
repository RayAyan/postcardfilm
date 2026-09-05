import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PolaroidStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraController()

    @State private var path = NavigationPath()
    @State private var capturing = false
    @State private var shutterFlash = false
    /// Opaque white fill for selfie screen flash (stays up through exposure).
    @State private var screenFlash = false
    @State private var shutterPressed = false
    @State private var captureError: String?
    @State private var showCaptureAlert = false

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// False when the debug screenshot harness stands in for the camera.
    private var usesCamera: Bool {
        #if DEBUG
        return !ScreenshotHarness.isActive
        #else
        return true
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.surface.ignoresSafeArea()
                content
                if shutterFlash || screenFlash {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .navigationDestination(for: PrintRoute.self) { route in
                ProcessView(id: route.id, openedFromCapture: route.openedFromCapture)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .gallery:
                    GalleryView(path: $path)
                case .settings:
                    SettingsView()
                }
            }
            .alert("capture failed", isPresented: $showCaptureAlert) {
                Button("ok", role: .cancel) {}
            } message: {
                Text(captureError ?? "could not take the photo. try again.")
            }
            .task {
                if usesCamera {
                    await camera.requestPermissionIfNeeded()
                }
                store.reload()
                if ProcessInfo.processInfo.arguments.contains("-AUTO_CAPTURE") {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await capture()
                }
            }
            .onDisappear { camera.stop() }
            .onAppear {
                Haptics.prepare()
                if usesCamera, camera.permission == .authorized {
                    Task { await camera.configureAndStart() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard usesCamera, phase == .active, camera.permission == .authorized else { return }
                Task { await camera.resume() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if usesCamera, camera.permission == .denied || camera.permission == .restricted {
            deniedView
        } else {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 16)

                viewfinder
                    .padding(.horizontal, 24)

                Text(Brand.homeTagline)
                    .font(AppType.caption(13))
                    .appChromeText()
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppTheme.taglineGap)
                    .padding(.horizontal, 24)

                Spacer(minLength: 20)

                controls
                    .padding(.bottom, 28)
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                path.append(HomeRoute.gallery)
            } label: {
                VStack(spacing: 4) {
                    Group {
                        if let first = store.items.first,
                           let uiImage = UIImage(contentsOfFile: store.polaroidURL(for: first.id).path)
                        {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.accentFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(AppTheme.hairline, lineWidth: 1)
                                )
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipped()
                    .cornerRadius(3)

                    Text(Brand.galleryChip)
                        .font(AppType.micro(9))
                        .appChromeText()
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(minWidth: AppTheme.hitTarget, minHeight: AppTheme.hitTarget)
            }
            .accessibilityLabel("Gallery")
            .disabled(capturing)

            Spacer()

            Wordmark()
                .padding(.top, 6)

            Spacer()

            Button {
                path.append(HomeRoute.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: AppTheme.hitTarget, height: AppTheme.hitTarget)
            }
            .accessibilityLabel("Settings")
            .disabled(capturing)
        }
    }

    private var viewfinder: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, 340)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surfaceRaised)
                preview
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 340)
    }

    @ViewBuilder
    private var preview: some View {
        #if DEBUG
        if ScreenshotHarness.isActive {
            ScreenshotViewfinder()
        } else {
            CameraPreviewView(session: camera.session)
        }
        #else
        CameraPreviewView(session: camera.session)
        #endif
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: AppTheme.hitTarget, height: AppTheme.hitTarget)
            }
            .accessibilityLabel("Flip camera")
            .disabled(capturing || camera.isSwitchingCamera)

            Button {
                // Fire immediately on press — flash/pipeline stay silent after this click.
                Haptics.shutter()
                Task { await capture() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(AppTheme.textPrimary, lineWidth: 4)
                        .frame(width: AppTheme.shutter, height: AppTheme.shutter)
                    Circle()
                        .fill(AppTheme.accentFill)
                        .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                        .frame(width: AppTheme.shutter - 14, height: AppTheme.shutter - 14)
                }
                .scaleEffect(shutterPressed ? 0.88 : 1)
            }
            .accessibilityLabel("Capture")
            .disabled(
                capturing
                    || camera.isSwitchingCamera
                    || (usesCamera && camera.permission != .authorized)
            )

            Button {
                camera.toggleFlash()
            } label: {
                Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: AppTheme.hitTarget, height: AppTheme.hitTarget)
            }
            .accessibilityLabel("Flash")
            .accessibilityValue(camera.isFlashOn ? "on" : "off")
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Text(Brand.cameraDeniedTitle)
                .font(AppType.display(22, weight: .semibold))
                .appChromeText()
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(Brand.name) needs the camera to take prints. turn it on in settings.")
                .font(AppType.body(17))
                .appChromeText()
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(Brand.openSettings)
                    .font(AppType.body(17, weight: .semibold))
                    .appChromeText()
                    .foregroundStyle(AppTheme.accentText)
                    .frame(minHeight: AppTheme.hitTarget)
                    .padding(.horizontal, 20)
                    .background(AppTheme.accentFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Open Settings")
        }
    }

    private func capture() async {
        guard !capturing else { return }
        capturing = true
        let id = UUID().uuidString
        var didPush = false
        let plan = camera.flashPlan

        do {
            let photo: UIImage
            if plan == .screen {
                // Functional lighting for selfie — wait for session/AE, shoot, then restore before push.
                ScreenFlash.begin()
                screenFlash = true
                defer {
                    ScreenFlash.end()
                    screenFlash = false
                }
                if !reduceMotion {
                    shutterPressed = true
                }
                // Brief settle so the white overlay is painted before AE reacts.
                try? await Task.sleep(nanoseconds: 150_000_000)
                photo = try await camera.takePhotoAfterScreenFlash()
                shutterPressed = false
            } else {
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.06)) {
                        shutterPressed = true
                        shutterFlash = true
                    }
                }

                async let photoWork = camera.capturePhotoResilient()

                if !reduceMotion {
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    withAnimation(.easeIn(duration: 0.12)) {
                        shutterFlash = false
                        shutterPressed = false
                    }
                }

                path.append(PrintRoute.captured(id: id))
                didPush = true
                photo = try await photoWork
            }

            if !didPush {
                path.append(PrintRoute.captured(id: id))
                didPush = true
            }

            let settings = settingsStore.settings
            let processed = try await Task.detached(priority: .userInitiated) {
                try PolaroidPipeline.processCapture(
                    image: photo,
                    captionMode: settings.captionMode,
                    dateFormat: settings.dateFormat,
                    dateCase: settings.dateCase,
                    customText: settings.customDefault,
                    captionFont: settings.captionFont,
                    captionFontSize: settings.captionFontSize,
                    captionHighlight: settings.captionHighlight,
                    serendipitySeed: id
                )
            }.value
            try store.create(
                id: id,
                caption: processed.caption,
                captionMode: processed.captionMode,
                captionFont: settings.captionFont,
                captionFontSize: settings.captionFontSize,
                captionHighlight: settings.captionHighlight,
                captionLetterCase: settings.dateCase,
                dateFormat: settings.dateFormat,
                filmStock: processed.filmStock,
                filmStrength: processed.filmStrength,
                originalJPEG: processed.originalJPEG,
                polaroidPNG: processed.polaroidPNG
            )
            capturing = false
        } catch {
            if didPush, !path.isEmpty {
                path.removeLast()
            }
            shutterFlash = false
            screenFlash = false
            shutterPressed = false
            capturing = false
            captureError = error.localizedDescription
            showCaptureAlert = true
        }
    }
}

enum HomeRoute: Hashable {
    case gallery
    case settings
}
