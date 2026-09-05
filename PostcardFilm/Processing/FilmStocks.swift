import CoreGraphics
import Foundation
import UIKit

/// One of five emulsions in the pack. Drawn at shutter; the user never picks or sees the name.
enum FilmStock: String, Codable, CaseIterable, Equatable {
    /// Original — exact 1.0.0 house Polaroid look. Frozen.
    case onestep
    /// Polaroid Sun 660 — soft flash fill, darker edges.
    case sun660
    /// Instax Mini — soft cool Instant.
    case mini9
    /// Fujifilm Natura 1600 — mild milky Fuji.
    case natura
    /// Leica M6 — soft dense rangefinder.
    case m6

    /// Docs / DEBUG only — never shown in product UI.
    var cameraName: String {
        switch self {
        case .onestep: return "Original"
        case .sun660: return "Polaroid Sun 660"
        case .mini9: return "Instax Mini 9"
        case .natura: return "Fujifilm Natura 1600"
        case .m6: return "Leica M6"
        }
    }

    /// Uniform random draw. Repeats allowed — not a cycle.
    static func draw() -> FilmStock {
        var rng = SystemRandomNumberGenerator()
        return draw(using: &rng)
    }

    static func draw(using rng: inout some RandomNumberGenerator) -> FilmStock {
        let all = FilmStock.allCases
        return all[Int.random(in: 0 ..< all.count, using: &rng)]
    }

    /// Scene-aware recipe from the ungraded square crop.
    func recipe(meanLuma: Double, centerBias: Double) -> FilmRecipe {
        let night = FilmScene.nightAmount(meanLuma: meanLuma)
        let alreadyFlashed = centerBias > 0.12
        switch self {
        case .onestep:
            return .onestep
        case .sun660:
            return .sun660(night: night, alreadyFlashed: alreadyFlashed)
        case .mini9:
            return .mini9(night: night)
        case .natura:
            return .natura(night: night)
        case .m6:
            return .m6(night: night)
        }
    }
}

/// How dark the frame is (0 = bright day, 1 = night).
enum FilmScene {
    static func nightAmount(meanLuma: Double) -> Double {
        // Bright day ~0.45+, deep night ~0.12-. Soft ramp in between.
        let t = (0.42 - meanLuma) / 0.30
        return min(1, max(0, t))
    }

    /// Whole-frame mean luma + (center − edge) bias on the ungraded square.
    static func measure(_ image: UIImage) -> (meanLuma: Double, centerBias: Double) {
        let sampleSide = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sampleSide, height: sampleSide))
        let small = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide))
        }
        guard let cg = small.cgImage else { return (0.5, 0) }

        let width = cg.width
        let height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0.5, 0)
        }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        var centerTotal = 0.0
        var edgeTotal = 0.0
        var centerCount = 0
        var edgeCount = 0
        let cx = Double(width) / 2
        let cy = Double(height) / 2
        let centerRadius = Double(min(width, height)) * 0.28
        let edgeInner = Double(min(width, height)) * 0.42

        for y in 0 ..< height {
            for x in 0 ..< width {
                let i = (y * width + x) * bytesPerPixel
                let r = Double(data[i]) / 255
                let g = Double(data[i + 1]) / 255
                let b = Double(data[i + 2]) / 255
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                total += luma
                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= centerRadius {
                    centerTotal += luma
                    centerCount += 1
                } else if dist >= edgeInner {
                    edgeTotal += luma
                    edgeCount += 1
                }
            }
        }

        let pixelCount = Double(width * height)
        let mean = total / pixelCount
        let centerMean = centerCount > 0 ? centerTotal / Double(centerCount) : mean
        let edgeMean = edgeCount > 0 ? edgeTotal / Double(edgeCount) : mean
        return (mean, centerMean - edgeMean)
    }
}

typealias FilmColorMatrix = (
    r: (Double, Double, Double, Double),
    g: (Double, Double, Double, Double),
    b: (Double, Double, Double, Double),
    bias: (Double, Double, Double)
)

