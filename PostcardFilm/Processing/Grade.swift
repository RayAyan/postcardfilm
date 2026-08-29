import Foundation

/// Polaroid 600 color grade — pure functions.
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double
}

enum Grade {
    private static func clamp01(_ v: Double) -> Double {
        min(1, max(0, v))
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    private static func sCurve(_ x: Double, amount: Double = 0.35) -> Double {
        let centered = (x - 0.5) * 2
        let curved = tanh(centered * (1 + amount)) / tanh(1 + amount)
        return curved * 0.5 + 0.5
    }

    private static func luma(_ c: RGB) -> Double {
        0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// Grade one pixel in 0–1 sRGB space (bright Polaroid / Huji-leaning recipe).
    static func gradePixel(_ input: RGB) -> RGB {
        var r = input.r
        var g = input.g
        var b = input.b

        // Mild overall lift — Huji-like sunny exposure.
        let exposure: Double = 0.10
        r = clamp01(r + exposure)
        g = clamp01(g + exposure * 0.95)
        b = clamp01(b + exposure * 0.85)

        let L = luma(RGB(r: r, g: g, b: b))

        // Chemical fog — lifted blacks, never true black.
        let shadowLift = smoothstep(0.50, 0.0, L)
        r = clamp01(r + 0.055 * shadowLift)
        g = clamp01(g + 0.048 * shadowLift)
        b = clamp01(b + 0.042 * shadowLift)

        r = sCurve(r, amount: 0.32)
        g = sCurve(g, amount: 0.32)
        b = sCurve(b, amount: 0.32)

        // Soft contrast — Polaroid, not digital punch.
        let contrast = 0.90
        r = clamp01((r - 0.5) * contrast + 0.5)
        g = clamp01((g - 0.5) * contrast + 0.5)
        b = clamp01((b - 0.5) * contrast + 0.5)

        let L2 = luma(RGB(r: r, g: g, b: b))

        // Warm yellow midtones (Huji / 600).
        let warm = smoothstep(0.12, 0.70, L2) * (1 - smoothstep(0.78, 1.0, L2))
        r = clamp01(r * (1 + 0.12 * warm))
        g = clamp01(g * (1 + 0.045 * warm))
        b = clamp01(b * (1 - 0.07 * warm))

        // Mild midtone vibrance
        let mid = smoothstep(0.18, 0.55, L2) * (1 - smoothstep(0.72, 0.96, L2))
        let sat = 1 + 0.07 * mid
        let gray = luma(RGB(r: r, g: g, b: b))
        r = clamp01(gray + (r - gray) * sat)
        g = clamp01(gray + (g - gray) * sat)
        b = clamp01(gray + (b - gray) * sat)

        // Cream highlights — never paper-white.
        let hi = smoothstep(0.62, 1.0, L2)
        r = clamp01(r * (1 - 0.035 * hi) + 0.95 * hi * 0.055)
        g = clamp01(g * (1 - 0.045 * hi) + 0.91 * hi * 0.05)
        b = clamp01(b * (1 - 0.09 * hi) + 0.84 * hi * 0.04)

        let cool = smoothstep(0.28, 0.0, L2)
        r = clamp01(r - 0.01 * cool)
        g = clamp01(g + 0.005 * cool)
        b = clamp01(b + 0.016 * cool)

        return RGB(r: r, g: g, b: b)
    }

    /// Convenience for 0–255 channel fixtures in tests.
    static func gradeRgb255(r: Int, g: Int, b: Int) -> (r: Int, g: Int, b: Int) {
        let out = gradePixel(RGB(r: Double(r) / 255, g: Double(g) / 255, b: Double(b) / 255))
        return (
            r: Int(round(out.r * 255)),
            g: Int(round(out.g * 255)),
            b: Int(round(out.b * 255))
        )
    }

    /// Bright warm Polaroid look as CIColorMatrix + bias.
    static func colorMatrix() -> (
        r: (Double, Double, Double, Double),
        g: (Double, Double, Double, Double),
        b: (Double, Double, Double, Double),
        bias: (Double, Double, Double)
    ) {
        (
            r: (0.94, 0.09, 0.02, 0),
            g: (0.04, 0.92, 0.04, 0),
            b: (0.01, 0.06, 0.86, 0),
            // Extra bias = sunny Huji lift.
            bias: (0.08, 0.07, 0.05)
        )
    }

    /// Global exposure bump applied in the CI path (EV).
    static func exposureEV() -> Double { 0.32 }

    /// Extra colour for dark areas only, so shadowed frames stop reading flat.
    /// `maskGamma` above 1 pulls the mask back toward true shadows.
    static func shadowSaturation() -> (amount: Double, maskGamma: Double) {
        (amount: 1.18, maskGamma: 1.55)
    }
}
