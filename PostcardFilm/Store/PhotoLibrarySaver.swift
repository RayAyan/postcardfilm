import Photos
import UIKit

enum PhotoLibrarySaveResult: Equatable {
    case saved
    case denied
    case failed(String)

    static func == (lhs: PhotoLibrarySaveResult, rhs: PhotoLibrarySaveResult) -> Bool {
        switch (lhs, rhs) {
        case (.saved, .saved), (.denied, .denied):
            return true
        case let (.failed(a), .failed(b)):
            return a == b
        default:
            return false
        }
    }
}

enum PhotoLibrarySaver {
    /// Authorization + write. Image decode and PhotoKit work run off the main actor.
    static func saveImage(at url: URL) async -> PhotoLibrarySaveResult {
        await saveImages(at: [url])
    }

    static func saveImage(data: Data) async -> PhotoLibrarySaveResult {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return .denied
        }

        let image = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)
        }.value

        guard let image else {
            return .failed("Could not load print.")
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Saves one or more images in a single Photos change. Empty list fails.
    static func saveImages(at urls: [URL]) async -> PhotoLibrarySaveResult {
        guard !urls.isEmpty else {
            return .failed("Nothing to save.")
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return .denied
        }

        let images = await Task.detached(priority: .userInitiated) {
            urls.compactMap { UIImage(contentsOfFile: $0.path) }
        }.value

        guard images.count == urls.count else {
            return .failed("Could not load print.")
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in images {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
