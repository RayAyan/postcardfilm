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
        items = readIndex().items
    }

    func polaroid(id: String) -> PolaroidRecord? {
        PolaroidIndexLogic.find(in: readIndex(), id: id)
    }

    @discardableResult
    func create(
        id: String,
        caption: String,
        captionMode: CaptionMode,
        captionFont: CaptionFont = .serif,
        captionHighlight: Bool = true,
        backNote: String? = nil,
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
            captionHighlight: captionHighlight,
            backNote: trimmedBack
        )
        var index = readIndex()
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
        var index = readIndex()
        index = PolaroidIndexLogic.remove(from: index, id: id)
        try writeIndex(index)
        items = index.items
    }

    func delete(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        var index = readIndex()
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
        captionHighlight: Bool,
        polaroidPNG: Data
    ) throws {
        try polaroidPNG.write(to: polaroidURL(for: id), options: .atomic)
        var index = readIndex()
        index = PolaroidIndexLogic.updateCaption(
            in: index,
            id: id,
            caption: caption,
            captionMode: captionMode,
            captionFont: captionFont,
            captionHighlight: captionHighlight
        )
        try writeIndex(index)
        items = index.items
    }

    /// Writes or clears the reverse note and its rendered PNG. Never recreates the photo directory.
    func updateBackNote(
        id: String,
        backNote: String?,
        backFont: CaptionFont = .script,
        backPNG: Data?
    ) throws {
        let trimmed = backNote.map { Caption.truncateBackNote($0) }.flatMap { $0.isEmpty ? nil : $0 }
        if let trimmed, let backPNG {
            try backPNG.write(to: backURL(for: id), options: .atomic)
            _ = trimmed
        } else {
            try? fileManager.removeItem(at: backURL(for: id))
        }
        var index = readIndex()
        index = PolaroidIndexLogic.updateBackNote(
            in: index,
            id: id,
            backNote: trimmed,
            backFont: backFont
        )
        try writeIndex(index)
        items = index.items
    }

    private func ensureRoot() throws {
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
    }

    private func readIndex() -> PolaroidIndex {
        guard let data = try? Data(contentsOf: indexURL),
              let raw = String(data: data, encoding: .utf8)
        else {
            return .empty
        }
        return PolaroidIndexLogic.parse(raw)
    }

    private func writeIndex(_ index: PolaroidIndex) throws {
        try ensureRoot()
        let raw = PolaroidIndexLogic.serialize(index)
        try raw.data(using: .utf8)?.write(to: indexURL, options: .atomic)
    }
}
