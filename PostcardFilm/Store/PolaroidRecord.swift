import Foundation

struct PolaroidRecord: Codable, Identifiable, Equatable {
    var id: String
    var createdAt: String
    var caption: String
    var captionMode: CaptionMode
    var captionFont: CaptionFont
    var captionHighlight: Bool
    /// Optional note on the reverse of the print.
    var backNote: String?
    /// Font used when rendering the reverse note.
    var backFont: CaptionFont

    var hasBackNote: Bool {
        !(backNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    init(
        id: String,
        createdAt: String,
        caption: String,
        captionMode: CaptionMode,
        captionFont: CaptionFont = .serif,
        captionHighlight: Bool = true,
        backNote: String? = nil,
        backFont: CaptionFont = .script
    ) {
        self.id = id
        self.createdAt = createdAt
        self.caption = caption
        self.captionMode = captionMode
        self.captionFont = captionFont
        self.captionHighlight = captionHighlight
        let trimmed = backNote.map { Caption.truncateBackNote($0) }
        self.backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
        self.backFont = backFont
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, caption, captionMode, captionFont, captionHighlight, backNote, backFont
        // Interim date/note schema — migrated on decode.
        case displayDate, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        captionFont = try container.decodeIfPresent(CaptionFont.self, forKey: .captionFont) ?? .serif
        captionHighlight = try container.decodeIfPresent(Bool.self, forKey: .captionHighlight) ?? true
        backFont = try container.decodeIfPresent(CaptionFont.self, forKey: .backFont) ?? .script

        let hasClassic = container.contains(.caption) || container.contains(.captionMode)
        let hasInterim = container.contains(.displayDate) || container.contains(.note)

        if hasClassic && !hasInterim {
            caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
            captionMode = try container.decodeIfPresent(CaptionMode.self, forKey: .captionMode) ?? .date
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
            captionMode = try container.decodeIfPresent(CaptionMode.self, forKey: .captionMode) ?? .date
            let rawBack = try container.decodeIfPresent(String.self, forKey: .backNote)
            let trimmed = rawBack.map { Caption.truncateBackNote($0) }
            backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(caption, forKey: .caption)
        try container.encode(captionMode, forKey: .captionMode)
        try container.encode(captionFont, forKey: .captionFont)
        try container.encode(captionHighlight, forKey: .captionHighlight)
        try container.encodeIfPresent(backNote, forKey: .backNote)
        try container.encode(backFont, forKey: .backFont)
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
        captionHighlight: Bool
    ) -> PolaroidIndex {
        PolaroidIndex(
            version: 1,
            items: index.items.map { item in
                guard item.id == id else { return item }
                var updated = item
                updated.caption = caption
                updated.captionMode = captionMode
                updated.captionFont = captionFont
                updated.captionHighlight = captionHighlight
                return updated
            }
        )
    }

    static func updateBackNote(
        in index: PolaroidIndex,
        id: String,
        backNote: String?,
        backFont: CaptionFont
    ) -> PolaroidIndex {
        PolaroidIndex(
            version: 1,
            items: index.items.map { item in
                guard item.id == id else { return item }
                var updated = item
                let trimmed = backNote.map { Caption.truncateBackNote($0) }
                updated.backNote = trimmed.flatMap { $0.isEmpty ? nil : $0 }
                updated.backFont = backFont
                return updated
            }
        )
    }

    static func parse(_ raw: String?) -> PolaroidIndex {
        guard let raw, let data = raw.data(using: .utf8) else {
            return .empty
        }
        do {
            let parsed = try JSONDecoder().decode(PolaroidIndex.self, from: data)
            return PolaroidIndex(version: 1, items: sortNewestFirst(parsed.items))
        } catch {
            return .empty
        }
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
