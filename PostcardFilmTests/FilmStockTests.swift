import UIKit
import XCTest
@testable import PostcardFilm

final class FilmStockTests: XCTestCase {
    func testPackHasFiveStocks() {
        XCTAssertEqual(FilmStock.allCases.count, 5)
        XCTAssertEqual(
            Set(FilmStock.allCases.map(\.rawValue)),
            Set(["onestep", "sun660", "mini9", "natura", "m6"])
        )
    }

    func testDrawReturnsOnlyPackMembers() {
        var rng = SeededGenerator(seed: 42)
        var seen = Set<FilmStock>()
        for _ in 0 ..< 40 {
            let stock = FilmStock.draw(using: &rng)
            XCTAssertTrue(FilmStock.allCases.contains(stock))
            seen.insert(stock)
        }
        XCTAssertGreaterThan(seen.count, 1)
    }

    func testMissingFilmStockDecodesAsOnestep() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","caption":"hi","captionMode":"date"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items[0].filmStock, .onestep)
    }

    func testFilmStockRoundTrip() {
        let record = PolaroidRecord(
            id: "z",
            createdAt: "2026-08-29T00:00:00.000Z",
            caption: "hi",
            captionMode: .date,
            filmStock: .mini9
        )
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(PolaroidIndexLogic.add(to: .empty, record: record)))
        XCTAssertEqual(again.items[0].filmStock, .mini9)
    }

    func testOnestepRecipeMatchesHouseGrade() {
        let recipe = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        XCTAssertEqual(FilmStock.onestep.cameraName, "Original")
        XCTAssertEqual(recipe.exposureEV, Grade.exposureEV())
        let house = Grade.colorMatrix()
        XCTAssertEqual(recipe.colorMatrix.r.0, house.r.0, accuracy: 0.0001)
        XCTAssertEqual(recipe.colorMatrix.bias.0, house.bias.0, accuracy: 0.0001)
        XCTAssertEqual(recipe.shadowSaturation.amount, Grade.shadowSaturation().amount, accuracy: 0.0001)
        XCTAssertEqual(recipe.contrast, 1.0, accuracy: 0.0001)
        XCTAssertEqual(recipe.saturation, 1.0, accuracy: 0.0001)
        XCTAssertEqual(recipe.highlightAmount, 1.0, accuracy: 0.0001)
        XCTAssertEqual(recipe.shadowAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(recipe.leakAlpha, 0.55, accuracy: 0.001)
        XCTAssertEqual(recipe.bloomAlpha, 0.7, accuracy: 0.001)
        XCTAssertEqual(recipe.flashAlpha, 0, accuracy: 0.001)
        XCTAssertEqual(recipe.grainAmount, 0, accuracy: 0.001)
        XCTAssertEqual(recipe.edgeBurnAmount, 0, accuracy: 0.001)
    }

    func testOnestepWarmMidGrayBias() {
        let recipe = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        // House matrix warms: R bias >= B bias, and R diagonal pulls warm.
        XCTAssertGreaterThanOrEqual(recipe.colorMatrix.bias.0, recipe.colorMatrix.bias.2)
    }

    func testDaylightToneRoles() {
        let onestep = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        let sun = FilmStock.sun660.recipe(meanLuma: 0.5, centerBias: 0)
        let mini = FilmStock.mini9.recipe(meanLuma: 0.5, centerBias: 0)
        let natura = FilmStock.natura.recipe(meanLuma: 0.5, centerBias: 0)
        let m6 = FilmStock.m6.recipe(meanLuma: 0.5, centerBias: 0)

        XCTAssertGreaterThan(sun.exposureEV, onestep.exposureEV - 0.05)
        XCTAssertLessThan(sun.flashAlpha, 0.18)
        XCTAssertGreaterThan(sun.flashAlpha, 0.08)
        XCTAssertLessThan(sun.vignetteStrength, 1.35)
        XCTAssertGreaterThan(sun.vignetteStrength, 1.10)

        XCTAssertLessThan(mini.contrast, 1.10)
        XCTAssertGreaterThan(mini.contrast, 1.03)
        XCTAssertLessThan(mini.shadowAmount, -0.03)

        XCTAssertGreaterThan(natura.exposureEV, onestep.exposureEV)
        XCTAssertLessThan(natura.contrast, 0.95)
        XCTAssertGreaterThan(natura.shadowAmount, 0.06)

        XCTAssertLessThan(m6.contrast, 1.10)
        XCTAssertGreaterThan(m6.contrast, 1.03)
        XCTAssertLessThan(m6.saturation, 1.0)
        XCTAssertEqual(m6.leakAlpha, 0, accuracy: 0.001)
        XCTAssertGreaterThan(m6.blurRadius, 0.40)
    }

    func testMini9CoolerThanOnestep() {
        let onestep = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        let mini = FilmStock.mini9.recipe(meanLuma: 0.5, centerBias: 0)
        XCTAssertGreaterThan(mini.colorMatrix.b.2, onestep.colorMatrix.b.2)
        XCTAssertGreaterThan(mini.colorMatrix.bias.2, onestep.colorMatrix.bias.2)
        XCTAssertEqual(mini.leakAlpha, 0, accuracy: 0.001)
    }

    func testNaturaGreenerShadowsThanOnestep() {
        let onestep = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        let natura = FilmStock.natura.recipe(meanLuma: 0.5, centerBias: 0)
        XCTAssertGreaterThan(natura.colorMatrix.g.1, onestep.colorMatrix.g.1)
        XCTAssertLessThan(natura.colorMatrix.b.2, onestep.colorMatrix.b.2)
    }

    func testM6NoLeakLowerSat() {
        let onestep = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        let m6 = FilmStock.m6.recipe(meanLuma: 0.5, centerBias: 0)
        XCTAssertEqual(m6.leakAlpha, 0, accuracy: 0.001)
        XCTAssertLessThan(m6.shadowSaturation.amount, onestep.shadowSaturation.amount)
        XCTAssertLessThan(m6.exposureEV, onestep.exposureEV)
    }

    func testSun660FlashOnDarkUnflashedFrame() {
        let recipe = FilmStock.sun660.recipe(meanLuma: 0.12, centerBias: 0.02)
        XCTAssertGreaterThan(recipe.flashAlpha, 0.12)
        XCTAssertLessThan(recipe.flashAlpha, 0.24)
        XCTAssertGreaterThan(recipe.flashCenterLift, 0.05)
        XCTAssertEqual(recipe.leakAlpha, 0, accuracy: 0.001)
    }

    func testSun660DoesNotDoubleBlowWhenCenterAlreadyLit() {
        let unflashed = FilmStock.sun660.recipe(meanLuma: 0.12, centerBias: 0.02)
        let flashed = FilmStock.sun660.recipe(meanLuma: 0.12, centerBias: 0.22)
        XCTAssertGreaterThan(unflashed.flashCenterLift, flashed.flashCenterLift)
        XCTAssertGreaterThan(unflashed.flashAlpha, flashed.flashAlpha)
        XCTAssertEqual(flashed.flashCenterLift, 0, accuracy: 0.001)
    }

    func testNaturaOpensAtNight() {
        let day = FilmStock.natura.recipe(meanLuma: 0.55, centerBias: 0)
        let night = FilmStock.natura.recipe(meanLuma: 0.12, centerBias: 0)
        XCTAssertGreaterThan(night.exposureEV, day.exposureEV)
        XCTAssertGreaterThan(night.colorMatrix.g.1, day.colorMatrix.g.1)
    }

    func testSerendipityLeavesOriginalUntouched() {
        let base = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        let varied = FilmSerendipity.vary(base, seed: "abc", stock: .onestep)
        XCTAssertEqual(varied, base)
    }

    func testSerendipityIsDeterministicForSeed() {
        let base = FilmStock.mini9.recipe(meanLuma: 0.5, centerBias: 0)
        let a = FilmSerendipity.vary(base, seed: "print-1", stock: .mini9)
        let b = FilmSerendipity.vary(base, seed: "print-1", stock: .mini9)
        let c = FilmSerendipity.vary(base, seed: "print-2", stock: .mini9)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a.grainAmount, c.grainAmount, accuracy: 0.00001)
    }

    func testExpressionLeavesOriginalUntouched() {
        let base = FilmStock.onestep.recipe(meanLuma: 0.5, centerBias: 0)
        XCTAssertEqual(FilmExpression.resolve(seed: "any", stock: .onestep), 1.0, accuracy: 0.0001)
        XCTAssertEqual(FilmExpression.apply(base, strength: 0.5, stock: .onestep), base)
    }

    func testExpressionResolveIsDeterministicAndBounded() {
        let a = FilmExpression.resolve(seed: "print-a", stock: .mini9)
        let b = FilmExpression.resolve(seed: "print-a", stock: .mini9)
        let c = FilmExpression.resolve(seed: "print-b", stock: .mini9)
        XCTAssertEqual(a, b, accuracy: 0.0000001)
        XCTAssertGreaterThanOrEqual(a, FilmExpression.minimumStrength)
        XCTAssertLessThanOrEqual(a, FilmExpression.maximumStrength)
        XCTAssertGreaterThanOrEqual(c, FilmExpression.minimumStrength)
        XCTAssertLessThanOrEqual(c, FilmExpression.maximumStrength)
    }

    func testExpressionDistributionIsWeightedGentle() {
        var gentle = 0
        var medium = 0
        var bold = 0
        for i in 0 ..< 200 {
            let strength = FilmExpression.resolve(seed: "dist-\(i)", stock: .natura)
            if strength < 0.62 {
                gentle += 1
            } else if strength < 0.82 {
                medium += 1
            } else {
                bold += 1
            }
        }
        XCTAssertGreaterThan(gentle, medium)
        XCTAssertGreaterThan(medium, bold)
        XCTAssertGreaterThan(gentle, 100)
        XCTAssertLessThan(bold, 40)
    }

    func testGentleExpressionSoftensHarshKnobs() {
        let base = FilmStock.mini9.recipe(meanLuma: 0.5, centerBias: 0)
        let gentle = FilmExpression.apply(base, strength: FilmExpression.minimumStrength, stock: .mini9)
        let bold = FilmExpression.apply(base, strength: 1.0, stock: .mini9)
        XCTAssertLessThan(abs(gentle.contrast - 1.0), abs(bold.contrast - 1.0))
        XCTAssertLessThan(abs(gentle.shadowAmount), abs(bold.shadowAmount))
        XCTAssertLessThan(gentle.grainAmount, bold.grainAmount)
        XCTAssertLessThan(gentle.edgeBurnAmount, bold.edgeBurnAmount)
        // Full strength keeps the stock recipe before serendipity.
        XCTAssertEqual(bold.contrast, base.contrast, accuracy: 0.0001)
        XCTAssertEqual(bold.grainAmount, base.grainAmount, accuracy: 0.0001)
    }

    func testGentleExpressionKeepsStockColorIdentity() {
        let base = FilmStock.natura.recipe(meanLuma: 0.5, centerBias: 0)
        let house = FilmRecipe.onestep
        let gentle = FilmExpression.apply(base, strength: FilmExpression.minimumStrength, stock: .natura)
        // Green diagonal should stay closer to Natura than to Original even when gentle.
        let towardStock = abs(gentle.colorMatrix.g.1 - base.colorMatrix.g.1)
        let towardHouse = abs(gentle.colorMatrix.g.1 - house.colorMatrix.g.1)
        XCTAssertLessThan(towardStock, towardHouse)
        XCTAssertGreaterThan(gentle.colorMatrix.g.1, house.colorMatrix.g.1)
    }

    func testSerendipityJitterScalesWithStrength() {
        let base = FilmStock.m6.recipe(meanLuma: 0.5, centerBias: 0)
        let soft = FilmSerendipity.vary(base, seed: "scale-1", stock: .m6, strength: 0.45)
        let hard = FilmSerendipity.vary(base, seed: "scale-1", stock: .m6, strength: 1.0)
        let softDelta = abs(Double(soft.vignetteStrength - base.vignetteStrength))
        let hardDelta = abs(Double(hard.vignetteStrength - base.vignetteStrength))
        XCTAssertLessThanOrEqual(softDelta, hardDelta + 0.0001)
    }

    func testReburnKeepsInjectedStockAndStrength() throws {
        let image = makeFlatImage(color: UIColor(white: 0.45, alpha: 1), size: 320)
        let first = try PolaroidPipeline.processCapture(
            image: image,
            captionMode: .blank,
            dateFormat: .long,
            customText: "",
            filmStock: .m6,
            filmStrength: 0.55,
            serendipitySeed: "reburn-test"
        )
        XCTAssertEqual(first.filmStock, .m6)
        XCTAssertEqual(first.filmStrength, 0.55, accuracy: 0.0001)
        let rebaked = try PolaroidPipeline.reburnCaption(
            squareJPEG: first.originalJPEG,
            captionMode: .custom,
            dateFormat: .long,
            customText: "kept",
            date: Date(),
            filmStock: .m6,
            filmStrength: first.filmStrength,
            serendipitySeed: "reburn-test"
        )
        XCTAssertEqual(rebaked.caption, "kept")
        XCTAssertFalse(rebaked.png.isEmpty)
        // Same emulsion + strength + seed → identical PNG bytes on reburn of same caption path
        // is hard to assert without re-rendering; at least strength round-trips through Result.
        let again = try PolaroidPipeline.processCapture(
            image: image,
            captionMode: .custom,
            dateFormat: .long,
            customText: "kept",
            filmStock: .m6,
            filmStrength: 0.55,
            serendipitySeed: "reburn-test"
        )
        XCTAssertEqual(again.polaroidPNG, rebaked.png)
    }

    func testMissingFilmStrengthDecodesAsLegacyFull() {
        let raw = """
        {"version":1,"items":[{"id":"x","createdAt":"2026-08-29T00:00:00.000Z","caption":"hi","captionMode":"date","filmStock":"mini9"}]}
        """
        let index = PolaroidIndexLogic.parse(raw)
        XCTAssertEqual(index.items[0].filmStock, .mini9)
        XCTAssertEqual(index.items[0].filmStrength, FilmExpression.legacyDefault, accuracy: 0.0001)
    }

    func testFilmStrengthRoundTrip() {
        let record = PolaroidRecord(
            id: "z",
            createdAt: "2026-08-29T00:00:00.000Z",
            caption: "hi",
            captionMode: .date,
            filmStock: .sun660,
            filmStrength: 0.71
        )
        let again = PolaroidIndexLogic.parse(PolaroidIndexLogic.serialize(PolaroidIndexLogic.add(to: .empty, record: record)))
        XCTAssertEqual(again.items[0].filmStock, .sun660)
        XCTAssertEqual(again.items[0].filmStrength, 0.71, accuracy: 0.0001)
    }

    func testGradedDistinctnessOnMidGray() throws {
        let image = makeFlatImage(color: UIColor(white: 0.5, alpha: 1), size: 256)
        let onestep = try sampleCenter(afterGrading: image, stock: .onestep)
        let mini = try sampleCenter(afterGrading: image, stock: .mini9)
        let natura = try sampleCenter(afterGrading: image, stock: .natura)

        XCTAssertGreaterThan(onestep.r, onestep.b, "onestep should warm mid gray")
        XCTAssertGreaterThan(mini.b, onestep.b - 0.01, "mini9 should read cooler / bluer")
        XCTAssertGreaterThan(natura.g, onestep.g - 0.02, "natura should lift green relative to onestep")
    }

    func testPixelDeltaVsOriginalOnMidGray() throws {
        let image = makeFlatImage(color: UIColor(white: 0.5, alpha: 1), size: 256)
        let original = try sampleCenter(afterGrading: image, stock: .onestep)
        for stock in [FilmStock.sun660, .mini9, .natura, .m6] {
            let sample = try sampleCenter(afterGrading: image, stock: stock)
            let delta = meanAbsDelta(original, sample)
            XCTAssertGreaterThanOrEqual(
                delta,
                0.025,
                "\(stock.rawValue) mid-gray delta \(delta) should be >= 0.025 vs Original"
            )
        }
    }

    func testPixelDeltaVsOriginalOnGradient() throws {
        let image = makeGradientImage(size: 256)
        let original = try sampleCenter(afterGrading: image, stock: .onestep)
        for stock in [FilmStock.sun660, .mini9, .natura, .m6] {
            let sample = try sampleCenter(afterGrading: image, stock: stock)
            let delta = meanAbsDelta(original, sample)
            XCTAssertGreaterThanOrEqual(
                delta,
                0.025,
                "\(stock.rawValue) gradient delta \(delta) should be >= 0.025 vs Original"
            )
        }
    }

    func testMini9BlacksDarkerThanNatura() throws {
        let black = makeFlatImage(color: UIColor(white: 0.08, alpha: 1), size: 256)
        let mini = try sampleCenter(afterGrading: black, stock: .mini9)
        let natura = try sampleCenter(afterGrading: black, stock: .natura)
        let miniLuma = luma(mini)
        let naturaLuma = luma(natura)
        XCTAssertLessThan(miniLuma, naturaLuma, "mini9 should crush blacks vs milky natura")
    }

    func testNaturaMidBrighterThanOriginal() throws {
        let mid = makeFlatImage(color: UIColor(white: 0.45, alpha: 1), size: 256)
        let original = try sampleCenter(afterGrading: mid, stock: .onestep)
        let natura = try sampleCenter(afterGrading: mid, stock: .natura)
        XCTAssertGreaterThan(luma(natura), luma(original))
    }

    func testM6ContrastSpanGreaterThanNatura() throws {
        let black = makeFlatImage(color: UIColor(white: 0.05, alpha: 1), size: 128)
        let white = makeFlatImage(color: UIColor(white: 0.95, alpha: 1), size: 128)
        let m6Black = try sampleCenter(afterGrading: black, stock: .m6)
        let m6White = try sampleCenter(afterGrading: white, stock: .m6)
        let naturaBlack = try sampleCenter(afterGrading: black, stock: .natura)
        let naturaWhite = try sampleCenter(afterGrading: white, stock: .natura)
        let m6Span = luma(m6White) - luma(m6Black)
        let naturaSpan = luma(naturaWhite) - luma(naturaBlack)
        XCTAssertGreaterThan(m6Span, naturaSpan)
    }

    func testSun660CenterBrighterThanEdgeOnDarkFrame() throws {
        let image = makeCenterLitDarkFrame(size: 256)
        // Dark overall, low center bias so flash fill engages.
        let graded = try PolaroidPipeline.applyGrade(
            to: image,
            recipe: FilmStock.sun660.recipe(meanLuma: 0.15, centerBias: 0.02)
        )
        let center = try samplePixel(graded, u: 0.5, v: 0.42)
        let edge = try samplePixel(graded, u: 0.08, v: 0.08)
        XCTAssertGreaterThan(luma(center), luma(edge))
    }

    // MARK: - Helpers

    private func luma(_ c: (r: Double, g: Double, b: Double)) -> Double {
        0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    private func meanAbsDelta(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double)
    ) -> Double {
        (abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b)) / 3
    }

    private func makeFlatImage(color: UIColor, size: Int) -> UIImage {
        let s = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: s)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: s))
        }
    }

    private func makeGradientImage(size: Int) -> UIImage {
        let s = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: s)
        return renderer.image { ctx in
            let colors = [UIColor.black.cgColor, UIColor.white.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
                return
            }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: s.width, y: s.height),
                options: []
            )
        }
    }

    private func makeCenterLitDarkFrame(size: Int) -> UIImage {
        let s = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: s)
        return renderer.image { ctx in
            UIColor(white: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: s))
            UIColor(white: 0.22, alpha: 1).setFill()
            let inset = CGFloat(size) * 0.28
            ctx.cgContext.fillEllipse(in: CGRect(
                x: inset,
                y: inset,
                width: CGFloat(size) - inset * 2,
                height: CGFloat(size) - inset * 2
            ))
        }
    }

    private func sampleCenter(afterGrading image: UIImage, stock: FilmStock) throws -> (r: Double, g: Double, b: Double) {
        let scene = FilmScene.measure(image)
        let recipe = stock.recipe(meanLuma: scene.meanLuma, centerBias: scene.centerBias)
        let graded = try PolaroidPipeline.applyGrade(to: image, recipe: recipe)
        return try samplePixel(graded, u: 0.5, v: 0.5)
    }

    private func samplePixel(_ image: UIImage, u: CGFloat, v: CGFloat) throws -> (r: Double, g: Double, b: Double) {
        guard let cg = image.cgImage else { throw PipelineError.decodeFailed }
        let x = min(cg.width - 1, max(0, Int(CGFloat(cg.width) * u)))
        let y = min(cg.height - 1, max(0, Int(CGFloat(cg.height) * v)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PipelineError.decodeFailed
        }
        ctx.draw(cg, in: CGRect(x: -x, y: -y, width: cg.width, height: cg.height))
        return (Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255)
    }
}

/// Deterministic RNG for draw() coverage.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 636_413_622_384_679_3005 &+ 1
        return state
    }
}