/// CI + overlay knobs for one stock at one scene.
struct FilmRecipe: Equatable {
    var exposureEV: Double
    var colorMatrix: FilmColorMatrix
    var shadowSaturation: (amount: Double, maskGamma: Double)
    /// CIColorControls contrast (1.0 = neutral).
    var contrast: Double
    /// CIColorControls saturation (1.0 = neutral).
    var saturation: Double
    /// CIHighlightShadowAdjust highlightAmount.
    var highlightAmount: Double
    /// CIHighlightShadowAdjust shadowAmount (negative crushes, positive lifts).
    var shadowAmount: Double
    var blurRadius: Double
    /// Multiply vignette drawn alpha scale (1 = house default strength).
    var vignetteStrength: CGFloat
    /// Screen light-leak alpha (0 = off).
    var leakAlpha: CGFloat
    /// Screen highlight-bloom alpha (0 = off).
    var bloomAlpha: CGFloat
    /// Soft radial flash fill screen alpha (sun660). 0 = off.
    var flashAlpha: CGFloat
    /// Extra center exposure for sun660 flash fill.
    var flashCenterLift: Double
    /// Soft film grain overlay alpha (0 = none). Original always 0.
    var grainAmount: CGFloat
    /// Soft edge burn strength (0 = none). Original always 0.
    var edgeBurnAmount: CGFloat

    static func == (lhs: FilmRecipe, rhs: FilmRecipe) -> Bool {
        lhs.exposureEV == rhs.exposureEV
            && lhs.blurRadius == rhs.blurRadius
            && lhs.contrast == rhs.contrast
            && lhs.saturation == rhs.saturation
            && lhs.highlightAmount == rhs.highlightAmount
            && lhs.shadowAmount == rhs.shadowAmount
            && lhs.vignetteStrength == rhs.vignetteStrength
            && lhs.leakAlpha == rhs.leakAlpha
            && lhs.bloomAlpha == rhs.bloomAlpha
            && lhs.flashAlpha == rhs.flashAlpha
            && lhs.flashCenterLift == rhs.flashCenterLift
            && lhs.grainAmount == rhs.grainAmount
            && lhs.edgeBurnAmount == rhs.edgeBurnAmount
            && lhs.shadowSaturation.amount == rhs.shadowSaturation.amount
            && lhs.shadowSaturation.maskGamma == rhs.shadowSaturation.maskGamma
            && lhs.colorMatrix.r == rhs.colorMatrix.r
            && lhs.colorMatrix.g == rhs.colorMatrix.g
            && lhs.colorMatrix.b == rhs.colorMatrix.b
            && lhs.colorMatrix.bias == rhs.colorMatrix.bias
    }
}

extension FilmRecipe {
    /// Exact 1.0.0 Original look — frozen. Neutral tone knobs so CI path matches v1.
    static let onestep = FilmRecipe(
        exposureEV: Grade.exposureEV(),
        colorMatrix: Grade.colorMatrix(),
        shadowSaturation: Grade.shadowSaturation(),
        contrast: 1.0,
        saturation: 1.0,
        highlightAmount: 1.0,
        shadowAmount: 0,
        blurRadius: 0.55,
        vignetteStrength: 1,
        leakAlpha: 0.55,
        bloomAlpha: 0.7,
        flashAlpha: 0,
        flashCenterLift: 0,
        grainAmount: 0,
        edgeBurnAmount: 0
    )

    static func sun660(night: Double, alreadyFlashed: Bool) -> FilmRecipe {
        // Flash cousin nearer Original: hint of fill and edges, not a stamp.
        let dayMatrix: FilmColorMatrix = (
            r: (0.90, 0.06, 0.03, 0),
            g: (0.03, 0.92, 0.045, 0),
            b: (0.015, 0.08, 0.94, 0),
            bias: (0.055, 0.055, 0.06)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.88, 0.055, 0.035, 0),
            g: (0.03, 0.915, 0.05, 0),
            b: (0.015, 0.085, 0.95, 0),
            bias: (0.05, 0.05, 0.065)
        )
        let matrix = lerpMatrix(dayMatrix, nightMatrix, t: night)

        let dayEV = 0.40
        let nightEV = alreadyFlashed ? 0.28 : 0.48
        let ev = lerp(dayEV, nightEV, t: night)

        let dayFlash: CGFloat = 0.12
        let nightFlash: CGFloat = alreadyFlashed ? 0.06 : 0.20
        let flash = CGFloat(lerp(Double(dayFlash), Double(nightFlash), t: night))

        let dayLift = alreadyFlashed ? 0.0 : 0.05
        let nightLift = alreadyFlashed ? 0.0 : 0.12
        let lift = lerp(dayLift, nightLift, t: night)

