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
        XCTAssertEqual(settings.captionHighlight, true)
        XCTAssertEqual(settings.dateCase, .lowercase)
        XCTAssertEqual(settings.backFont, .script)
        XCTAssertEqual(settings.backFontSize, .medium)
        XCTAssertEqual(settings.backLetterCase, .lowercase)
    }

    func testStoredSettingsMissingFontSizeDefaultsMedium() throws {
        let raw = """
        {"captionMode":"date","dateFormat":"long","customDefault":"","saveOnCapture":false,"captionFont":"serif","captionHighlight":true}
        """
        let data = try XCTUnwrap(raw.data(using: .utf8))
        let settings = try AppSettings.fromStoredJSON(data)
        XCTAssertEqual(settings.captionFontSize, .medium)
        XCTAssertEqual(settings.backFont, .script)
        XCTAssertEqual(settings.backFontSize, .medium)
        XCTAssertEqual(settings.backLetterCase, .lowercase)
    }

    func testSettingsDoNotMutateExistingPrints() {
        XCTAssertFalse(AppSettings.settingsAffectExistingPrints())
    }

    func testFrontAndBackStyleDefaultsAreIndependent() {
        var settings = AppSettings.default
        settings.captionFont = .modern
        settings.captionFontSize = .large
        settings.dateCase = .sentence
        // Back defaults stay independent until a blank reverse is opened.
        XCTAssertEqual(settings.backFont, .script)
        XCTAssertEqual(settings.backFontSize, .medium)
        XCTAssertEqual(settings.backLetterCase, .lowercase)
        settings.backFont = .typewriter
        XCTAssertEqual(settings.captionFont, .modern)
        XCTAssertEqual(settings.backFont, .typewriter)
    }
}
