#!/usr/bin/env swift
// Host-side smoke verification of pure logic (mirrors XCTest assertions).
// Run: swift Scripts/verify_logic.swift

import Foundation

struct RGB { var r: Double; var g: Double; var b: Double }

enum Grade {
    static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }
    static func sCurve(_ x: Double, amount: Double = 0.35) -> Double {
        let centered = (x - 0.5) * 2
        let curved = tanh(centered * (1 + amount)) / tanh(1 + amount)
        return curved * 0.5 + 0.5
    }
    static func luma(_ c: RGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    static func gradePixel(_ input: RGB) -> RGB {
        var r = input.r, g = input.g, b = input.b
        let L = luma(RGB(r: r, g: g, b: b))
        let shadowLift = smoothstep(0.45, 0.0, L)
        r = clamp01(r + 0.04 * shadowLift); g = clamp01(g + 0.035 * shadowLift); b = clamp01(b + 0.03 * shadowLift)
        r = sCurve(r, amount: 0.42); g = sCurve(g, amount: 0.42); b = sCurve(b, amount: 0.42)
        let contrast = 0.98
        r = clamp01((r - 0.5) * contrast + 0.5); g = clamp01((g - 0.5) * contrast + 0.5); b = clamp01((b - 0.5) * contrast + 0.5)
        let L2 = luma(RGB(r: r, g: g, b: b))
        let warm = smoothstep(0.15, 0.65, L2) * (1 - smoothstep(0.75, 1.0, L2))
        r = clamp01(r * (1 + 0.10 * warm)); g = clamp01(g * (1 + 0.035 * warm)); b = clamp01(b * (1 - 0.06 * warm))
        let mid = smoothstep(0.2, 0.55, L2) * (1 - smoothstep(0.7, 0.95, L2))
        let sat = 1 + 0.08 * mid
        let gray = luma(RGB(r: r, g: g, b: b))
        r = clamp01(gray + (r - gray) * sat); g = clamp01(gray + (g - gray) * sat); b = clamp01(gray + (b - gray) * sat)
        let hi = smoothstep(0.65, 1.0, L2)
        r = clamp01(r * (1 - 0.04 * hi) + 0.94 * hi * 0.05)
        g = clamp01(g * (1 - 0.05 * hi) + 0.90 * hi * 0.045)
        b = clamp01(b * (1 - 0.10 * hi) + 0.82 * hi * 0.035)
        let cool = smoothstep(0.3, 0.0, L2)
        r = clamp01(r - 0.012 * cool); g = clamp01(g + 0.004 * cool); b = clamp01(b + 0.018 * cool)
        return RGB(r: r, g: g, b: b)
    }
    static func gradeRgb255(r: Int, g: Int, b: Int) -> (Int, Int, Int) {
        let out = gradePixel(RGB(r: Double(r)/255, g: Double(g)/255, b: Double(b)/255))
        return (Int(round(out.r*255)), Int(round(out.g*255)), Int(round(out.b*255)))
    }
}

func assertTrue(_ cond: Bool, _ msg: String) {
    if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) }
}

let black = Grade.gradeRgb255(r: 0, g: 0, b: 0)
assertTrue(black.0 > 0 && black.1 > 0 && black.2 > 0, "lifted blacks")
assertTrue(black.2 >= black.0 - 10, "teal shadow lean")

let white = Grade.gradeRgb255(r: 255, g: 255, b: 255)
assertTrue(white.0 < 255 && white.1 < 255 && white.2 < 255, "cream whites")
assertTrue(white.2 <= white.0, "cream blue <= red")

let mid = Grade.gradeRgb255(r: 128, g: 128, b: 128)
assertTrue(mid.0 > mid.2, "warm mid gray")

let side = Int(round(1080.0 * 0.09))
let top = side
let bottom = Int(round((0.24 / 0.76) * Double(1080 + top)))
let canvasH = 1080 + top + bottom
let bottomRatio = Double(bottom) / Double(canvasH)
assertTrue(bottomRatio >= 0.22 && bottomRatio <= 0.26, "bottom band \(bottomRatio)")
let sideRatio = Double(side) / 1080.0
assertTrue(sideRatio >= 0.08 && sideRatio <= 0.10, "side band")

print("OK: pure logic assertions passed")
