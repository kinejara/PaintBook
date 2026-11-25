//
//  LibraryBackup.swift
//  PaintBook
//
//  Whole-library backup/restore (JSON) and spreadsheet export (CSV).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum LibraryBackup {
    static let currentVersion = 1

    enum BackupError: LocalizedError {
        case unreadable
        case newerVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                "This file isn't a PaintBook backup."
            case .newerVersion(let version):
                "This backup was made by a newer version of PaintBook (format \(version)). Update the app to restore it."
            }
        }
    }

    // MARK: Backup

    static func makeBackup(from context: ModelContext) throws -> Data {
        let rooms = try context.fetch(FetchDescriptor<Room>(sortBy: [SortDescriptor(\.name)]))
        let paints = try context.fetch(FetchDescriptor<Paint>(sortBy: [SortDescriptor(\.createdAt)]))

        // Rooms have no stable ID of their own, so give each one for this file.
        var roomIDs: [PersistentIdentifier: String] = [:]
        let roomRecords = rooms.map { room -> RoomRecord in
            let id = UUID().uuidString
            roomIDs[room.persistentModelID] = id
            return RoomRecord(id: id, name: room.name, createdAt: room.createdAt)
        }

        let paintRecords = paints.map { paint in
            PaintRecord(
                colorName: paint.colorName,
                brand: paint.brand,
                sheen: paint.sheen.rawValue,
                base: paint.base.rawValue,
                code: paint.code,
                notes: paint.notes,
                createdAt: paint.createdAt,
                red: paint.swatchRed,
                green: paint.swatchGreen,
                blue: paint.swatchBlue,
                roomID: paint.room.flatMap { roomIDs[$0.persistentModelID] },
                photos: paint.sortedPhotos.map { PhotoRecord(data: $0.data, addedAt: $0.addedAt) }
            )
        }

        let backup = BackupFile(version: currentVersion, exportedAt: .now,
                                rooms: roomRecords, paints: paintRecords)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Checks the data is a backup this version can read, without changing anything.
    static func inspect(_ data: Data) throws -> (paints: Int, rooms: Int) {
        let backup = try decode(data)
        return (backup.paints.count, backup.rooms.count)
    }

    /// Adds the backup's rooms and paints. With `replacing`, deletes everything first.
    @discardableResult
    static func restore(_ data: Data, into context: ModelContext, replacing: Bool) throws -> (paints: Int, rooms: Int) {
        let backup = try decode(data)

        if replacing {
            for paint in try context.fetch(FetchDescriptor<Paint>()) { context.delete(paint) }
            for room in try context.fetch(FetchDescriptor<Room>()) { context.delete(room) }
        }

        // Reuse existing rooms with the same name when adding, so restoring twice doesn't duplicate them.
        var roomsByName: [String: Room] = [:]
        if !replacing {
            for room in try context.fetch(FetchDescriptor<Room>()) { roomsByName[room.name] = room }
        }
        var roomsByID: [String: Room] = [:]
        var newRooms = 0
        for record in backup.rooms {
            if let existing = roomsByName[record.name] {
                roomsByID[record.id] = existing
            } else {
                let room = Room(name: record.name)
                room.createdAt = record.createdAt
                context.insert(room)
                roomsByName[record.name] = room
                roomsByID[record.id] = room
                newRooms += 1
            }
        }

        for record in backup.paints {
            let paint = Paint()
            context.insert(paint)
            paint.colorName = record.colorName
            paint.brand = record.brand
            paint.sheen = Sheen(rawValue: record.sheen) ?? .eggshell
            paint.base = PaintBase(rawValue: record.base) ?? .water
            paint.code = record.code
            paint.notes = record.notes
            paint.createdAt = record.createdAt
            paint.swatchRed = record.red
            paint.swatchGreen = record.green
            paint.swatchBlue = record.blue
            paint.room = record.roomID.flatMap { roomsByID[$0] }
            for photoRecord in record.photos {
                let photo = PaintPhoto(data: photoRecord.data)
                photo.addedAt = photoRecord.addedAt
                paint.photos.append(photo)
            }
        }

        try context.save()
        return (backup.paints.count, newRooms)
    }

    private static func decode(_ data: Data) throws -> BackupFile {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else {
            // Distinguish "newer format" from "not a backup at all".
            if let header = try? JSONDecoder().decode(VersionHeader.self, from: data),
               header.version > currentVersion {
                throw BackupError.newerVersion(header.version)
            }
            throw BackupError.unreadable
        }
        guard backup.version <= currentVersion else { throw BackupError.newerVersion(backup.version) }
        return backup
    }

    // MARK: Spreadsheet

    static func makeCSV(from paints: [Paint]) -> String {
        let header = ["Name", "Brand", "Code", "Sheen", "Base", "Color", "Room", "Notes", "Added"]
        let dateFormat = Date.ISO8601FormatStyle().year().month().day()
        let rows = paints.map { paint in
            [paint.colorName, paint.brand, paint.code, paint.sheen.rawValue, paint.base.rawValue,
             paint.swatchRGB.hex, paint.room?.name ?? "", paint.notes,
             paint.createdAt.formatted(dateFormat)]
        }
        return ([header] + rows)
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field when it contains a comma, quote or line break (RFC 4180).
    nonisolated static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - File format

private nonisolated struct VersionHeader: Decodable {
    var version: Int
}

private nonisolated struct BackupFile: Codable {
    var version: Int
    var exportedAt: Date
    var rooms: [RoomRecord]
    var paints: [PaintRecord]
}

private nonisolated struct RoomRecord: Codable {
    var id: String
    var name: String
    var createdAt: Date
}

private nonisolated struct PaintRecord: Codable {
    var colorName: String
    var brand: String
    var sheen: String
    var base: String
    var code: String
    var notes: String
    var createdAt: Date
    var red: Double
    var green: Double
    var blue: Double
    var roomID: String?
    var photos: [PhotoRecord]
}

private nonisolated struct PhotoRecord: Codable {
    var data: Data
    var addedAt: Date
}

// MARK: - Export document

/// Bytes handed to `.fileExporter`, used for both backups and spreadsheets.
nonisolated struct ExportFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
