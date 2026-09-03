import XCTest
@testable import PostcardFilm

final class AppSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = AppSettings.default
        XCTAssertEqual(settings.captionMode, .date)
        XCTAssertFalse(settings.saveOnCapture)
        XCTAssertEqual(settings.dateFormat, .long)
        XCTAssertEqual(settings.captionFont, .serif)
        XCTAssertEqual(settings.captionFontSize, .medium)
        XCTAssertTrue(settings.captionHighlight)
        XCTAssertEqual(settings.dateCase, .lowercase)
    }

    func testStoredSettingsMissingFontSizeDefaultsMedium() throws {
        let raw = """
        {"captionMode":"date","dateFormat":"long","customDefault":"","saveOnCapture":false,"captionFont":"serif","captionHighlight":true}
        """
        let data = try XCTUnwrap(raw.data(using: .utf8))
        let settings = try AppSettings.fromStoredJSON(data)
        XCTAssertEqual(settings.captionFontSize, .medium)
    }

    func testSettingsDoNotMutateExistingPrints() {
        XCTAssertFalse(AppSettings.settingsAffectExistingPrints())
    }
}
