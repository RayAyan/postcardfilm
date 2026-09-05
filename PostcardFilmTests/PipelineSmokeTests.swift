import UIKit
import XCTest
@testable import PostcardFilm

final class PipelineSmokeTests: XCTestCase {
    func testProcessCaptureProducesPNGAndJPEG() throws {
        let image = makeTestImage()
        let result = try PolaroidPipeline.processCapture(
            image: image,
            captionMode: .date,
            dateFormat: .long,
            customText: "",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            filmStock: .onestep
        )
        XCTAssertFalse(result.originalJPEG.isEmpty)
        XCTAssertFalse(result.polaroidPNG.isEmpty)
        XCTAssertFalse(result.caption.isEmpty)
        XCTAssertEqual(result.captionMode, .date)
        XCTAssertEqual(result.filmStock, .onestep)
        XCTAssertEqual(result.filmStrength, 1.0, accuracy: 0.0001)
        XCTAssertNotNil(UIImage(data: result.polaroidPNG))
        XCTAssertNotNil(UIImage(data: result.originalJPEG))
    }

    func testProcessCaptureWithCustomFontAndHighlight() throws {
        let image = makeTestImage()
        let result = try PolaroidPipeline.processCapture(
            image: image,
            captionMode: .custom,
            dateFormat: .long,
            customText: "hello film",
            captionFont: .script,
            captionHighlight: true,
            filmStock: .natura
        )
        XCTAssertEqual(result.caption, "hello film")
        XCTAssertEqual(result.captionMode, .custom)
        XCTAssertEqual(result.filmStock, .natura)
        XCTAssertGreaterThanOrEqual(result.filmStrength, FilmExpression.minimumStrength)
        XCTAssertLessThanOrEqual(result.filmStrength, FilmExpression.maximumStrength)
        let png = try XCTUnwrap(UIImage(data: result.polaroidPNG))
        let layout = FrameGeometry.computeFrameLayout()
        XCTAssertEqual(Int(png.size.width), layout.canvasWidth)
        XCTAssertEqual(Int(png.size.height), layout.canvasHeight)
    }

    func testReburnCaptionChangesText() throws {
        let image = makeTestImage()
        let first = try PolaroidPipeline.processCapture(
            image: image,
            captionMode: .blank,
            dateFormat: .long,
            customText: "",
            captionHighlight: false,
            filmStock: .sun660
        )
        let rebaked = try PolaroidPipeline.reburnCaption(
            squareJPEG: first.originalJPEG,
            captionMode: .custom,
            dateFormat: .long,
            customText: "rewritten",
            captionFont: .typewriter,
            captionHighlight: true,
            date: Date(),
            filmStock: first.filmStock,
            filmStrength: first.filmStrength
        )
        XCTAssertEqual(rebaked.caption, "rewritten")
        XCTAssertFalse(rebaked.png.isEmpty)
        XCTAssertEqual(first.filmStock, .sun660)
        XCTAssertGreaterThanOrEqual(first.filmStrength, FilmExpression.minimumStrength)
    }

    func testRenderBackMatchesFrontCanvas() throws {
        let back = try PolaroidPipeline.renderBack(
            note: "the water was freezing and we stayed anyway.",
            font: .script
        )
        let layout = FrameGeometry.computeFrameLayout()
        XCTAssertEqual(Int(back.size.width), layout.canvasWidth)
        XCTAssertEqual(Int(back.size.height), layout.canvasHeight)
    }

    func testRenderBackWithTypewriterAndBlank() throws {
        let back = try PolaroidPipeline.renderBack(
            note: "hello",
            font: .typewriter,
            fontSize: .large,
            letterCase: .sentence
        )
        let blank = try PolaroidPipeline.renderBlankBack()
        let layout = FrameGeometry.computeFrameLayout()
        XCTAssertEqual(Int(back.size.width), layout.canvasWidth)
        XCTAssertEqual(Int(blank.size.width), layout.canvasWidth)
        XCTAssertEqual(Int(blank.size.height), layout.canvasHeight)
    }

    func testRenderBackAppliesSentenceCaseOnce() throws {
        let sentence = try PolaroidPipeline.renderBack(
            note: "hello world",
            font: .serif,
            letterCase: .sentence
        )
        let lower = try PolaroidPipeline.renderBack(
            note: "hello world",
            font: .serif,
            letterCase: .lowercase
        )
        // Different letter-case burns must produce different PNG bytes.
        XCTAssertNotEqual(sentence.pngData(), lower.pngData())
        XCTAssertEqual(DateCaseStyle.sentence.apply("hello world"), "Hello World")
    }

    #if targetEnvironment(simulator)
    func testSimulatorPlaceholderIsSquareCroppable() throws {
        let image = CameraController.simulatorPlaceholderImage()
        let square = try PolaroidPipeline.squareCrop(image: image, side: FrameConstants.imageSide)
        XCTAssertEqual(Int(square.size.width), FrameConstants.imageSide)
        XCTAssertEqual(Int(square.size.height), FrameConstants.imageSide)
    }
    #endif

    private func makeTestImage(width: Int = 320, height: Int = 320) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 20, y: 20, width: 80, height: 80))
        }
    }
}