        return FilmRecipe(
            exposureEV: ev,
            colorMatrix: matrix,
            shadowSaturation: (amount: lerp(1.14, 1.12, t: night), maskGamma: 1.48),
            contrast: lerp(1.02, 1.04, t: night),
            saturation: lerp(1.01, 1.00, t: night),
            highlightAmount: lerp(0.96, 0.94, t: night),
            shadowAmount: lerp(-0.02, -0.04, t: night),
            blurRadius: 0.55,
            vignetteStrength: CGFloat(lerp(1.18, 1.28, t: night)),
            leakAlpha: 0,
            bloomAlpha: CGFloat(lerp(0.40, 0.32, t: night)),
            flashAlpha: flash,
            flashCenterLift: lift,
            grainAmount: 0.015,
            edgeBurnAmount: 0.08
        )
    }

    static func mini9(night: Double) -> FilmRecipe {
        // Cool Instant cousin — slight punch, close to house contrast.
        let dayMatrix: FilmColorMatrix = (
            r: (0.90, 0.055, 0.02, 0),
            g: (0.03, 0.90, 0.055, 0),
            b: (0.02, 0.075, 0.96, 0),
            bias: (0.05, 0.05, 0.052)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.88, 0.05, 0.02, 0),
            g: (0.03, 0.89, 0.06, 0),
            b: (0.02, 0.08, 0.97, 0),
            bias: (0.045, 0.045, 0.055)
        )
        return FilmRecipe(
            exposureEV: lerp(0.22, 0.18, t: night),
            colorMatrix: lerpMatrix(dayMatrix, nightMatrix, t: night),
            shadowSaturation: (amount: lerp(1.20, 1.22, t: night), maskGamma: lerp(1.55, 1.62, t: night)),
            contrast: lerp(1.06, 1.08, t: night),
            saturation: lerp(1.03, 1.04, t: night),
            highlightAmount: lerp(0.96, 0.94, t: night),
            shadowAmount: lerp(-0.06, -0.08, t: night),
            blurRadius: 0.50,
            vignetteStrength: CGFloat(lerp(1.05, 1.12, t: night)),
            leakAlpha: 0,
            bloomAlpha: 0.35,
            flashAlpha: 0,
            flashCenterLift: 0,
            grainAmount: 0.025,
            edgeBurnAmount: 0.04
        )
    }

    static func natura(night: Double) -> FilmRecipe {
        // Milder milky Fuji: slight lift and green, not a fog wash.
        let dayMatrix: FilmColorMatrix = (
            r: (0.96, 0.11, 0.01, 0),
            g: (0.06, 1.00, 0.06, 0),
            b: (0.005, 0.05, 0.80, 0),
            bias: (0.09, 0.095, 0.045)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.95, 0.12, 0.01, 0),
            g: (0.065, 1.02, 0.065, 0),
            b: (0.005, 0.055, 0.78, 0),
            bias: (0.085, 0.10, 0.04)
        )
        return FilmRecipe(
            exposureEV: lerp(0.40, 0.48, t: night),
            colorMatrix: lerpMatrix(dayMatrix, nightMatrix, t: night),
            shadowSaturation: (amount: lerp(1.15, 1.18, t: night), maskGamma: 1.45),
            contrast: lerp(0.88, 0.86, t: night),
            saturation: lerp(0.98, 0.99, t: night),
            highlightAmount: lerp(0.94, 0.92, t: night),
            shadowAmount: lerp(0.10, 0.14, t: night),
            blurRadius: 0.53,
            vignetteStrength: 0.85,
            leakAlpha: 0.28,
            bloomAlpha: 0.48,
            flashAlpha: 0,
            flashCenterLift: 0,
            grainAmount: 0.02,
            edgeBurnAmount: 0.03
        )
    }

    static func m6(night: Double) -> FilmRecipe {
        // Dense cousin nearer Original: a little darker and less sat, not razor contrast.
        let dayMatrix: FilmColorMatrix = (
            r: (0.97, 0.06, 0.00, 0),
            g: (0.03, 0.94, 0.025, 0),
            b: (0.00, 0.055, 0.92, 0),
            bias: (0.05, 0.045, 0.04)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.96, 0.055, 0.00, 0),
            g: (0.03, 0.935, 0.03, 0),
            b: (0.00, 0.06, 0.93, 0),
            bias: (0.045, 0.04, 0.042)
        )
        return FilmRecipe(
            exposureEV: lerp(0.18, 0.14, t: night),
            colorMatrix: lerpMatrix(dayMatrix, nightMatrix, t: night),
            shadowSaturation: (amount: lerp(1.08, 1.05, t: night), maskGamma: 1.40),
            contrast: lerp(1.06, 1.08, t: night),
            saturation: lerp(0.95, 0.93, t: night),
            highlightAmount: lerp(0.96, 0.94, t: night),
            shadowAmount: lerp(-0.04, -0.06, t: night),
            blurRadius: 0.48,
            vignetteStrength: 1.0,
            leakAlpha: 0,
            bloomAlpha: 0.35,
            flashAlpha: 0,
            flashCenterLift: 0,
            grainAmount: 0.03,
            edgeBurnAmount: 0.07
        )
    }

    private static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * t
    }

    private static func lerpMatrix(_ a: FilmColorMatrix, _ b: FilmColorMatrix, t: Double) -> FilmColorMatrix {
        func row(
            _ x: (Double, Double, Double, Double),
            _ y: (Double, Double, Double, Double)
        ) -> (Double, Double, Double, Double) {
            (lerp(x.0, y.0, t: t), lerp(x.1, y.1, t: t), lerp(x.2, y.2, t: t), lerp(x.3, y.3, t: t))
        }
        return (
            r: row(a.r, b.r),
            g: row(a.g, b.g),
            b: row(a.b, b.b),
            bias: (
                lerp(a.bias.0, b.bias.0, t: t),
                lerp(a.bias.1, b.bias.1, t: t),
                lerp(a.bias.2, b.bias.2, t: t)
            )
        )
    }
}

