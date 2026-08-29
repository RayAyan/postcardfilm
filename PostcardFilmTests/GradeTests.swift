import XCTest
@testable import PostcardFilm

final class GradeTests: XCTestCase {
    private func luma(_ r: Int, _ g: Int, _ b: Int) -> Double {
        0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }

    func testLiftsNearBlack() {
        let out = Grade.gradeRgb255(r: 0, g: 0, b: 0)
        XCTAssertGreaterThan(out.r, 0)
        XCTAssertGreaterThan(out.g, 0)
        XCTAssertGreaterThan(out.b, 0)
        XCTAssertGreaterThanOrEqual(out.b, out.r - 10)
    }

    func testCreamsPureWhite() {
        let out = Grade.gradeRgb255(r: 255, g: 255, b: 255)
        XCTAssertLessThan(out.r, 255)
        XCTAssertLessThan(out.g, 255)
        XCTAssertLessThan(out.b, 255)
        XCTAssertLessThanOrEqual(out.b, out.r)
        XCTAssertGreaterThanOrEqual(out.r, out.g)
        XCTAssertGreaterThanOrEqual(out.g, out.b)
    }

    func testWarmsMidGray() {
        let out = Grade.gradeRgb255(r: 128, g: 128, b: 128)
        XCTAssertGreaterThan(out.r, out.b)
    }

    func testMidGrayBrightens() {
        let out = Grade.gradeRgb255(r: 128, g: 128, b: 128)
        XCTAssertGreaterThan(luma(out.r, out.g, out.b), luma(128, 128, 128))
    }

    func testExposureEVIsSunny() {
        XCTAssertGreaterThan(Grade.exposureEV(), 0.25)
    }

    func testChannelsStayInRange() {
        let samples = [
            RGB(r: 0, g: 0, b: 0),
            RGB(r: 1, g: 1, b: 1),
            RGB(r: 0.5, g: 0.2, b: 0.8),
            RGB(r: 0.1, g: 0.9, b: 0.3),
        ]
        for sample in samples {
            let out = Grade.gradePixel(sample)
            XCTAssertGreaterThanOrEqual(out.r, 0)
            XCTAssertLessThanOrEqual(out.r, 1)
            XCTAssertGreaterThanOrEqual(out.g, 0)
            XCTAssertLessThanOrEqual(out.g, 1)
            XCTAssertGreaterThanOrEqual(out.b, 0)
            XCTAssertLessThanOrEqual(out.b, 1)
        }
    }
}
