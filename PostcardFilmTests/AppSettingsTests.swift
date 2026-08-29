import XCTest
@testable import PostcardFilm

final class AppSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = AppSettings.default
        XCTAssertEqual(settings.captionMode, .date)
        XCTAssertFalse(settings.saveOnCapture)
        XCTAssertEqual(settings.dateFormat, .long)
        XCTAssertEqual(settings.captionFont, .serif)
        XCTAssertTrue(settings.captionHighlight)
        XCTAssertEqual(settings.dateCase, .lowercase)
    }

    func testSettingsDoNotMutateExistingPrints() {
        XCTAssertFalse(AppSettings.settingsAffectExistingPrints())
    }
}
