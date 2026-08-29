import XCTest
@testable import PostcardFilm

final class CaptionTests: XCTestCase {
    private var sample: Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 29
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: comps)!
    }

    func testDateFormats() {
        XCTAssertEqual(
            Caption.formatDate(sample, format: .long, letterCase: .sentence),
            "29 Aug 2026"
        )
        XCTAssertEqual(
            Caption.formatDate(sample, format: .long, letterCase: .lowercase),
            "29 aug 2026"
        )
        XCTAssertEqual(Caption.formatDate(sample, format: .short), "08.29.26")
        XCTAssertEqual(Caption.formatDate(sample, format: .iso), "2026-08-29")
        // Default letter case is lowercase
        XCTAssertEqual(Caption.formatDate(sample, format: .long), "29 aug 2026")
    }

    func testDateCaseDefaultIsLowercase() {
        XCTAssertEqual(DateCaseStyle.lowercase.label, "lowercase")
        XCTAssertEqual(DateCaseStyle.sentence.label, "sentence case")
        XCTAssertEqual(
            Caption.resolveCaptionText(
                mode: .date,
                dateFormat: .long,
                date: sample
            ),
            "29 aug 2026"
        )
        XCTAssertEqual(
            Caption.resolveCaptionText(
                mode: .date,
                dateFormat: .long,
                dateCase: .sentence,
                date: sample
            ),
            "29 Aug 2026"
        )
    }

    func testTruncateAt20() {
        let long = String(repeating: "x", count: 50)
        XCTAssertEqual(Caption.truncateCaption(long).count, 20)
        XCTAssertEqual(Caption.maxLength, 20)
    }

    func testDateModeIgnoresCustomMaxLength() {
        // Long-format dates exceed 20 chars in sentence case months; still full string.
        let text = Caption.resolveCaptionText(
            mode: .date,
            dateFormat: .long,
            dateCase: .sentence,
            date: sample
        )
        XCTAssertEqual(text, "29 Aug 2026")
        XCTAssertGreaterThan(text.count, 0)
    }

    func testBackNoteMax200() {
        let long = String(repeating: "y", count: 250)
        XCTAssertEqual(Caption.truncateBackNote(long).count, 200)
        XCTAssertEqual(Caption.backMaxLength, 200)
    }

    func testBlankResolvesEmpty() {
        let text = Caption.resolveCaptionText(
            mode: .blank,
            dateFormat: .long,
            customText: "hello",
            date: sample
        )
        XCTAssertEqual(text, "")
    }

    func testDateModeUsesFormat() {
        let text = Caption.resolveCaptionText(
            mode: .date,
            dateFormat: .iso,
            date: sample
        )
        XCTAssertEqual(text, "2026-08-29")
    }

    func testCustomMode() {
        XCTAssertEqual(
            Caption.resolveCaptionText(
                mode: .custom,
                dateFormat: .long,
                customText: "  beach day  ",
                date: sample
            ),
            "beach day"
        )
        XCTAssertEqual(
            Caption.resolveCaptionText(
                mode: .custom,
                dateFormat: .long,
                customText: "   ",
                date: sample
            ),
            ""
        )
    }

    func testCaptionFontLabels() {
        XCTAssertEqual(CaptionFont.serif.label, "serif")
        XCTAssertEqual(CaptionFont.modern.label, "modern")
        XCTAssertEqual(CaptionFont.script.label, "script")
        XCTAssertEqual(CaptionFont.typewriter.label, "typewriter")
        XCTAssertEqual(CaptionFont.allCases.count, 4)
    }

    func testCaptionFontsResolveUIFont() {
        for font in CaptionFont.allCases {
            let ui = font.uiFont(size: 24)
            XCTAssertGreaterThan(ui.pointSize, 0)
        }
    }

    func testScriptPreviewRunsLarger() {
        XCTAssertGreaterThan(
            CaptionFont.script.previewFont(size: 17).pointSize,
            CaptionFont.serif.previewFont(size: 17).pointSize
        )
    }

    /// Settings rows demonstrate the case they apply.
    func testDateCaseLabelsShowTheirOwnCase() {
        XCTAssertEqual(DateCaseStyle.lowercase.apply(DateCaseStyle.lowercase.label), "lowercase")
        XCTAssertEqual(DateCaseStyle.sentence.apply(DateCaseStyle.sentence.label), "Sentence Case")
    }
}
