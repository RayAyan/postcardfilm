import XCTest
@testable import PostcardFilm

final class BrandTests: XCTestCase {
    func testNameHasNoSpace() {
        XCTAssertEqual(Brand.name, "postcardfilm")
        XCTAssertFalse(Brand.name.contains(" "))
    }

    func testWordmark() {
        XCTAssertEqual(Brand.wordmark, "postcardfilm.")
        XCTAssertTrue(Brand.wordmark.hasPrefix(Brand.name))
    }

    func testAppVersionLabelUsesBrand() {
        XCTAssertTrue(AppVersion.label.hasPrefix(Brand.wordmark))
        XCTAssertFalse(AppVersion.label.lowercased().contains("postcard film"))
        XCTAssertFalse(AppVersion.label.lowercased().contains("polaroid"))
    }

    func testCreditMatchesBrand() {
        XCTAssertEqual(AppVersion.credit, Brand.credit)
        XCTAssertEqual(Brand.credit, "made by ayan ray in dublin.")
    }

    func testScreenCopyNonEmpty() {
        XCTAssertFalse(Brand.homeTagline.isEmpty)
        XCTAssertEqual(Brand.gallerySubtext, "prints you've kept.")
        XCTAssertEqual(Brand.homeTagline, Brand.homeTagline.lowercased())
        XCTAssertEqual(Brand.developing, Brand.developing.lowercased())
        XCTAssertEqual(Brand.credit, Brand.credit.lowercased())
        XCTAssertEqual(CaptionMode.date.label, "date")
        XCTAssertEqual(CaptionMode.custom.label, "custom")
        XCTAssertEqual(CaptionMode.blank.label, "blank")
    }
}
