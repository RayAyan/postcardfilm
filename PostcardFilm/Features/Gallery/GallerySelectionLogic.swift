import Foundation

/// Pure gallery multi-select helpers (unit-tested; used by GalleryView).
enum GallerySelectionLogic {
    enum DragPaintMode: Equatable {
        case select
        case deselect
    }

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

    /// First cell under a drag stroke sets whether the stroke selects or deselects.
    static func paintMode(for id: String, startingFrom selected: Set<String>) -> DragPaintMode {
        selected.contains(id) ? .deselect : .select
    }

    /// Apply one hit during a drag stroke — insert or remove, never toggle mid-stroke.
    static func applyDragHit(
        id: String,
        mode: DragPaintMode,
        to selected: Set<String>
    ) -> Set<String> {
        var next = selected
        switch mode {
        case .select:
            next.insert(id)
        case .deselect:
            next.remove(id)
        }
        return next
    }

    /// Apply ordered unique hits in one stroke.
    static func applyDragHits(
        _ ids: [String],
        mode: DragPaintMode,
        to selected: Set<String>
    ) -> Set<String> {
        ids.reduce(selected) { partial, id in
            applyDragHit(id: id, mode: mode, to: partial)
        }
    }
}
