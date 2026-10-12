import Foundation

/// Kodachrome-family house grade — pure functions (tests + CI matrix source).
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

    /// Grade one pixel in 0–1 sRGB — Kodachrome 64 grammar: dense darks, forward reds/oranges.
    static func gradePixel(_ input: RGB) -> RGB {
        var r = input.r
        var g = input.g
        var b = input.b

        // Sunny daylight lift — less than the old Polaroid fog.
        let exposure: Double = 0.08
        r = clamp01(r + exposure)
        g = clamp01(g + exposure * 0.92)
        b = clamp01(b + exposure * 0.78)

        let L = luma(RGB(r: r, g: g, b: b))

        // Darks close down — tiny residual lift so blacks are not crushed to zero.
        let shadowLift = smoothstep(0.42, 0.0, L)
        r = clamp01(r + 0.018 * shadowLift)
        g = clamp01(g + 0.016 * shadowLift)
        b = clamp01(b + 0.014 * shadowLift)

        r = sCurve(r, amount: 0.40)
        g = sCurve(g, amount: 0.38)
        b = sCurve(b, amount: 0.36)

        // Slide contrast — denser than Polaroid soft.
        let contrast = 0.98
        r = clamp01((r - 0.5) * contrast + 0.5)
        g = clamp01((g - 0.5) * contrast + 0.5)
        b = clamp01((b - 0.5) * contrast + 0.5)

        let L2 = luma(RGB(r: r, g: g, b: b))

        // Forward reds / gold oranges (K64 long-red feel).
        let warm = smoothstep(0.12, 0.70, L2) * (1 - smoothstep(0.78, 1.0, L2))
        r = clamp01(r * (1 + 0.16 * warm))
        g = clamp01(g * (1 + 0.05 * warm))
        b = clamp01(b * (1 - 0.09 * warm))

        // Midtone vibrance — reds denser than greens.
        let mid = smoothstep(0.18, 0.55, L2) * (1 - smoothstep(0.72, 0.96, L2))
        let sat = 1 + 0.10 * mid
        let gray = luma(RGB(r: r, g: g, b: b))
        r = clamp01(gray + (r - gray) * (sat + 0.04 * mid))
        g = clamp01(gray + (g - gray) * sat)
        b = clamp01(gray + (b - gray) * (sat - 0.02 * mid))

        // Cream highlights — never paper-white.
        let hi = smoothstep(0.58, 1.0, L2)
        r = clamp01(r * (1 - 0.10 * hi) + 0.90 * hi * 0.04)
        g = clamp01(g * (1 - 0.12 * hi) + 0.85 * hi * 0.035)
        b = clamp01(b * (1 - 0.16 * hi) + 0.74 * hi * 0.03)

        // Restrained blue in deep shadows — not teal-Fuji lift.
        let cool = smoothstep(0.22, 0.0, L2)
        r = clamp01(r - 0.008 * cool)
        g = clamp01(g + 0.002 * cool)
        b = clamp01(b + 0.008 * cool)

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

    /// Kodachrome-family CIColorMatrix — forward red, restrained blue, modest warm bias.
    static func colorMatrix() -> (
        r: (Double, Double, Double, Double),
        g: (Double, Double, Double, Double),
        b: (Double, Double, Double, Double),
        bias: (Double, Double, Double)
    ) {
        (
            r: (1.02, 0.08, 0.01, 0),
            g: (0.03, 0.94, 0.03, 0),
            b: (0.00, 0.04, 0.88, 0),
            bias: (0.055, 0.045, 0.028)
        )
    }

    /// Global exposure bump applied in the CI path (EV).
    static func exposureEV() -> Double { 0.28 }

    /// Extra colour for dark areas only — denser reds in shadows without fogging blacks.
    /// `maskGamma` above 1 pulls the mask back toward true shadows.
    static func shadowSaturation() -> (amount: Double, maskGamma: Double) {
        (amount: 1.22, maskGamma: 1.62)
    }
}
