import XCTest
@testable import PostcardFilm

final class GallerySelectionTests: XCTestCase {
    func testToggleAddsAndRemoves() {
        var selected = Set<String>()
        selected = GallerySelectionLogic.toggle("a", in: selected)
        XCTAssertEqual(selected, ["a"])
        selected = GallerySelectionLogic.toggle("b", in: selected)
        XCTAssertEqual(selected, ["a", "b"])
        selected = GallerySelectionLogic.toggle("a", in: selected)
        XCTAssertEqual(selected, ["b"])
    }

    func testSelectAll() {
        let all = GallerySelectionLogic.selectAll(ids: ["a", "b", "c"])
        XCTAssertEqual(all, ["a", "b", "c"])
    }

    func testLongPressEntersWithOneId() {
        let result = GallerySelectionLogic.enterLongPress(
            id: "a",
            selecting: false,
            selected: []
        )
        XCTAssertTrue(result.selecting)
        XCTAssertEqual(result.selected, ["a"])
    }

    func testLongPressWhileSelectingInsertsNotReplaces() {
        let result = GallerySelectionLogic.enterLongPress(
            id: "b",
            selecting: true,
            selected: ["a"]
        )
        XCTAssertTrue(result.selecting)
        XCTAssertEqual(result.selected, ["a", "b"])
    }

    func testLongPressWhileSelectingTogglesExisting() {
        let result = GallerySelectionLogic.enterLongPress(
            id: "a",
            selecting: true,
            selected: ["a", "b"]
        )
        XCTAssertEqual(result.selected, ["b"])
    }
}
