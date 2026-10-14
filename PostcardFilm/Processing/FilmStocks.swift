import CoreGraphics
import Foundation
import UIKit

/// One of five emulsions in the Kodachrome-family pack. Drawn at shutter; user never picks.
enum FilmStock: String, Codable, CaseIterable, Equatable {
    /// House Kodachrome 64 daylight.
    case onestep
    /// Dusk / harder light — same reds, deeper edges, soft fill when dark.
    case sun660
    /// Cooler K25-ish — deeper sky blues, reds still forward.
    case mini9
    /// Summer-greens cousin — luminous greens without Fuji fog.
    case natura
    /// Densest Dmax — slightly darker EV.
    case m6

    /// Docs / DEBUG only — never shown in product UI.
    var cameraName: String {
        switch self {
        case .onestep: return "Matisse"
        case .sun660: return "Van Gogh"
        case .mini9: return "Picasso"
        case .natura: return "Monet"
        case .m6: return "Rembrandt"
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
    func recipe(meanLuma: Double, centerBias: Double, meanChroma: Double = 0.2) -> FilmRecipe {
        let night = FilmScene.nightAmount(meanLuma: meanLuma)
        let alreadyFlashed = centerBias > 0.12
        var recipe: FilmRecipe
        switch self {
        case .onestep:
            recipe = .onestep
        case .sun660:
            recipe = .sun660(night: night, alreadyFlashed: alreadyFlashed)
        case .mini9:
            recipe = .mini9(night: night)
        case .natura:
            recipe = .natura(night: night)
        case .m6:
            recipe = .m6(night: night)
        }
        return FilmScene.applyChromaSaturation(recipe, meanChroma: meanChroma)
    }
}

/// How dark / colourful the frame is.
enum FilmScene {
    static func nightAmount(meanLuma: Double) -> Double {
        // Bright day ~0.45+, deep night ~0.12-. Soft ramp in between.
        let t = (0.42 - meanLuma) / 0.30
        return min(1, max(0, t))
    }

    /// Whole-frame mean luma, (center − edge) bias, and mean chroma on the ungraded square.
    static func measure(_ image: UIImage) -> (meanLuma: Double, centerBias: Double, meanChroma: Double) {
        let sampleSide = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sampleSide, height: sampleSide))
        let small = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide))
        }
        guard let cg = small.cgImage else { return (0.5, 0, 0.2) }

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
            return (0.5, 0, 0.2)
        }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        var chromaTotal = 0.0
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
                chromaTotal += max(r, g, b) - min(r, g, b)
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
        let chroma = chromaTotal / pixelCount
        let centerMean = centerCount > 0 ? centerTotal / Double(centerCount) : mean
        let edgeMean = edgeCount > 0 ? edgeTotal / Double(edgeCount) : mean
        return (mean, centerMean - edgeMean, chroma)
    }

    /// Low-chroma (dull gray/green) frames get a modest sat bump; colourful scenes stay put.
    static func applyChromaSaturation(_ recipe: FilmRecipe, meanChroma: Double) -> FilmRecipe {
        var next = recipe
        guard meanChroma < 0.12 else { return next }
        let t = (0.12 - meanChroma) / 0.12
        let bump = 0.04 + 0.04 * min(1, max(0, t))
        next.saturation = min(1.18, next.saturation + bump)
        return next
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
    /// Multiply vignette drawn alpha scale (rim-only overlay).
    var vignetteStrength: CGFloat
    /// Screen light-leak alpha (0 = off). Retired for Kodachrome pack.
    var leakAlpha: CGFloat
    /// Screen highlight-bloom alpha (0 = off). Retired for Kodachrome pack.
    var bloomAlpha: CGFloat
    /// Soft radial flash fill screen alpha (sun660). 0 = off.
    var flashAlpha: CGFloat
    /// Extra center exposure for sun660 flash fill.
    var flashCenterLift: Double
    /// Soft film grain overlay alpha (always 0 — upsampled noise looked pixelated).
    var grainAmount: CGFloat
    /// Soft edge burn strength (0 = none).
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
    /// House Kodachrome 64 daylight — denser darks, forward reds, no leak/bloom.
    static let onestep = FilmRecipe(
        exposureEV: Grade.exposureEV(),
        colorMatrix: Grade.colorMatrix(),
        shadowSaturation: Grade.shadowSaturation(),
        contrast: 1.04,
        saturation: 1.08,
        highlightAmount: 0.96,
        shadowAmount: -0.04,
        blurRadius: 0.42,
        vignetteStrength: 0.65,
        leakAlpha: 0,
        bloomAlpha: 0,
        flashAlpha: 0,
        flashCenterLift: 0,
        grainAmount: 0,
        edgeBurnAmount: 0
    )

    /// Quiet Matisse expression floor — bold strength lerps fully back to `onestep`.
    static let matisseSoft = FilmRecipe(
        exposureEV: Grade.exposureEV() * 0.92,
        colorMatrix: (
            r: (0.98, 0.05, 0.02, 0),
            g: (0.03, 0.96, 0.03, 0),
            b: (0.02, 0.04, 0.94, 0),
            bias: (0.03, 0.025, 0.02)
        ),
        shadowSaturation: (amount: 1.08, maskGamma: 1.45),
        contrast: 1.0,
        saturation: 1.02,
        highlightAmount: 0.98,
        shadowAmount: 0,
        blurRadius: 0.40,
        vignetteStrength: 0.50,
        leakAlpha: 0,
        bloomAlpha: 0,
        flashAlpha: 0,
        flashCenterLift: 0,
        grainAmount: 0,
        edgeBurnAmount: 0
    )

    static func sun660(night: Double, alreadyFlashed: Bool) -> FilmRecipe {
        // Dusk / harder light — same red pop, deeper edges, soft fill when dark.
        let dayMatrix: FilmColorMatrix = (
            r: (0.96, 0.08, 0.02, 0),
            g: (0.035, 0.90, 0.04, 0),
            b: (0.01, 0.06, 0.93, 0),
            bias: (0.04, 0.035, 0.04)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.94, 0.075, 0.025, 0),
            g: (0.035, 0.895, 0.045, 0),
            b: (0.01, 0.065, 0.94, 0),
            bias: (0.035, 0.032, 0.042)
        )
        let matrix = lerpMatrix(dayMatrix, nightMatrix, t: night)

        let dayEV = 0.42
        let nightEV = alreadyFlashed ? 0.28 : 0.50
        let ev = lerp(dayEV, nightEV, t: night)

        let dayFlash: CGFloat = 0.10
        let nightFlash: CGFloat = alreadyFlashed ? 0.05 : 0.18
        let flash = CGFloat(lerp(Double(dayFlash), Double(nightFlash), t: night))

        let dayLift = alreadyFlashed ? 0.0 : 0.04
        let nightLift = alreadyFlashed ? 0.0 : 0.10
        let lift = lerp(dayLift, nightLift, t: night)

        return FilmRecipe(
            exposureEV: ev,
            colorMatrix: matrix,
            shadowSaturation: (amount: lerp(1.20, 1.18, t: night), maskGamma: 1.58),
            contrast: lerp(1.06, 1.08, t: night),
            saturation: lerp(1.05, 1.04, t: night),
            highlightAmount: lerp(0.94, 0.92, t: night),
            shadowAmount: lerp(-0.06, -0.08, t: night),
            blurRadius: 0.42,
            vignetteStrength: CGFloat(lerp(0.80, 0.90, t: night)),
            leakAlpha: 0,
            bloomAlpha: 0,
            flashAlpha: flash,
            flashCenterLift: lift,
            grainAmount: 0,
            edgeBurnAmount: 0.07
        )
    }

    static func mini9(night: Double) -> FilmRecipe {
        // Cooler K25-ish — deeper sky blues, reds still forward, darks closed.
        let dayMatrix: FilmColorMatrix = (
            r: (1.00, 0.06, 0.01, 0),
            g: (0.025, 0.93, 0.04, 0),
            b: (0.01, 0.055, 0.94, 0),
            bias: (0.045, 0.04, 0.038)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.98, 0.055, 0.01, 0),
            g: (0.025, 0.92, 0.045, 0),
            b: (0.01, 0.06, 0.95, 0),
            bias: (0.04, 0.038, 0.042)
        )
        return FilmRecipe(
            exposureEV: lerp(0.24, 0.20, t: night),
            colorMatrix: lerpMatrix(dayMatrix, nightMatrix, t: night),
            shadowSaturation: (amount: lerp(1.24, 1.26, t: night), maskGamma: lerp(1.60, 1.66, t: night)),
            contrast: lerp(1.06, 1.08, t: night),
            saturation: lerp(1.08, 1.09, t: night),
            highlightAmount: lerp(0.95, 0.93, t: night),
            shadowAmount: lerp(-0.06, -0.08, t: night),
            blurRadius: 0.40,
            vignetteStrength: CGFloat(lerp(0.65, 0.72, t: night)),
            leakAlpha: 0,
            bloomAlpha: 0,
            flashAlpha: 0,
            flashCenterLift: 0,
            grainAmount: 0,
            edgeBurnAmount: 0.04
        )
    }

    static func natura(night: Double) -> FilmRecipe {
        // Monet — Polaroid olive foliage (cooler green, denser darks; not yellow lawn).
        let dayMatrix: FilmColorMatrix = (
            r: (0.98, 0.07, 0.01, 0),
            g: (0.04, 1.02, 0.07, 0),
            b: (0.01, 0.07, 0.86, 0),
            bias: (0.05, 0.042, 0.032)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (0.97, 0.075, 0.01, 0),
            g: (0.042, 1.022, 0.075, 0),
            b: (0.01, 0.075, 0.85, 0),
            bias: (0.045, 0.045, 0.034)
        )
        return FilmRecipe(
            exposureEV: lerp(0.30, 0.34, t: night),
            colorMatrix: lerpMatrix(dayMatrix, nightMatrix, t: night),
            shadowSaturation: (amount: lerp(1.18, 1.20, t: night), maskGamma: 1.55),
            contrast: lerp(1.04, 1.06, t: night),
            saturation: lerp(1.05, 1.06, t: night),
            highlightAmount: lerp(0.94, 0.92, t: night),
            shadowAmount: lerp(-0.05, -0.06, t: night),
            blurRadius: 0.42,
            vignetteStrength: 0.62,
            leakAlpha: 0,
            bloomAlpha: 0,
            flashAlpha: 0,
            flashCenterLift: 0,
            grainAmount: 0,
            edgeBurnAmount: 0.05
        )
    }

    static func m6(night: Double) -> FilmRecipe {
        // Densest Dmax — reds still pop, sat restored, slightly lower EV.
        let dayMatrix: FilmColorMatrix = (
            r: (1.01, 0.06, 0.00, 0),
            g: (0.025, 0.93, 0.025, 0),
            b: (0.00, 0.04, 0.87, 0),
            bias: (0.048, 0.038, 0.022)
        )
        let nightMatrix: FilmColorMatrix = (
            r: (1.00, 0.055, 0.00, 0),
            g: (0.025, 0.925, 0.03, 0),
            b: (0.00, 0.045, 0.88, 0),
            bias: (0.042, 0.035, 0.024)
        )
        return FilmRecipe(
            exposureEV: lerp(0.18, 0.14, t: night),
            colorMatrix: lerpMatrix(dayMatrix, nightMatrix, t: night),
            shadowSaturation: (amount: lerp(1.16, 1.14, t: night), maskGamma: 1.50),
            contrast: lerp(1.07, 1.09, t: night),
            saturation: lerp(1.04, 1.03, t: night),
            highlightAmount: lerp(0.94, 0.92, t: night),
            shadowAmount: lerp(-0.07, -0.09, t: night),
            blurRadius: 0.38,
            vignetteStrength: 0.78,
            leakAlpha: 0,
            bloomAlpha: 0,
            flashAlpha: 0,
            flashCenterLift: 0,
            grainAmount: 0,
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
    /// Chance a print gets a tiny depth kiss after expression (~18%).
    static let depthKissChance: Double = 0.18
    /// Contrast bump when the depth kiss fires.
    static let depthKissContrastMin: Double = 0.02
    static let depthKissContrastMax: Double = 0.04
    /// Extra shadow crush (more negative) when the depth kiss fires.
    static let depthKissShadowMin: Double = 0.02
    static let depthKissShadowMax: Double = 0.04
    /// Optional rim vignette nudge when the depth kiss fires.
    static let depthKissVignetteMin: Double = 0.02
    static let depthKissVignetteMax: Double = 0.04

    /// Weighted draw: ~65% gentle, ~25% medium, ~10% bold (all five stocks, including Matisse).
    static func resolve(seed: String, stock: FilmStock) -> Double {
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
    /// - Parameter seed: print id — drives the occasional depth kiss (reburn-stable).
    static func apply(
        _ recipe: FilmRecipe,
        strength: Double,
        stock: FilmStock,
        seed: String = ""
    ) -> FilmRecipe {
        let t = clamp(strength, minimumStrength, maximumStrength)
        // Color / tone identity stays mostly stock even when gentle.
        let idMix = 0.58 + 0.42 * t
        // Contrast, flash, edge burn attenuate more at low strength.
        let harshMix = 0.30 + 0.70 * t

        let expressed: FilmRecipe
        if stock == .onestep {
            // Matisse: quiet soft anchor → full house. Bold (1.0) == today's house look.
            expressed = mix(from: .matisseSoft, toward: FilmRecipe.onestep, idMix: idMix, harshMix: harshMix)
        } else {
            expressed = mix(from: .onestep, toward: recipe, idMix: idMix, harshMix: harshMix)
        }
        return applyDepthKiss(expressed, seed: seed, stock: stock)
    }

    /// Whether this seed/stock pair receives the depth kiss (for tests).
    static func depthKissApplies(seed: String, stock: FilmStock) -> Bool {
        var rng = SeededRNG(seed: seedHash(seed, stock: stock, tag: "depthkiss"))
        return rng.nextUnit() < depthKissChance
    }

    /// Soft Matisse anchor — quieter contrast/sat/vignette; bold lerps to full house.
    fileprivate static func mix(
        from anchor: FilmRecipe,
        toward target: FilmRecipe,
        idMix: Double,
        harshMix: Double
    ) -> FilmRecipe {
        var next = target
        next.exposureEV = lerp(anchor.exposureEV, target.exposureEV, t: idMix)
        next.colorMatrix = lerpMatrix(anchor.colorMatrix, target.colorMatrix, t: idMix)
        next.shadowSaturation = (
            amount: lerp(anchor.shadowSaturation.amount, target.shadowSaturation.amount, t: idMix),
            maskGamma: lerp(anchor.shadowSaturation.maskGamma, target.shadowSaturation.maskGamma, t: idMix)
        )
        next.saturation = lerp(anchor.saturation, target.saturation, t: idMix)
        next.contrast = lerp(anchor.contrast, target.contrast, t: harshMix)
        next.highlightAmount = lerp(anchor.highlightAmount, target.highlightAmount, t: harshMix)
        next.shadowAmount = lerp(anchor.shadowAmount, target.shadowAmount, t: harshMix)
        next.blurRadius = lerp(anchor.blurRadius, target.blurRadius, t: idMix)
        next.vignetteStrength = CGFloat(lerp(Double(anchor.vignetteStrength), Double(target.vignetteStrength), t: harshMix))
        next.leakAlpha = 0
        next.bloomAlpha = 0
        next.flashAlpha = CGFloat(lerp(Double(anchor.flashAlpha), Double(target.flashAlpha), t: harshMix))
        next.flashCenterLift = lerp(anchor.flashCenterLift, target.flashCenterLift, t: harshMix)
        next.grainAmount = 0
        next.edgeBurnAmount = CGFloat(lerp(Double(anchor.edgeBurnAmount), Double(target.edgeBurnAmount), t: harshMix))
        return next
    }

    /// Occasional contrast + darker darks — no hue / green / yellow shift.
    fileprivate static func applyDepthKiss(
        _ recipe: FilmRecipe,
        seed: String,
        stock: FilmStock
    ) -> FilmRecipe {
        guard !seed.isEmpty else { return recipe }
        var rng = SeededRNG(seed: seedHash(seed, stock: stock, tag: "depthkiss"))
        let roll = rng.nextUnit()
        guard roll < depthKissChance else { return recipe }
        let contrastBump = depthKissContrastMin
            + rng.nextUnit() * (depthKissContrastMax - depthKissContrastMin)
        let shadowCrush = depthKissShadowMin
            + rng.nextUnit() * (depthKissShadowMax - depthKissShadowMin)
        let vignetteBump = depthKissVignetteMin
            + rng.nextUnit() * (depthKissVignetteMax - depthKissVignetteMin)
        var next = recipe
        next.contrast = clamp(next.contrast + contrastBump, 0.90, 1.18)
        next.shadowAmount = clamp(next.shadowAmount - shadowCrush, -0.14, 0.08)
        next.vignetteStrength = CGFloat(clamp(
            Double(next.vignetteStrength) + vignetteBump,
            0.45,
            1.15
        ))
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

/// Light per-print jitter — brightness, contrast, edges — never leak/bloom/grain.
enum FilmSerendipity {
    static func vary(
        _ recipe: FilmRecipe,
        seed: String,
        stock: FilmStock,
        strength: Double = FilmExpression.legacyDefault
    ) -> FilmRecipe {
        let s = FilmExpression.clamp(strength, FilmExpression.minimumStrength, FilmExpression.maximumStrength)
        // Keep legacy hash shape (`seed|stock`) so reburns stay pixel-stable.
        var rng = SeededRNG(seed: legacySeedHash(seed, stock: stock))
        var next = recipe

        next.exposureEV = FilmExpression.clamp(
            next.exposureEV + (rng.nextUnit() * 0.20 - 0.10) * s,
            0.05,
            0.55
        )
        next.contrast = FilmExpression.clamp(
            next.contrast + (rng.nextUnit() * 0.04 - 0.02) * s,
            0.90,
            1.18
        )
        next.vignetteStrength = CGFloat(FilmExpression.clamp(
            Double(next.vignetteStrength) + (rng.nextUnit() * 0.10 - 0.05) * s,
            0.45,
            1.15
        ))
        // Consume former grain slot so EV / edge / flash streams stay seed-stable.
        _ = rng.nextUnit()
        next.grainAmount = 0
        next.edgeBurnAmount = CGFloat(FilmExpression.clamp(
            Double(next.edgeBurnAmount) + (rng.nextUnit() * 0.06 - 0.02) * s,
            0,
            0.18
        ))
        next.flashAlpha = CGFloat(FilmExpression.clamp(
            Double(next.flashAlpha) + (rng.nextUnit() * 0.04 - 0.02) * s,
            0,
            0.28
        ))

        // Occasional extra chemistry softness — never leak.
        let longRoll = rng.nextUnit()
        let blurChance = 0.30 * s
        if longRoll < blurChance {
            next.blurRadius = FilmExpression.clamp(
                next.blurRadius + (0.06 + rng.nextUnit() * 0.05) * s,
                0.12,
                0.62
            )
        }

        next.leakAlpha = 0
        next.bloomAlpha = 0
        next.grainAmount = 0
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