/// Invisible per-print strength: usually gentle, sometimes medium, rarely bold.
/// Seeded by print id + stock so reburn stays pixel-stable when strength is persisted.
enum FilmExpression {
    /// Legacy prints without `filmStrength` render at full stock character.
    static let legacyDefault: Double = 1.0
    static let minimumStrength: Double = 0.42
    static let maximumStrength: Double = 1.0

    /// Weighted draw: ~65% gentle, ~25% medium, ~10% bold. Original always 1.0.
    static func resolve(seed: String, stock: FilmStock) -> Double {
        guard stock != .onestep else { return maximumStrength }
        var rng = SeededRNG(seed: seedHash(seed, stock: stock, tag: "expr"))
        let roll = rng.nextUnit()
        let strength: Double
        if roll < 0.65 {
            strength = 0.42 + rng.nextUnit() * 0.20
        } else if roll < 0.90 {
            strength = 0.62 + rng.nextUnit() * 0.20
        } else {
            strength = 0.82 + rng.nextUnit() * 0.18
        }
        return clamp(strength, minimumStrength, maximumStrength)
    }

    /// Softens harsh knobs toward safe anchors while keeping stock color identity.
    /// Applied after scene-aware recipe, before serendipity.
    static func apply(_ recipe: FilmRecipe, strength: Double, stock: FilmStock) -> FilmRecipe {
        guard stock != .onestep else { return recipe }
        let t = clamp(strength, minimumStrength, maximumStrength)
        // Color / tone identity stays mostly stock even when gentle.
        let idMix = 0.58 + 0.42 * t
        // Contrast, flash, grain, edge burn attenuate more at low strength.
        let harshMix = 0.30 + 0.70 * t

        let house = FilmRecipe.onestep
        var next = recipe
        next.exposureEV = lerp(house.exposureEV, recipe.exposureEV, t: idMix)
        next.colorMatrix = lerpMatrix(house.colorMatrix, recipe.colorMatrix, t: idMix)
        next.shadowSaturation = (
            amount: lerp(house.shadowSaturation.amount, recipe.shadowSaturation.amount, t: idMix),
            maskGamma: lerp(house.shadowSaturation.maskGamma, recipe.shadowSaturation.maskGamma, t: idMix)
        )
        next.saturation = lerp(1.0, recipe.saturation, t: idMix)
        next.contrast = lerp(1.0, recipe.contrast, t: harshMix)
        next.highlightAmount = lerp(1.0, recipe.highlightAmount, t: harshMix)
        next.shadowAmount = lerp(0, recipe.shadowAmount, t: harshMix)
        next.blurRadius = lerp(0.50, recipe.blurRadius, t: idMix)
        next.vignetteStrength = CGFloat(lerp(1.0, Double(recipe.vignetteStrength), t: harshMix))
        next.leakAlpha = CGFloat(lerp(0, Double(recipe.leakAlpha), t: idMix))
        next.bloomAlpha = CGFloat(lerp(0.20, Double(recipe.bloomAlpha), t: idMix))
        next.flashAlpha = CGFloat(lerp(0, Double(recipe.flashAlpha), t: harshMix))
        next.flashCenterLift = lerp(0, recipe.flashCenterLift, t: harshMix)
        next.grainAmount = CGFloat(lerp(0, Double(recipe.grainAmount), t: harshMix))
        next.edgeBurnAmount = CGFloat(lerp(0, Double(recipe.edgeBurnAmount), t: harshMix))
        return next
    }

    fileprivate static func seedHash(_ seed: String, stock: FilmStock, tag: String) -> UInt64 {
        var hash: UInt64 = 0xC0FFEE
        for byte in (seed + "|" + stock.rawValue + "|" + tag).utf8 {
            hash = hash &* 31 &+ UInt64(byte)
        }
        return hash == 0 ? 0xDEADBEEF : hash
    }

