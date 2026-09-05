import Foundation

/// User-facing brand strings. All lowercase; brand is `postcardfilm` (no space).
enum Brand {
    static let name = "postcardfilm"
    static let wordmark = "postcardfilm."
    static let credit = "made by ayan ray in dublin."

    static let homeTagline = "take a photo."
    static let gallerySubtext = "prints you've kept."
    static let settingsSubtext = "your defaults for new prints."
    static let processHint = "tap the strip. write something."
    static let backHint = "write on the back."
    static let developing = "developing…"
    static let galleryChip = "gallery"

    static let emptyGallery = "no prints yet."
    static let takeOne = "take one"

    static let cameraDeniedTitle = "camera access is off"
    static let openSettings = "open settings"
    static let printGone = "this print is gone"
    static let backToGallery = "back to gallery"

    static let deleteConfirmOne = "are you sure, delete this print?"
    static let deleteAction = "delete"
    static let deleteGoBack = "go back"

    static func deleteConfirm(count: Int) -> String {
        count == 1 ? deleteConfirmOne : "are you sure, delete \(count) prints?"
    }
}
