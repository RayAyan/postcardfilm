import UIKit
import XCTest
@testable import PostcardFilm

/// Hard rule: film debug picker is DEBUG + test-branch only.
/// See `.cursor/rules/film-debug-picker.mdc`.
final class FilmDebugPickerTests: XCTestCase {
    func testFilmDebugPickerSourceIsDebugGated() throws {
        let source = try String(contentsOf: filmDebugPickerURL, encoding: .utf8)
        XCTAssertTrue(
            source.hasPrefix("#if DEBUG"),
            "FilmDebugPicker.swift must compile only under #if DEBUG"
        )
        XCTAssertTrue(
            source.contains("BuildChannel.isTestBranch"),
            "Picker availability must require BuildChannel.isTestBranch"
        )
        XCTAssertTrue(
            source.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("#endif"),
            "FilmDebugPicker.swift must close the DEBUG gate"
        )
    }

    func testHomeViewWiresDebugOverridesUnderDebugGate() throws {
        let source = try String(contentsOf: homeViewURL, encoding: .utf8)
        XCTAssertTrue(source.contains("#if DEBUG"), "Home must gate film debug UI")
        XCTAssertTrue(source.contains("FilmDebugSession"), "Home must host FilmDebugSession")
        XCTAssertTrue(source.contains("FilmDebugSession.isAvailable"), "Chip must check isAvailable")
        XCTAssertTrue(source.contains("overrideStock"), "Capture must pass overrideStock")
        XCTAssertTrue(source.contains("overrideStrength"), "Capture must pass overrideStrength")
    }

    func testProjectYMLRunsBuildChannelScript() throws {
        let projectYML = try String(
            contentsOf: sourcesRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        XCTAssertTrue(
            projectYML.contains("generate-build-channel.sh"),
            "App target must regenerate BuildChannel before compile"
        )
        XCTAssertTrue(
            projectYML.contains("Generate BuildChannel"),
            "Pre-build script phase must be named"
        )
    }

    func testGenerateBuildChannelScriptGatesOnTestBranch() throws {
        let scriptURL = sourcesRoot.appendingPathComponent("Scripts/generate-build-channel.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        XCTAssertTrue(
            script.contains("BUILD_CHANNEL_BRANCH"),
            "Script must allow branch override for local/CI checks"
        )
        XCTAssertTrue(
            script.contains("[[ \"${BRANCH}\" == \"test\" ]]"),
            "isTestBranch must be true only for git branch test"
        )
        XCTAssertTrue(
            script.contains("BuildChannel.generated.swift"),
            "Script must write BuildChannel.generated.swift"
        )
        let generated = try String(
            contentsOf: sourcesRoot.appendingPathComponent("PostcardFilm/Support/BuildChannel.generated.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(generated.contains("static let gitBranch: String"))
        XCTAssertTrue(generated.contains("static let isTestBranch: Bool"))
    }

    func testExpressionBandMidpointsMatchPlan() {
        #if DEBUG
        XCTAssertEqual(FilmDebugSession.ExpressionBand.gentle.strength, 0.52, accuracy: 0.0001)
        XCTAssertEqual(FilmDebugSession.ExpressionBand.medium.strength, 0.72, accuracy: 0.0001)
        XCTAssertEqual(FilmDebugSession.ExpressionBand.bold.strength, 0.91, accuracy: 0.0001)
        #endif
    }

    @MainActor
    func testManualOverridesNilWhenAuto() {
        #if DEBUG
        let session = FilmDebugSession()
        session.mode = .auto
        session.stock = .m6
        session.band = .bold
        // When BuildChannel.isTestBranch is true (test branch builds), Auto still yields nil.
        XCTAssertNil(session.overrideStock)
        XCTAssertNil(session.overrideStrength)
        #endif
    }

    @MainActor
    func testManualOverridesStayNilWhileMenuDisabled() {
        #if DEBUG
        // menuEnabled is hard-off — chip and overrides must stay dormant.
        XCTAssertFalse(FilmDebugSession.isAvailable)
        let session = FilmDebugSession()
        session.mode = .manual
        session.stock = .natura
        session.band = .gentle
        XCTAssertNil(session.overrideStock)
        XCTAssertNil(session.overrideStrength)
        #endif
    }

    func testProcessCaptureHonorsForcedStockAndStrength() throws {
        let image = makeTestImage()
        let result = try PolaroidPipeline.processCapture(
            image: image,
            captionMode: .blank,
            dateFormat: .long,
            customText: "",
            filmStock: .mini9,
            filmStrength: 0.72,
            serendipitySeed: "debug-force-seed"
        )
        XCTAssertEqual(result.filmStock, .mini9)
        XCTAssertEqual(result.filmStrength, 0.72, accuracy: 0.0001)
    }

    private func makeTestImage() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private var filmDebugPickerURL: URL {
        sourcesRoot.appendingPathComponent("PostcardFilm/Features/Home/FilmDebugPicker.swift")
    }

    private var homeViewURL: URL {
        sourcesRoot.appendingPathComponent("PostcardFilm/Features/Home/HomeView.swift")
    }

    private var sourcesRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            let project = url.appendingPathComponent("project.yml")
            let app = url.appendingPathComponent("PostcardFilm")
            if FileManager.default.fileExists(atPath: project.path),
               FileManager.default.fileExists(atPath: app.path)
            {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
