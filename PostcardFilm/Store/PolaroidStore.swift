import Foundation
import UIKit

@MainActor
final class PolaroidStore: ObservableObject {
    @Published private(set) var items: [PolaroidRecord] = []

    private let fileManager = FileManager.default

    private var rootURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("polaroids", isDirectory: true)
    }

    private var indexURL: URL {
        rootURL.appendingPathComponent("index.json")
    }

    func directoryURL(for id: String) -> URL {
        rootURL.appendingPathComponent(id, isDirectory: true)
    }

    func originalURL(for id: String) -> URL {
        directoryURL(for: id).appendingPathComponent("original.jpg")
    }

    func polaroidURL(for id: String) -> URL {
        directoryURL(for: id).appendingPathComponent("polaroid.png")
    }

    func backURL(for id: String) -> URL {
        directoryURL(for: id).appendingPathComponent("back.png")
    }

    func reload() {
        var index = readIndex()
        let repaired = repairIndexFromDisk(index)
        if repaired.items.map(\.id) != index.items.map(\.id) {
            index = repaired
            try? writeIndex(index)
        }
        items = index.items
    }

    /// If index.json is empty/corrupt but print folders still exist, bring them back.
    private func repairIndexFromDisk(_ index: PolaroidIndex) -> PolaroidIndex {
        let diskEntries = scanPrintFolders()
        guard !diskEntries.isEmpty else { return index }
        let merged = PolaroidIndexLogic.recoverMissingRecords(
            existing: index.items,
            folderIDsWithPNG: diskEntries
        )
        return PolaroidIndex(version: 1, items: merged)
    }

    /// Folders under Documents/polaroids that still have a polaroid.png.
    private func scanPrintFolders() -> [(id: String, createdAt: String)] {
        guard fileManager.fileExists(atPath: rootURL.path),
              let urls = try? fileManager.contentsOfDirectory(
                  at: rootURL,
                  includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                  options: [.skipsHiddenFiles]
              )
        else {
            return []
        }

        var found: [(id: String, createdAt: String)] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard values?.isDirectory == true else { continue }
            let id = url.lastPathComponent
            guard id != "index.json" else { continue }
            let png = polaroidURL(for: id)
            guard fileManager.fileExists(atPath: png.path) else { continue }
            let date = values?.contentModificationDate ?? Date()
            found.append((id: id, createdAt: Caption.isoString(from: date)))
        }
        return found
    }

    func polaroid(id: String) -> PolaroidRecord? {
        PolaroidIndexLogic.find(in: loadIndex(), id: id)
    }

    @discardableResult
    func create(
        id: String,
        caption: String,
        captionMode: CaptionMode,
        captionFont: CaptionFont = .serif,
        captionFontSize: CaptionFontSize = .medium,
        captionHighlight: Bool = true,
        captionLetterCase: DateCaseStyle = .lowercase,
        dateFormat: DateFormatOption = .long,
        backNote: String? = nil,
        filmStock: FilmStock = .onestep,
        filmStrength: Double = FilmExpression.legacyDefault,
        originalJPEG: Data,
        polaroidPNG: Data,
        backPNG: Data? = nil
    ) throws -> PolaroidRecord {
        try ensureRoot()
        let dir = directoryURL(for: id)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        try originalJPEG.write(to: originalURL(for: id), options: .atomic)
        try polaroidPNG.write(to: polaroidURL(for: id), options: .atomic)

        let trimmedBack = backNote.map { Caption.truncateBackNote($0) }.flatMap { $0.isEmpty ? nil : $0 }
        if let trimmedBack, let backPNG {
            try backPNG.write(to: backURL(for: id), options: .atomic)
        } else {
            try? fileManager.removeItem(at: backURL(for: id))
        }

        let record = PolaroidRecord(
            id: id,
            createdAt: Caption.isoString(from: Date()),
            caption: caption,
            captionMode: captionMode,
            captionFont: captionFont,
            captionFontSize: captionFontSize,
            captionHighlight: captionHighlight,
            captionLetterCase: captionLetterCase,
            dateFormat: dateFormat,
            backNote: trimmedBack,
            filmStock: filmStock,
            filmStrength: filmStrength
        )
        var index = loadIndex()
        index = PolaroidIndexLogic.add(to: index, record: record)
        try writeIndex(index)
        items = index.items
        return record
    }

    func delete(id: String) throws {
        let dir = directoryURL(for: id)
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
        var index = loadIndex()
        index = PolaroidIndexLogic.remove(from: index, id: id)
        try writeIndex(index)
        items = index.items
    }

    func delete(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        var index = loadIndex()
        for id in ids {
            let dir = directoryURL(for: id)
            if fileManager.fileExists(atPath: dir.path) {
                try? fileManager.removeItem(at: dir)
            }
            index = PolaroidIndexLogic.remove(from: index, id: id)
        }
        try writeIndex(index)
        items = index.items
    }

    func updateCaption(
        id: String,
        caption: String,
        captionMode: CaptionMode,
        captionFont: CaptionFont,
        captionFontSize: CaptionFontSize,
        captionHighlight: Bool,
        captionLetterCase: DateCaseStyle,
        dateFormat: DateFormatOption,
        polaroidPNG: Data
    ) throws {
        try polaroidPNG.write(to: polaroidURL(for: id), options: .atomic)
        var index = loadIndex()
        index = PolaroidIndexLogic.updateCaption(
            in: index,
            id: id,
            caption: caption,
            captionMode: captionMode,
            captionFont: captionFont,
            captionFontSize: captionFontSize,
            captionHighlight: captionHighlight,
            captionLetterCase: captionLetterCase,
            dateFormat: dateFormat
        )
        try writeIndex(index)
        items = index.items
    }

    /// Writes or clears the reverse note and its rendered PNG. Never recreates the photo directory.
    func updateBackNote(
        id: String,
        backNote: String?,
        backFont: CaptionFont = .script,
        backFontSize: CaptionFontSize = .medium,
        backLetterCase: DateCaseStyle = .lowercase,
        backPNG: Data?
    ) throws {
        let trimmed = backNote.map { Caption.truncateBackNote($0) }.flatMap { $0.isEmpty ? nil : $0 }
        if let trimmed, let backPNG {
            try backPNG.write(to: backURL(for: id), options: .atomic)
            _ = trimmed
        } else {
            try? fileManager.removeItem(at: backURL(for: id))
        }
        var index = loadIndex()
        index = PolaroidIndexLogic.updateBackNote(
            in: index,
            id: id,
            backNote: trimmed,
            backFont: backFont,
            backFontSize: backFontSize,
            backLetterCase: backLetterCase
        )
        try writeIndex(index)
        items = index.items
    }

    private func ensureRoot() throws {
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
    }

    /// Raw index.json read — may be empty if corrupt.
    private func readIndex() -> PolaroidIndex {
        guard let data = try? Data(contentsOf: indexURL),
              let raw = String(data: data, encoding: .utf8)
        else {
            return .empty
        }
        return PolaroidIndexLogic.parse(raw)
    }

    /// Index merged with any on-disk print folders still present.
    private func loadIndex() -> PolaroidIndex {
        repairIndexFromDisk(readIndex())
    }

    private func writeIndex(_ index: PolaroidIndex) throws {
        try ensureRoot()
        let raw = PolaroidIndexLogic.serialize(index)
        try raw.data(using: .utf8)?.write(to: indexURL, options: .atomic)
    }
}
