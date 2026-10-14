import AVFoundation
import XCTest
@testable import PostcardFilm

final class CameraFacingTests: XCTestCase {
    func testToggleBackToFront() {
        XCTAssertEqual(CameraFacing.toggled(.back), .front)
    }

    func testToggleFrontToBack() {
        XCTAssertEqual(CameraFacing.toggled(.front), .back)
    }

    func testToggleIsInvolution() {
        XCTAssertEqual(CameraFacing.toggled(CameraFacing.toggled(.back)), .back)
        XCTAssertEqual(CameraFacing.toggled(CameraFacing.toggled(.front)), .front)
    }

    func testOnlyFrontIsMirrored() {
        XCTAssertTrue(CameraFacing.shouldMirrorPreview(for: .front))
        XCTAssertFalse(CameraFacing.shouldMirrorPreview(for: .back))
        XCTAssertFalse(CameraFacing.shouldMirrorPreview(for: .unspecified))
    }
}
