import XCTest
@testable import PostcardFilm

final class PolaroidIndexTests: XCTestCase {
    private let older = PolaroidRecord(
        id: "a",
        createdAt: "2026-01-01T00:00:00.000Z",
        caption: "old",
        captionMode: .date,
        captionFont: .serif,
        captionHighlight: true
    )
    private let newer = PolaroidRecord(
        id: "b",
        createdAt: "2026-08-29T00:00:00.000Z",
        caption: "new",
        captionMode: .custom,
        captionFont: .script,
        captionHighlight: false,
        backNote: "a longer note on the reverse"
    )

    func testNewestFirst() {
        let sorted = PolaroidIndexLogic.sortNewestFirst([older, newer])
        XCTAssertEqual(sorted.map(\.id), ["b", "a"])
    }

    func testAddAndFind() {
        var index = PolaroidIndex.empty
        index = PolaroidIndexLogic.add(to: index, record: older)
        index = PolaroidIndexLogic.add(to: index, record: newer)
        XCTAssertEqual(index.items[0].id, "b")
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.caption, "old")
    }

    func testRemoveLeavesNoRow() {
        var index = PolaroidIndexLogic.add(to: .empty, record: older)
        index = PolaroidIndexLogic.add(to: index, record: newer)
        index = PolaroidIndexLogic.remove(from: index, id: "b")
        XCTAssertNil(PolaroidIndexLogic.find(in: index, id: "b"))
        XCTAssertEqual(index.items.count, 1)
        XCTAssertEqual(index.items[0].id, "a")
    }

    func testMissingId() {
        let index = PolaroidIndexLogic.add(to: .empty, record: older)
        XCTAssertNil(PolaroidIndexLogic.find(in: index, id: "missing"))
    }

    func testUpdateCaptionLeavesOthers() {
        var index = PolaroidIndexLogic.add(to: .empty, record: older)
        index = PolaroidIndexLogic.add(to: index, record: newer)
        index = PolaroidIndexLogic.updateCaption(
            in: index,
            id: "a",
            caption: "rewritten",
            captionMode: .custom,
            captionFont: .typewriter,
            captionFontSize: .large,
            captionHighlight: false,
            captionLetterCase: .sentence,
            dateFormat: .short
        )
        let updated = PolaroidIndexLogic.find(in: index, id: "a")
        XCTAssertEqual(updated?.caption, "rewritten")
        XCTAssertEqual(updated?.captionFont, .typewriter)
        XCTAssertEqual(updated?.captionFontSize, .large)
        XCTAssertEqual(updated?.captionHighlight, false)
        XCTAssertEqual(updated?.captionLetterCase, .sentence)
        XCTAssertEqual(updated?.dateFormat, .short)
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "b")?.caption, "new")
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "b")?.backNote, "a longer note on the reverse")
    }

    func testUpdateBackNote() {
        var index = PolaroidIndexLogic.add(to: .empty, record: older)
        index = PolaroidIndexLogic.updateBackNote(
            in: index,
            id: "a",
            backNote: "  hello back  ",
            backFont: .script,
            backFontSize: .large,
            backLetterCase: .sentence
        )
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backNote, "hello back")
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backFont, .script)
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backFontSize, .large)
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backLetterCase, .sentence)
        index = PolaroidIndexLogic.updateBackNote(in: index, id: "a", backNote: "   ", backFont: .typewriter)
        XCTAssertNil(PolaroidIndexLogic.find(in: index, id: "a")?.backNote)
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backFont, .typewriter)
    }

    func testSerializeParseRoundTrip() {
        var index = PolaroidIndexLogic.add(to: .empty, record: older)
        index = PolaroidIndexLogic.add(to: index, record: newer)
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(index))
        XCTAssertEqual(again.items.map(\.id), ["b", "a"])
        XCTAssertEqual(again.items[0].captionFont, .script)
        XCTAssertEqual(again.items[0].backNote, "a longer note on the reverse")
        XCTAssertEqual(again.items[1].captionMode, .date)
    }

    func testParseLegacyMissingFontAndHighlight() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","caption":"hi","captionMode":"date"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items.count, 1)
        XCTAssertEqual(index.items[0].captionFont, .serif)
        XCTAssertEqual(index.items[0].captionFontSize, .medium)
        XCTAssertEqual(index.items[0].captionHighlight, true)
        XCTAssertEqual(index.items[0].captionLetterCase, .lowercase)
        XCTAssertEqual(index.items[0].backFont, .script)
        XCTAssertEqual(index.items[0].backFontSize, .medium)
        XCTAssertEqual(index.items[0].backLetterCase, .lowercase)
        XCTAssertEqual(index.items[0].filmStock, .onestep)
        XCTAssertEqual(index.items[0].filmStrength, FilmExpression.legacyDefault, accuracy: 0.0001)
        XCTAssertNil(index.items[0].backNote)
        XCTAssertEqual(index.items[0].dateFormat, .long)
    }

    func testDateFormatRoundTrip() {
        let record = PolaroidRecord(
            id: "fmt",
            createdAt: "2026-08-29T00:00:00.000Z",
            caption: "hi",
            captionMode: .date,
            dateFormat: .iso
        )
        let index = PolaroidIndexLogic.add(to: .empty, record: record)
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(index))
        XCTAssertEqual(again.items[0].dateFormat, .iso)
    }

    func testCaptionLetterCaseRoundTrip() {
        let record = PolaroidRecord(
            id: "case",
            createdAt: "2026-08-29T00:00:00.000Z",
            caption: "Hello",
            captionMode: .custom,
            captionLetterCase: .sentence
        )
        let index = PolaroidIndexLogic.add(to: .empty, record: record)
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(index))
        XCTAssertEqual(again.items[0].captionLetterCase, .sentence)
    }

    func testCanvasAspectMatchesLayout() {
        let layout = FrameGeometry.computeFrameLayout()
        let expected = CGFloat(layout.canvasWidth) / CGFloat(layout.canvasHeight)
        XCTAssertEqual(FrameGeometry.canvasAspect, expected, accuracy: 0.0001)
    }

    func testBackFontRoundTrip() {
        let record = PolaroidRecord(
            id: "z",
            createdAt: "2026-08-29T00:00:00.000Z",
            caption: "hi",
            captionMode: .date,
            backNote: "note",
            backFont: .typewriter,
            backFontSize: .small,
            backLetterCase: .sentence
        )
        let index = PolaroidIndexLogic.add(to: .empty, record: record)
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(index))
        XCTAssertEqual(again.items[0].backFont, .typewriter)
        XCTAssertEqual(again.items[0].backFontSize, .small)
        XCTAssertEqual(again.items[0].backLetterCase, .sentence)
        XCTAssertEqual(again.items[0].backNote, "note")
    }

    func testParseInterimDisplayDateOnly() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","displayDate":"2026-08-29T00:00:00.000Z"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items[0].captionMode, .date)
        XCTAssertNil(index.items[0].backNote)
    }

    func testParseInterimNoteOnly() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","note":"lake day"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items[0].captionMode, .custom)
        XCTAssertEqual(index.items[0].caption, "lake day")
        XCTAssertNil(index.items[0].backNote)
    }

    func testParseInterimDateAndNotePutsNoteOnBack() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","displayDate":"2026-08-29T00:00:00.000Z","note":"lake day"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items[0].captionMode, .date)
        XCTAssertEqual(index.items[0].backNote, "lake day")
    }

    func testParseCorrupt() {
        XCTAssertEqual(PolaroidIndexLogic.parse(nil).items, [])
        XCTAssertEqual(PolaroidIndexLogic.parse("{not json").items, [])
    }

    func testUnknownFilmStockFallsBackToOnestep() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","caption":"hi","captionMode":"date","filmStock":"original-pack"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items.count, 1)
        XCTAssertEqual(index.items[0].id, "x")
        XCTAssertEqual(index.items[0].filmStock, .onestep)
    }

    func testUnknownCaptionFontFallsBack() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","caption":"hi","captionMode":"date","captionFont":"comic"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items.count, 1)
        XCTAssertEqual(index.items[0].captionFont, .serif)
    }

    func testLenientParseKeepsGoodRowsWhenOneIsBroken() {
        // Second item is not an object — whole-index decode fails; lenient path keeps the first.
        let raw = """
        {"version":1,"items":[{"id":"good","createdAt":"2026-08-29T00:00:00.000Z","caption":"hi","captionMode":"date"},42]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items.map(\.id), ["good"])
    }

    func testRecoverMissingRecordsFromDiskFolders() {
        let existing = [
            PolaroidRecord(
                id: "a",
                createdAt: "2026-01-01T00:00:00.000Z",
                caption: "kept",
                captionMode: .custom
            ),
        ]
        let recovered = PolaroidIndexLogic.recoverMissingRecords(
            existing: existing,
            folderIDsWithPNG: [
                (id: "a", createdAt: "2026-01-01T00:00:00.000Z"),
                (id: "orphan", createdAt: "2026-08-29T00:00:00.000Z"),
            ]
        )
        XCTAssertEqual(recovered.map(\.id), ["orphan", "a"])
        XCTAssertEqual(recovered.first?.captionMode, .blank)
        XCTAssertEqual(recovered.first?.filmStock, .onestep)
    }

    func testPrintRouteSources() {
        XCTAssertTrue(PrintRoute.captured(id: "a").openedFromCapture)
        XCTAssertFalse(PrintRoute.saved(id: "a").openedFromCapture)
    }
}
