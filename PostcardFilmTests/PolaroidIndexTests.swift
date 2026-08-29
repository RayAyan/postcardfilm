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
            captionHighlight: false
        )
        let updated = PolaroidIndexLogic.find(in: index, id: "a")
        XCTAssertEqual(updated?.caption, "rewritten")
        XCTAssertEqual(updated?.captionFont, .typewriter)
        XCTAssertEqual(updated?.captionHighlight, false)
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "b")?.caption, "new")
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "b")?.backNote, "a longer note on the reverse")
    }

    func testUpdateBackNote() {
        var index = PolaroidIndexLogic.add(to: .empty, record: older)
        index = PolaroidIndexLogic.updateBackNote(in: index, id: "a", backNote: "  hello back  ", backFont: .script)
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backNote, "hello back")
        XCTAssertEqual(PolaroidIndexLogic.find(in: index, id: "a")?.backFont, .script)
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
        XCTAssertEqual(index.items[0].captionHighlight, true)
        XCTAssertEqual(index.items[0].backFont, .script)
        XCTAssertNil(index.items[0].backNote)
    }

    func testBackFontRoundTrip() {
        let record = PolaroidRecord(
            id: "z",
            createdAt: "2026-08-29T00:00:00.000Z",
            caption: "hi",
            captionMode: .date,
            backNote: "note",
            backFont: .typewriter
        )
        let index = PolaroidIndexLogic.add(to: .empty, record: record)
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(index))
        XCTAssertEqual(again.items[0].backFont, .typewriter)
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

    func testPrintRouteSources() {
        XCTAssertTrue(PrintRoute.captured(id: "a").openedFromCapture)
        XCTAssertFalse(PrintRoute.saved(id: "a").openedFromCapture)
    }
}
