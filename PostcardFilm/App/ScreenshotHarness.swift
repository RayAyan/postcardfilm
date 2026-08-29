#if DEBUG
import SwiftUI
import UIKit

/// Debug-only support for capturing App Store screenshots in the Simulator, which
/// has no camera. Launch with `-SCREENSHOTS -SCREENSHOT_SCREEN <screen>` and place
/// square source photos in the app container's `Documents/_seed`.
enum ScreenshotHarness {
    enum Screen: String {
        case home
        case developing
        case process
        case gallery
        case settings
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-SCREENSHOTS")
    }

    static var screen: Screen {
        Screen(rawValue: argument(after: "-SCREENSHOT_SCREEN") ?? "") ?? .home
    }

    static var hidesStatusBar: Bool {
        ProcessInfo.processInfo.arguments.contains("-SCREENSHOT_NO_STATUS_BAR")
    }

    /// `-SCREENSHOT_COUNT n` trims how many prints get seeded.
    private static var sampleLimit: Int {
        guard let raw = argument(after: "-SCREENSHOT_COUNT"),
              let count = Int(raw),
              count > 0
        else {
            return samples.count
        }
        return min(count, samples.count)
    }

    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    /// Stand-in for the live camera feed.
    static var viewfinderStill: UIImage? {
        guard let url = seedURLs.first else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    @MainActor
    static func seed(store: PolaroidStore) {
        let images = seedURLs.compactMap { UIImage(contentsOfFile: $0.path) }
        guard !images.isEmpty else { return }

        let root = documents.appendingPathComponent("polaroids", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var records: [PolaroidRecord] = []

        for (offset, sample) in samples.prefix(sampleLimit).enumerated() {
            let image = images[sample.photo % images.count]
            let date = Date().addingTimeInterval(-Double(offset) * 86_400)
            let mode: CaptionMode = sample.caption == nil ? .date : .custom
            guard let processed = try? PolaroidPipeline.processCapture(
                image: image,
                captionMode: mode,
                dateFormat: .long,
                dateCase: .lowercase,
                customText: sample.caption ?? "",
                captionFont: sample.font,
                captionHighlight: sample.highlight,
                date: date
            ) else { continue }

            let id = String(format: "seed-%02d", offset)
            let dir = root.appendingPathComponent(id, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? processed.originalJPEG.write(to: dir.appendingPathComponent("original.jpg"))
            try? processed.polaroidPNG.write(to: dir.appendingPathComponent("polaroid.png"))

            var backNote: String?
            if let note = sample.backNote {
                let trimmed = Caption.truncateBackNote(note)
                if !trimmed.isEmpty,
                   let back = try? PolaroidPipeline.renderBack(note: trimmed, font: sample.font),
                   let png = back.pngData()
                {
                    try? png.write(to: dir.appendingPathComponent("back.png"))
                    backNote = trimmed
                }
            }

            records.append(
                PolaroidRecord(
                    id: id,
                    createdAt: stamp.string(from: date),
                    caption: processed.caption,
                    captionMode: mode,
                    captionFont: sample.font,
                    captionHighlight: sample.highlight,
                    backNote: backNote,
                    backFont: sample.font
                )
            )
        }

        let index = PolaroidIndex(version: 1, items: records)
        try? PolaroidIndexLogic.serialize(index)
            .data(using: .utf8)?
            .write(to: root.appendingPathComponent("index.json"))
        store.reload()
    }

    private struct Sample {
        let photo: Int
        /// `nil` burns the date instead.
        let caption: String?
        var backNote: String? = nil
        let font: CaptionFont
        var highlight: Bool = true
    }

    private static let samples: [Sample] = [
        Sample(photo: 2, caption: "Kananaskis Lake", backNote: "the water was freezing and we stayed anyway.", font: .script),
        Sample(photo: 0, caption: nil, font: .serif),
        Sample(photo: 1, caption: "sandymount", font: .typewriter),
    ]

    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var seedURLs: [URL] {
        let dir = documents.appendingPathComponent("_seed", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// Seeds the store, then pins the app to a single screen.
struct ScreenshotRoot: View {
    @EnvironmentObject private var store: PolaroidStore
    @State private var seeded = false

    var body: some View {
        Group {
            if seeded {
                screen
            } else {
                AppTheme.surface.ignoresSafeArea()
            }
        }
        .statusBarHidden(ScreenshotHarness.hidesStatusBar)
        .task {
            ScreenshotHarness.seed(store: store)
            seeded = true
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch ScreenshotHarness.screen {
        case .home:
            HomeView()
        case .developing:
            NavigationStack {
                ProcessView(id: firstID, openedFromCapture: true)
            }
        case .process:
            NavigationStack {
                ProcessView(id: firstID, openedFromCapture: false)
            }
        case .gallery:
            NavigationStack {
                GalleryView(path: .constant(NavigationPath()))
            }
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }

    private var firstID: String {
        store.items.first?.id ?? ""
    }
}

/// Still frame shown where the camera preview would be.
struct ScreenshotViewfinder: View {
    var body: some View {
        if let still = ScreenshotHarness.viewfinderStill {
            Image(uiImage: still)
                .resizable()
                .scaledToFill()
        } else {
            AppTheme.surfaceRaised
        }
    }
}
#endif
