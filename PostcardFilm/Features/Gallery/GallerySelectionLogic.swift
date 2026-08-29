import Foundation

/// Pure gallery multi-select helpers (unit-tested; used by GalleryView).
enum GallerySelectionLogic {
    static func toggle(_ id: String, in selected: Set<String>) -> Set<String> {
        var next = selected
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        return next
    }

    static func selectAll(ids: [String]) -> Set<String> {
        Set(ids)
    }

    /// Long-press: enter select with this id, or insert/toggle if already selecting.
    /// Never replaces the whole selection set when already selecting.
    static func enterLongPress(
        id: String,
        selecting: Bool,
        selected: Set<String>
    ) -> (selecting: Bool, selected: Set<String>) {
        if selecting {
            return (true, toggle(id, in: selected))
        }
        return (true, [id])
    }
}
