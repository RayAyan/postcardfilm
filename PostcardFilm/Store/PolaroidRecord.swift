import Foundation

struct PolaroidRecord: Codable, Identifiable, Equatable {
    var id: String
    var createdAt: String
    var caption: String
    var captionMode: CaptionMode
    var captionFont: CaptionFont
    var captionFontSize: CaptionFontSize
    var captionHighlight: Bool
    /// Letter case burned into the strip at capture / last reburn.
    var captionLetterCase: DateCaseStyle
    /// Date format burned into the strip at capture / last reburn. Settings must not rewrite this.
    var dateFormat: DateFormatOption
    /// Optional note on the reverse of the print.
    var backNote: String?
    /// Font used when rendering the reverse note.
    var backFont: CaptionFont
    /// Size used when rendering the reverse note.
    var backFontSize: CaptionFontSize
    /// Letter case applied when burning the reverse note.
    var backLetterCase: DateCaseStyle
    /// Emulsion drawn from the pack at capture. Old prints default to `onestep`.
    var filmStock: FilmStock
    /// Invisible expression strength (0.42…1.0). Missing → 1.0 (legacy full look).
    var filmStrength: Double

    var hasBackNote: Bool {
        !(backNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    init(
        id: String,
        createdAt: String,
        caption: String,
        captionMode: CaptionMode,
        captionFont: CaptionFont = .serif,
        captionFontSize: CaptionFontSize = .medium,
        captionHighlight: Bool = true,
        captionLetterCase: DateCaseStyle = .lowercase,
        dateFormat: DateFormatOption = .long,
        backNote: String? = nil,
        backFont: CaptionFont = .script,
        backFontSize: CaptionFontSize = .medium,
        backLetterCase: DateCaseStyle = .lowercase,
        filmStock: FilmStock = .onestep,
        filmStrength: Double = FilmExpression.legacyDefault
    ) {
        self.id = id
        self.createdAt = createdAt
        self.caption = caption
        self.captionMode = captionMode
        self.captionFont = captionFont
        self.captionFontSize = captionFontSize
        self.captionHighlight = captionHighlight
        self.captionLetterCase = captionLetterCase
        self.dateFormat = dateFormat
        let trimmed = backNote.map { Caption.truncateBackNote($0) }
        self.backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
        self.backFont = backFont
        self.backFontSize = backFontSize
        self.backLetterCase = backLetterCase
        self.filmStock = filmStock
        self.filmStrength = Self.clampStrength(filmStrength)
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, caption, captionMode, captionFont, captionFontSize, captionHighlight
        case captionLetterCase, dateFormat
        case backNote, backFont, backFontSize, backLetterCase, filmStock, filmStrength
        // Interim date/note schema — migrated on decode.
        case displayDate, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        // Lossless string-enum decode: unknown / corrupt values must not wipe the gallery.
        captionFont = Self.decodeStringEnum(container, forKey: .captionFont, default: .serif)
        captionFontSize = Self.decodeStringEnum(container, forKey: .captionFontSize, default: .medium)
        captionHighlight = try container.decodeIfPresent(Bool.self, forKey: .captionHighlight) ?? true
        captionLetterCase = Self.decodeStringEnum(container, forKey: .captionLetterCase, default: .lowercase)
        dateFormat = Self.decodeStringEnum(container, forKey: .dateFormat, default: .long)
        backFont = Self.decodeStringEnum(container, forKey: .backFont, default: .script)
        backFontSize = Self.decodeStringEnum(container, forKey: .backFontSize, default: .medium)
        backLetterCase = Self.decodeStringEnum(container, forKey: .backLetterCase, default: .lowercase)
        filmStock = Self.decodeStringEnum(container, forKey: .filmStock, default: .onestep)
        filmStrength = Self.clampStrength(
            try container.decodeIfPresent(Double.self, forKey: .filmStrength) ?? FilmExpression.legacyDefault
        )

        let hasClassic = container.contains(.caption) || container.contains(.captionMode)
        let hasInterim = container.contains(.displayDate) || container.contains(.note)

        if hasClassic && !hasInterim {
            caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
            captionMode = Self.decodeStringEnum(container, forKey: .captionMode, default: .date)
            let rawBack = try container.decodeIfPresent(String.self, forKey: .backNote)
            let trimmed = rawBack.map { Caption.truncateBackNote($0) }
            backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
        } else if hasInterim {
            let displayDate = try container.decodeIfPresent(String.self, forKey: .displayDate)
            let note = try container.decodeIfPresent(String.self, forKey: .note)
            let trimmedNote = note.map { Caption.truncateCaption($0) }.flatMap { $0.isEmpty ? nil : $0 }
            let hasDate = displayDate != nil
            let hasNote = trimmedNote != nil

            switch (hasDate, hasNote) {
            case (true, false):
                captionMode = .date
                if let date = Caption.parseISODate(displayDate) {
                    caption = Caption.formatDate(date, format: .long, letterCase: .lowercase)
                } else {
                    caption = ""
                }
                backNote = nil
            case (false, true):
                captionMode = .custom
                caption = trimmedNote!
                backNote = nil
            case (true, true):
                captionMode = .date
                if let date = Caption.parseISODate(displayDate) {
                    caption = Caption.formatDate(date, format: .long, letterCase: .lowercase)
                } else {
                    caption = ""
                }
                backNote = Caption.truncateBackNote(trimmedNote!)
            case (false, false):
                captionMode = .blank
                caption = ""
                backNote = nil
            }
            // Prefer explicit backNote if somehow present alongside interim fields.
            if let rawBack = try container.decodeIfPresent(String.self, forKey: .backNote) {
                let t = Caption.truncateBackNote(rawBack)
                if !t.isEmpty { backNote = t }
            }
        } else {
            caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
            captionMode = Self.decodeStringEnum(container, forKey: .captionMode, default: .date)
            let rawBack = try container.decodeIfPresent(String.self, forKey: .backNote)
            let trimmed = rawBack.map { Caption.truncateBackNote($0) }
            backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    /// Decodes a string-backed enum without throwing on unknown raw values.
    private static func decodeStringEnum<T: RawRepresentable>(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        default defaultValue: T
    ) -> T where T.RawValue == String {
        guard let raw = try? container.decodeIfPresent(String.self, forKey: key),
              let value = T(rawValue: raw)
        else {
            return defaultValue
        }
        return value
    }

    private static func clampStrength(_ value: Double) -> Double {
        guard value.isFinite else { return FilmExpression.legacyDefault }
        return min(FilmExpression.maximumStrength, max(0, value))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(caption, forKey: .caption)
        try container.encode(captionMode, forKey: .captionMode)
        try container.encode(captionFont, forKey: .captionFont)
        try container.encode(captionFontSize, forKey: .captionFontSize)
        try container.encode(captionHighlight, forKey: .captionHighlight)
        try container.encode(captionLetterCase, forKey: .captionLetterCase)
        try container.encode(dateFormat, forKey: .dateFormat)
        try container.encodeIfPresent(backNote, forKey: .backNote)
        try container.encode(backFont, forKey: .backFont)
        try container.encode(backFontSize, forKey: .backFontSize)
        try container.encode(backLetterCase, forKey: .backLetterCase)
        try container.encode(filmStock, forKey: .filmStock)
        try container.encode(filmStrength, forKey: .filmStrength)
    }
}

struct PolaroidIndex: Codable, Equatable {
    var version: Int
    var items: [PolaroidRecord]

    static let empty = PolaroidIndex(version: 1, items: [])
}

enum PolaroidIndexLogic {
    static func sortNewestFirst(_ items: [PolaroidRecord]) -> [PolaroidRecord] {
        items.sorted {
            ($0.createdAt) > ($1.createdAt)
        }
    }

    static func add(to index: PolaroidIndex, record: PolaroidRecord) -> PolaroidIndex {
        let without = index.items.filter { $0.id != record.id }
        return PolaroidIndex(version: 1, items: sortNewestFirst([record] + without))
    }

    static func remove(from index: PolaroidIndex, id: String) -> PolaroidIndex {
        PolaroidIndex(version: 1, items: index.items.filter { $0.id != id })
    }

    static func find(in index: PolaroidIndex, id: String) -> PolaroidRecord? {
        index.items.first { $0.id == id }
    }

    static func updateCaption(
        in index: PolaroidIndex,
        id: String,
        caption: String,
        captionMode: CaptionMode,
        captionFont: CaptionFont,
        captionFontSize: CaptionFontSize,
        captionHighlight: Bool,
        captionLetterCase: DateCaseStyle,
        dateFormat: DateFormatOption
    ) -> PolaroidIndex {
        PolaroidIndex(
            version: 1,
            items: index.items.map { item in
                guard item.id == id else { return item }
                var updated = item
                updated.caption = caption
                updated.captionMode = captionMode
                updated.captionFont = captionFont
                updated.captionFontSize = captionFontSize
                updated.captionHighlight = captionHighlight
                updated.captionLetterCase = captionLetterCase
                updated.dateFormat = dateFormat
                return updated
            }
        )
    }

    static func updateBackNote(
        in index: PolaroidIndex,
        id: String,
        backNote: String?,
        backFont: CaptionFont,
        backFontSize: CaptionFontSize = .medium,
        backLetterCase: DateCaseStyle = .lowercase
    ) -> PolaroidIndex {
        PolaroidIndex(
            version: 1,
            items: index.items.map { item in
                guard item.id == id else { return item }
                var updated = item
                let trimmed = backNote.map { Caption.truncateBackNote($0) }
                updated.backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
                updated.backFont = backFont
                updated.backFontSize = backFontSize
                updated.backLetterCase = backLetterCase
                return updated
            }
        )
    }

    static func parse(_ raw: String?) -> PolaroidIndex {
        guard let raw, let data = raw.data(using: .utf8) else {
            return .empty
        }
        // Prefer full decode when the file is healthy.
        if let parsed = try? JSONDecoder().decode(PolaroidIndex.self, from: data) {
            return PolaroidIndex(version: 1, items: sortNewestFirst(parsed.items))
        }
        // One bad row must not empty the gallery — decode items individually.
        return parseItemsLeniently(from: data)
    }

    /// Recovers as many rows as possible when the whole-index decode fails.
    static func parseItemsLeniently(from data: Data) -> PolaroidIndex {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let arr = root["items"] as? [Any]
        else {
            return .empty
        }
        var items: [PolaroidRecord] = []
        let decoder = JSONDecoder()
        for element in arr {
            guard JSONSerialization.isValidJSONObject(element),
                  let itemData = try? JSONSerialization.data(withJSONObject: element),
                  let record = try? decoder.decode(PolaroidRecord.self, from: itemData)
            else {
                continue
            }
            items.append(record)
        }
        return PolaroidIndex(version: 1, items: sortNewestFirst(items))
    }

    /// Builds placeholder records for on-disk print folders missing from the index.
    static func recoverMissingRecords(
        existing: [PolaroidRecord],
        folderIDsWithPNG: [(id: String, createdAt: String)]
    ) -> [PolaroidRecord] {
        let known = Set(existing.map(\.id))
        var recovered = existing
        for entry in folderIDsWithPNG where !known.contains(entry.id) {
            recovered.append(
                PolaroidRecord(
                    id: entry.id,
                    createdAt: entry.createdAt,
                    caption: "",
                    captionMode: .blank,
                    filmStock: .onestep
                )
            )
        }
        return sortNewestFirst(recovered)
    }

    static func serialize(_ index: PolaroidIndex) -> String {
        let sorted = PolaroidIndex(version: 1, items: sortNewestFirst(index.items))
        let data = (try? JSONEncoder().encode(sorted)) ?? Data()
        return String(data: data, encoding: .utf8) ?? #"{"version":1,"items":[]}"#
    }
}

/// Typed navigation so gallery opens never re-run the developing overlay.
enum PrintRoute: Hashable {
    case captured(id: String)
    case saved(id: String)

    var id: String {
        switch self {
        case .captured(let id), .saved(let id): return id
        }
    }

    var openedFromCapture: Bool {
        if case .captured = self { return true }
        return false
    }
}
