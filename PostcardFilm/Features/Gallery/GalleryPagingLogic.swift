import Foundation

/// Pure helpers for gallery Process paging (unit-tested).
enum GalleryPagingLogic {
    /// Nearby pages for thumbnail prefetch (±2 by default).
    static func neighborIDs(
        items: [PolaroidRecord],
        currentID: String,
        radius: Int = 2
    ) -> [String] {
        guard let idx = items.firstIndex(where: { $0.id == currentID }) else { return [] }
        let span = max(radius, 0)
        let start = max(0, idx - span)
        let end = min(items.count - 1, idx + span)
        guard start <= end else { return [] }
        var ids: [String] = []
        for i in start ... end where i != idx {
            ids.append(items[i].id)
        }
        return ids
    }
}
