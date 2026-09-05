import XCTest
@testable import PostcardFilm

/// Hard rule: gallery survives every binary swap until uninstall.
/// See `.cursor/rules/gallery-persistence.mdc`.
final class GalleryPersistenceTests: XCTestCase {
    func testScreenshotHarnessNeverRemovesPolaroidsRoot() throws {
        let source = try String(contentsOf: harnessSourceURL, encoding: .utf8)
        XCTAssertTrue(
            source.contains("#if DEBUG && targetEnvironment(simulator)"),
            "Harness must compile only for Simulator DEBUG builds"
        )
        XCTAssertFalse(
            source.contains("removeItem(at: root)"),
            "Must never FileManager.removeItem the polaroids root"
        )
        XCTAssertTrue(
            source.contains("mergingScreenshotSeeds"),
            "Seed must merge into the index, not replace real prints"
        )
        XCTAssertTrue(
            source.contains("removeSeedFolders"),
            "Only seed-* folders may be refreshed"
        )
    }

    func testPolaroidStoreNeverRemovesPolaroidsRoot() throws {
        let source = try String(contentsOf: storeSourceURL, encoding: .utf8)
        XCTAssertFalse(
            source.contains("removeItem(at: rootURL)"),
            "Store must never removeItem the polaroids root"
        )
        XCTAssertTrue(
            source.contains("removeItem(at: dir)"),
            "Per-print delete after user confirm remains allowed"
        )
    }

    func testMergingScreenshotSeedsKeepsUUIDRecords() {
        let real = PolaroidRecord(
            id: "A9AE02AB-3087-4CE4-BE1B-0AD7B8462C6B",
            createdAt: "2026-09-05T12:00:00.000Z",
            caption: "kept",
            captionMode: .custom
        )
        let oldSeed = PolaroidRecord(
            id: "seed-00",
            createdAt: "2026-01-01T00:00:00.000Z",
            caption: "old seed",
            captionMode: .custom
        )
        let newSeed = PolaroidRecord(
            id: "seed-00",
            createdAt: "2026-09-05T13:00:00.000Z",
            caption: "Kananaskis Lake",
            captionMode: .custom
        )
        let merged = PolaroidIndexLogic.mergingScreenshotSeeds(
            existing: [real, oldSeed],
            seeds: [newSeed]
        )
        XCTAssertEqual(merged.map(\.id), ["seed-00", real.id])
        XCTAssertEqual(PolaroidIndexLogic.find(in: PolaroidIndex(version: 1, items: merged), id: real.id)?.caption, "kept")
        XCTAssertEqual(PolaroidIndexLogic.find(in: PolaroidIndex(version: 1, items: merged), id: "seed-00")?.caption, "Kananaskis Lake")
    }

    func testMergingScreenshotSeedsWithEmptyExisting() {
        let seed = PolaroidRecord(
            id: "seed-01",
            createdAt: "2026-09-05T13:00:00.000Z",
            caption: "only",
            captionMode: .date
        )
        let merged = PolaroidIndexLogic.mergingScreenshotSeeds(existing: [], seeds: [seed])
        XCTAssertEqual(merged.map(\.id), ["seed-01"])
    }

    private var harnessSourceURL: URL {
        sourcesRoot.appendingPathComponent("PostcardFilm/App/ScreenshotHarness.swift")
    }

    private var storeSourceURL: URL {
        sourcesRoot.appendingPathComponent("PostcardFilm/Store/PolaroidStore.swift")
    }

    /// Walk up from the test file to the repo root (contains `PostcardFilm/` + `project.yml`).
    private var sourcesRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            let candidate = url.deletingLastPathComponent()
            let marker = candidate.appendingPathComponent("project.yml")
            if FileManager.default.fileExists(atPath: marker.path) {
                return candidate
            }
            url = candidate
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
