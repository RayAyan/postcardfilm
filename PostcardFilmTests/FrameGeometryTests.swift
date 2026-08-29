import XCTest
@testable import PostcardFilm

final class FrameGeometryTests: XCTestCase {
    func testBottomStripInBand() {
        let layout = FrameGeometry.computeFrameLayout(imageSide: 1080)
        let ratio = FrameGeometry.bottomRatio(of: layout)
        XCTAssertGreaterThanOrEqual(ratio, 0.22)
        XCTAssertLessThanOrEqual(ratio, 0.26)
    }

    func testSideBordersInBand() {
        let layout = FrameGeometry.computeFrameLayout(imageSide: 1080)
        let ratio = FrameGeometry.sideRatio(of: layout)
        XCTAssertGreaterThanOrEqual(ratio, 0.08)
        XCTAssertLessThanOrEqual(ratio, 0.10)
        XCTAssertEqual(layout.top, layout.side)
    }

    func testImagePlacement() {
        let layout = FrameGeometry.computeFrameLayout(imageSide: 1080)
        XCTAssertEqual(layout.imageX, layout.side)
        XCTAssertEqual(layout.imageY, layout.top)
        XCTAssertEqual(layout.canvasWidth, layout.imageSide + layout.side * 2)
        XCTAssertEqual(layout.canvasHeight, layout.imageSide + layout.top + layout.bottom)
        XCTAssertEqual(layout.stripHeight, layout.bottom)
    }
}
