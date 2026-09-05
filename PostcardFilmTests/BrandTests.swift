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

    func testAppVersionLabelIncludesMarketingAndBuild() {
        let expected = "\(Brand.wordmark) \(AppVersion.marketing) (\(AppVersion.build))"
        XCTAssertEqual(AppVersion.label, expected)
        XCTAssertFalse(AppVersion.marketing.isEmpty)
        XCTAssertFalse(AppVersion.build.isEmpty)
        XCTAssertEqual(AppVersion.marketing, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        XCTAssertEqual(AppVersion.build, Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
    }

    func testCreditMatchesBrand() {
        XCTAssertEqual(AppVersion.credit, Brand.credit)
        XCTAssertEqual(Brand.credit, "made by ayan ray in dublin.")
    }

    func testScreenCopyNonEmpty() {
        XCTAssertFalse(Brand.homeTagline.isEmpty)
        XCTAssertEqual(Brand.gallerySubtext, "prints you've kept.")
        XCTAssertEqual(Brand.settingsSubtext, "your defaults for new prints.")
        XCTAssertEqual(Brand.settingsSubtext, Brand.settingsSubtext.lowercased())
        XCTAssertEqual(Brand.homeTagline, Brand.homeTagline.lowercased())
        XCTAssertEqual(Brand.developing, Brand.developing.lowercased())
        XCTAssertEqual(Brand.credit, Brand.credit.lowercased())
        XCTAssertEqual(Brand.deleteConfirmOne, "are you sure, delete this print?")
        XCTAssertEqual(Brand.deleteConfirm(count: 1), Brand.deleteConfirmOne)
        XCTAssertEqual(Brand.deleteConfirm(count: 3), "are you sure, delete 3 prints?")
        XCTAssertEqual(Brand.deleteAction, "delete")
        XCTAssertEqual(Brand.deleteGoBack, "go back")
        XCTAssertEqual(CaptionMode.date.label, "date")
        XCTAssertEqual(CaptionMode.custom.label, "custom")
        XCTAssertEqual(CaptionMode.blank.label, "blank")
    }
}