    fileprivate static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, value))
    }

    fileprivate static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * t
    }

    fileprivate static func lerpMatrix(_ a: FilmColorMatrix, _ b: FilmColorMatrix, t: Double) -> FilmColorMatrix {
        func row(
            _ x: (Double, Double, Double, Double),
            _ y: (Double, Double, Double, Double)
        ) -> (Double, Double, Double, Double) {
            (lerp(x.0, y.0, t: t), lerp(x.1, y.1, t: t), lerp(x.2, y.2, t: t), lerp(x.3, y.3, t: t))
        }
        return (
            r: row(a.r, b.r),
            g: row(a.g, b.g),
            b: row(a.b, b.b),
            bias: (
                lerp(a.bias.0, b.bias.0, t: t),
                lerp(a.bias.1, b.bias.1, t: t),
                lerp(a.bias.2, b.bias.2, t: t)
            )
        )
    }
}

/// Light per-print jitter so two draws of the same stock still feel like Polaroid chance.
/// Jitter amplitude and rare long-roll events scale with expression strength.
enum FilmSerendipity {
    static func vary(
        _ recipe: FilmRecipe,
        seed: String,
        stock: FilmStock,
        strength: Double = FilmExpression.legacyDefault
    ) -> FilmRecipe {
        guard stock != .onestep else { return recipe }

        let s = FilmExpression.clamp(strength, FilmExpression.minimumStrength, FilmExpression.maximumStrength)
        // Keep legacy hash shape (`seed|stock`) so pre-expression prints reburn identically at strength 1.0.
        var rng = SeededRNG(seed: legacySeedHash(seed, stock: stock))
        var next = recipe

        next.contrast = FilmExpression.clamp(
            next.contrast + (rng.nextUnit() * 0.04 - 0.02) * s,
            0.68,
            1.20
        )
        next.vignetteStrength = CGFloat(FilmExpression.clamp(
            Double(next.vignetteStrength) + (rng.nextUnit() * 0.12 - 0.06) * s,
            0.55,
            1.70
        ))
        next.bloomAlpha = CGFloat(FilmExpression.clamp(
            Double(next.bloomAlpha) + (rng.nextUnit() * 0.08 - 0.03) * s,
            0,
            0.45
        ))
        next.leakAlpha = CGFloat(FilmExpression.clamp(
            Double(next.leakAlpha) + (rng.nextUnit() * 0.06 - 0.02) * s,
            0,
            0.40
        ))
        next.grainAmount = CGFloat(FilmExpression.clamp(
            Double(next.grainAmount) + (rng.nextUnit() * 0.03 - 0.01) * s,
            0,
            0.08
        ))
        next.edgeBurnAmount = CGFloat(FilmExpression.clamp(
            Double(next.edgeBurnAmount) + (rng.nextUnit() * 0.08 - 0.03) * s,
            0,
            0.25
        ))
        next.flashAlpha = CGFloat(FilmExpression.clamp(
            Double(next.flashAlpha) + (rng.nextUnit() * 0.04 - 0.02) * s,
            0,
            0.34
        ))

        // Occasional “long” soft effect: extra blur OR extra leak — never both maxed.
        // Probabilities scale with strength so bold prints get rare drama more often.
        let longRoll = rng.nextUnit()
        let blurChance = 0.35 * s
        let leakChance = blurChance + 0.20 * s
        if longRoll < blurChance {
            next.blurRadius = FilmExpression.clamp(
                next.blurRadius + (0.08 + rng.nextUnit() * 0.06) * s,
                0.12,
                0.70
            )
        } else if longRoll < leakChance {
            next.leakAlpha = CGFloat(FilmExpression.clamp(
                Double(next.leakAlpha) + (0.06 + rng.nextUnit() * 0.05) * s,
                0,
                0.35
            ))
        }

        return next
    }

    private static func legacySeedHash(_ seed: String, stock: FilmStock) -> UInt64 {
        var hash: UInt64 = 0xC0FFEE
        for byte in (seed + "|" + stock.rawValue).utf8 {
            hash = hash &* 31 &+ UInt64(byte)
        }
        return hash == 0 ? 0xDEADBEEF : hash
    }
}

/// Deterministic RNG for serendipity (and tests).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 636_413_622_384_679_3005 &+ 1
        return state
    }

    /// Uniform 0…1.
    mutating func nextUnit() -> Double {
        Double(next() % 10_000) / 10_000
    }
}
