import Foundation
import SwiftUI

struct AppSettings: Equatable {
    var captionMode: CaptionMode = .date
    var dateFormat: DateFormatOption = .long
    var dateCase: DateCaseStyle = .lowercase
    var customDefault: String = ""
    var saveOnCapture: Bool = false
    var captionFont: CaptionFont = .serif
    var captionFontSize: CaptionFontSize = .medium
    var captionHighlight: Bool = true

    static let `default` = AppSettings()

    /// Product rule: caption/date defaults apply to the *next* capture only.
    static func settingsAffectExistingPrints() -> Bool { false }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard
    private let key = "postcard.film.settings.v1"

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StoredSettings.self, from: data)
        {
            settings = decoded.asAppSettings()
        } else {
            settings = .default
        }
    }

    func update(_ patch: (inout AppSettings) -> Void) {
        var next = settings
        patch(&next)
        settings = next
    }

    private func persist() {
        let stored = StoredSettings(from: settings)
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: key)
        }
    }
}

private struct StoredSettings: Codable {
    var captionMode: String
    var dateFormat: String
    var dateCase: String?
    var customDefault: String
    var saveOnCapture: Bool
    var captionFont: String?
    var captionFontSize: String?
    var captionHighlight: Bool?

    init(from settings: AppSettings) {
        captionMode = settings.captionMode.rawValue
        dateFormat = settings.dateFormat.rawValue
        dateCase = settings.dateCase.rawValue
        customDefault = settings.customDefault
        saveOnCapture = settings.saveOnCapture
        captionFont = settings.captionFont.rawValue
        captionFontSize = settings.captionFontSize.rawValue
        captionHighlight = settings.captionHighlight
    }

    func asAppSettings() -> AppSettings {
        AppSettings(
            captionMode: CaptionMode(rawValue: captionMode) ?? .date,
            dateFormat: DateFormatOption(rawValue: dateFormat) ?? .long,
            dateCase: DateCaseStyle(rawValue: dateCase ?? "") ?? .lowercase,
            customDefault: customDefault,
            saveOnCapture: saveOnCapture,
            captionFont: CaptionFont(rawValue: captionFont ?? "") ?? .serif,
            captionFontSize: CaptionFontSize(rawValue: captionFontSize ?? "") ?? .medium,
            captionHighlight: captionHighlight ?? true
        )
    }
}

extension AppSettings {
    /// Decode persisted settings JSON (used by tests for missing-key defaults).
    static func fromStoredJSON(_ data: Data) throws -> AppSettings {
        try JSONDecoder().decode(StoredSettings.self, from: data).asAppSettings()
    }
}

enum AppVersion {
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var label: String {
        "\(Brand.wordmark) \(marketing)"
    }

    static let credit = Brand.credit
}
