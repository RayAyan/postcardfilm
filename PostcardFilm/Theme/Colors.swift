import SwiftUI

enum AppTheme {
    // MARK: - Print palette (cream Polaroid card — do not use for app chrome)

    static let paper = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)
    static let paperDeep = Color(red: 237 / 255, green: 230 / 255, blue: 216 / 255)
    static let graphite = Color(red: 44 / 255, green: 42 / 255, blue: 38 / 255)
    static let graphiteMuted = Color(red: 107 / 255, green: 101 / 255, blue: 96 / 255)
    static let border = Color(red: 217 / 255, green: 208 / 255, blue: 194 / 255)
    static let destructive = Color(red: 192 / 255, green: 57 / 255, blue: 43 / 255)
    static let highlighter = Color(red: 1, green: 235 / 255, blue: 120 / 255).opacity(0.45)
    static let overlay = Color(red: 0, green: 0, blue: 0).opacity(0.55)

    static let cardUIColor = UIColor(red: 246 / 255, green: 241 / 255, blue: 231 / 255, alpha: 1)
    static let graphiteUIColor = UIColor(red: 44 / 255, green: 42 / 255, blue: 38 / 255, alpha: 1)

    // MARK: - App UI palette (black chrome; print stays cream)

    static let surface = Color(red: 18 / 255, green: 17 / 255, blue: 16 / 255)
    static let surfaceRaised = Color(red: 32 / 255, green: 30 / 255, blue: 28 / 255)
    static let textPrimary = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)
    static let textSecondary = Color(red: 168 / 255, green: 162 / 255, blue: 152 / 255)
    static let hairline = Color(red: 72 / 255, green: 68 / 255, blue: 62 / 255)
    static let accentFill = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)
    static let accentText = Color(red: 44 / 255, green: 42 / 255, blue: 38 / 255)

    // MARK: - Layout

    static let hitTarget: CGFloat = 44
    static let shutter: CGFloat = 72
    static let gap: CGFloat = 8
}
