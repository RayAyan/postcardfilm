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

    func testLongDateZeroPadsSingleDigitDay() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 3
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let early = cal.date(from: comps)!
        XCTAssertEqual(Caption.formatDate(early, format: .long), "03 jan 2026")
        XCTAssertEqual(
            Caption.formatDate(early, format: .long, letterCase: .sentence),
            "03 Jan 2026"
        )
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

    // MARK: - Burn dirty checks

    private func makeRecord(
        caption: String = "29 aug 2026",
        captionMode: CaptionMode = .date,
        captionFont: CaptionFont = .serif,
        captionFontSize: CaptionFontSize = .medium,
        captionHighlight: Bool = true,
        captionLetterCase: DateCaseStyle = .lowercase,
        dateFormat: DateFormatOption = .long,
        backNote: String? = nil,
        backFont: CaptionFont = .script,
        backFontSize: CaptionFontSize = .medium,
        backLetterCase: DateCaseStyle = .lowercase
    ) -> PolaroidRecord {
        PolaroidRecord(
            id: "test",
            createdAt: "2026-08-29T12:00:00.000Z",
            caption: caption,
            captionMode: captionMode,
            captionFont: captionFont,
            captionFontSize: captionFontSize,
            captionHighlight: captionHighlight,
            captionLetterCase: captionLetterCase,
            dateFormat: dateFormat,
            backNote: backNote,
            backFont: backFont,
            backFontSize: backFontSize,
            backLetterCase: backLetterCase
        )
    }

    func testFrontBurnNeededUnchangedDate() {
        let record = makeRecord()
        XCTAssertFalse(
            Caption.frontBurnNeeded(
                record: record,
                mode: .date,
                customText: "",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: true
            )
        )
    }

    func testFrontBurnNeededUnchangedCustom() {
        let record = makeRecord(caption: "beach day", captionMode: .custom)
        XCTAssertFalse(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "beach day",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: true
            )
        )
    }

    func testFrontBurnNeededUnchangedBlank() {
        let record = makeRecord(caption: "", captionMode: .blank)
        XCTAssertFalse(
            Caption.frontBurnNeeded(
                record: record,
                mode: .blank,
                customText: "",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: true
            )
        )
    }

    func testFrontBurnNeededDetectsStyleAndTextChanges() {
        let record = makeRecord(caption: "beach day", captionMode: .custom)
        XCTAssertTrue(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "beach day",
                font: .modern,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: true
            )
        )
        XCTAssertTrue(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "beach day",
                font: .serif,
                fontSize: .large,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: true
            )
        )
        XCTAssertTrue(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "beach day",
                font: .serif,
                fontSize: .medium,
                letterCase: .sentence,
                dateFormat: .long,
                highlight: true
            )
        )
        XCTAssertTrue(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "beach day",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .iso,
                highlight: true
            )
        )
        XCTAssertTrue(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "beach day",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: false
            )
        )
        XCTAssertTrue(
            Caption.frontBurnNeeded(
                record: record,
                mode: .custom,
                customText: "other day",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase,
                dateFormat: .long,
                highlight: true
            )
        )
    }

    func testBackBurnNeededUnchangedBlank() {
        let record = makeRecord()
        XCTAssertFalse(
            Caption.backBurnNeeded(
                record: record,
                note: "",
                font: .script,
                fontSize: .medium,
                letterCase: .lowercase
            )
        )
        XCTAssertFalse(
            Caption.backBurnNeeded(
                record: record,
                note: "   ",
                font: .script,
                fontSize: .medium,
                letterCase: .lowercase
            )
        )
    }

    func testBackBurnNeededDetectsNoteChanges() {
        let record = makeRecord(backNote: "hello")
        XCTAssertFalse(
            Caption.backBurnNeeded(
                record: record,
                note: "hello",
                font: .script,
                fontSize: .medium,
                letterCase: .lowercase
            )
        )
        XCTAssertTrue(
            Caption.backBurnNeeded(
                record: record,
                note: "goodbye",
                font: .script,
                fontSize: .medium,
                letterCase: .lowercase
            )
        )
        XCTAssertTrue(
            Caption.backBurnNeeded(
                record: record,
                note: "hello",
                font: .serif,
                fontSize: .medium,
                letterCase: .lowercase
            )
        )
    }
}
