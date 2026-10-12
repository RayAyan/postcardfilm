import XCTest
@testable import PostcardFilm

final class GalleryPagingTests: XCTestCase {
    private func record(_ id: String) -> PolaroidRecord {
        PolaroidRecord(
            id: id,
            createdAt: "2026-01-01T00:00:00Z",
            caption: id,
            captionMode: .date,
            captionFont: .serif,
            filmStock: .onestep
        )
    }

    func testNeighborsExcludeCurrentWithinRadiusTwo() {
        let items = ["a", "b", "c", "d", "e"].map(record)
        XCTAssertEqual(
            GalleryPagingLogic.neighborIDs(items: items, currentID: "c"),
            ["a", "b", "d", "e"]
        )
        XCTAssertEqual(
            GalleryPagingLogic.neighborIDs(items: items, currentID: "a"),
            ["b", "c"]
        )
        XCTAssertEqual(
            GalleryPagingLogic.neighborIDs(items: items, currentID: "e"),
            ["c", "d"]
        )
    }

    func testNeighborsCustomRadius() {
        let items = ["a", "b", "c"].map(record)
        XCTAssertEqual(
            GalleryPagingLogic.neighborIDs(items: items, currentID: "b", radius: 1),
            ["a", "c"]
        )
    }

    func testNeighborsUnknownOrEmpty() {
        let items = ["a", "b"].map(record)
        XCTAssertEqual(
            GalleryPagingLogic.neighborIDs(items: items, currentID: "missing"),
            []
        )
        XCTAssertEqual(
            GalleryPagingLogic.neighborIDs(items: [], currentID: "a"),
            []
        )
    }
}
