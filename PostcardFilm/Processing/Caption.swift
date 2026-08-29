import Foundation
import UIKit

enum CaptionMode: String, Codable, CaseIterable, Identifiable {
    case date
    case custom
    case blank

    var id: String { rawValue }

    var label: String {
        switch self {
        case .date: return "date"
        case .custom: return "custom"
        case .blank: return "blank"
        }
    }
}

enum DateFormatOption: String, Codable, CaseIterable, Identifiable {
    case long
    case short
    case iso

    var id: String { rawValue }
}

/// Letter case for date captions on the strip.
enum DateCaseStyle: String, Codable, CaseIterable, Identifiable {
    case lowercase
    case sentence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lowercase: return "lowercase"
        case .sentence: return "sentence case"
        }
    }

    func apply(_ text: String) -> String {
        let lower = text.lowercased()
        switch self {
        case .lowercase:
            return lower
        case .sentence:
            return lower.capitalized
        }
    }
}

enum CaptionFont: String, Codable, CaseIterable, Identifiable {
    case serif
    case modern
    case script
    case typewriter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .serif: return "serif"
        case .modern: return "modern"
        case .script: return "script"
        case .typewriter: return "typewriter"
        }
    }

    /// Caveat runs small against the others at a shared point size.
    func previewFont(size: CGFloat = 17) -> UIFont {
        self == .script ? uiFont(size: size * 1.25) : uiFont(size: size)
    }

    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .serif:
            let base = UIFont.systemFont(ofSize: size, weight: .regular)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .modern:
            return UIFont.systemFont(ofSize: size, weight: .regular)
        case .script:
            if let caveat = UIFont(name: "Caveat-Regular", size: size) {
                return caveat
            }
            return UIFont(name: "Snell Roundhand", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .regular)
        case .typewriter:
            return UIFont(name: "AmericanTypewriter", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .regular)
        }
    }
}

enum Caption {
    /// Front strip custom text — short enough to look like a Polaroid caption.
    /// Date mode is not truncated to this length.
    static let maxLength = 20
    /// Back of the print — longer handwritten note.
    static let backMaxLength = 200

    private static let months = [
        "jan", "feb", "mar", "apr", "may", "jun",
        "jul", "aug", "sep", "oct", "nov", "dec",
    ]

    private static func pad2(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    private static var utcGregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    static func formatDate(
        _ date: Date,
        format: DateFormatOption,
        letterCase: DateCaseStyle = .lowercase,
        calendar: Calendar = utcGregorian
    ) -> String {
        let d = calendar.component(.day, from: date)
        let m = calendar.component(.month, from: date) - 1
        let y = calendar.component(.year, from: date)

        let raw: String
        switch format {
        case .long:
            raw = "\(d) \(months[m]) \(y)"
        case .short:
            raw = "\(pad2(m + 1)).\(pad2(d)).\(String(String(y).suffix(2)))"
        case .iso:
            raw = "\(y)-\(pad2(m + 1))-\(pad2(d))"
        }
        return letterCase.apply(raw)
    }

    static func truncateCaption(_ text: String, max: Int = maxLength) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= max { return trimmed }
        return String(trimmed.prefix(max))
    }

    static func truncateBackNote(_ text: String) -> String {
        truncateCaption(text, max: backMaxLength)
    }

    static func resolveCaptionText(
        mode: CaptionMode,
        dateFormat: DateFormatOption,
        dateCase: DateCaseStyle = .lowercase,
        customText: String = "",
        date: Date = Date()
    ) -> String {
        switch mode {
        case .blank:
            return ""
        case .custom:
            return truncateCaption(customText)
        case .date:
            return formatDate(date, format: dateFormat, letterCase: dateCase)
        }
    }

    static func parseISODate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
