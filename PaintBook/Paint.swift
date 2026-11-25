//
//  Paint.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import SwiftUI
import SwiftData

enum Sheen: String, Codable, CaseIterable, Identifiable {
    case flat = "Flat",
         matte = "Matte",
         eggshell = "Eggshell",
         satin = "Satin",
         semiGloss = "Semi-Gloss",
         gloss = "Gloss"

    var id: Self { self }
}

enum PaintBase: String, Codable, CaseIterable, Identifiable {
    case water = "Water-based", oil = "Oil-based"
    var id: Self { self }
}

@Model
final class Paint {
    var colorName: String = ""
    var brand: String = ""
    var sheen: Sheen = Sheen.eggshell
    var base: PaintBase = PaintBase.water
    var code: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now

    // Swatch stored as sRGB components (0...1)
    var swatchRed: Double = 1
    var swatchGreen: Double = 1
    var swatchBlue: Double = 1

    var room: Room?

    @Relationship(deleteRule: .cascade, inverse: \PaintPhoto.paint)
    var photos: [PaintPhoto] = []

    init() {}

    /// Not stored itself; reads and writes the RGB components above.
    var swatch: Color {
        get { swatchRGB.color }
        set { swatchRGB = RGB(newValue) }
    }

    var swatchRGB: RGB {
        get { RGB(red: swatchRed, green: swatchGreen, blue: swatchBlue) }
        set {
            swatchRed = newValue.red
            swatchGreen = newValue.green
            swatchBlue = newValue.blue
        }
    }

    /// Photos in the order they were added (SwiftData doesn't keep relationship order).
    var sortedPhotos: [PaintPhoto] {
        photos.sorted { $0.addedAt < $1.addedAt }
    }

    var displayName: String {
        colorName.isEmpty ? "Untitled Paint" : colorName
    }

    /// "Brand · Code", skipping whichever is empty.
    var subtitle: String {
        [brand, code].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var shareSummary: String {
        var lines = [displayName]
        if !subtitle.isEmpty { lines.append(subtitle) }
        lines.append("\(sheen.rawValue), \(base.rawValue)")
        lines.append("Color: \(swatchRGB.hex)")
        if let room { lines.append("Room: \(room.displayName)") }
        if !notes.isEmpty { lines.append(notes) }
        return lines.joined(separator: "\n")
    }

    /// A plain, thread-safe copy used for PDF export.
    var snapshot: PaintSnapshot {
        PaintSnapshot(
            name: displayName,
            subtitle: subtitle,
            finish: "\(sheen.rawValue) · \(base.rawValue)",
            room: room?.displayName,
            notes: notes,
            rgb: swatchRGB,
            photos: sortedPhotos.prefix(3).map(\.data)
        )
    }
}

@Model
final class PaintPhoto {
    @Attribute(.externalStorage) var data: Data = Data()
    var addedAt: Date = Date.now
    var paint: Paint?

    init(data: Data) {
        self.data = data
    }
}
