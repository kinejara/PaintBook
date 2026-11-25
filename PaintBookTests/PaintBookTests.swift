//
//  PaintBookTests.swift
//  PaintBookTests
//
//  Created by Jorge Villanueva on 11/13/26.
//

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SwiftData
import SwiftUI
@testable import PaintBook

// MARK: - Colour

struct ColorMathTests {
    @Test func hexFormatting() {
        #expect(RGB(red: 1, green: 0, blue: 0).hex == "#FF0000")
        #expect(RGB(red: 0, green: 0.5, blue: 1).hex == "#0080FF")
        #expect(RGB(red: 1.2, green: -0.1, blue: 0).hex == "#FF0000") // clamps out-of-range values
    }

    @Test func distanceIsZeroForSameColorAndLargeForOpposites() {
        let white = RGB(red: 1, green: 1, blue: 1)
        let black = RGB(red: 0, green: 0, blue: 0)
        #expect(white.distance(to: white) < 0.001)
        #expect(white.distance(to: black) > 99) // L* spans 0...100
    }

    @Test func nearbyColorsRankCloserThanDifferentOnes() {
        let navy = RGB(red: 0.18, green: 0.23, blue: 0.31)
        let almostNavy = RGB(red: 0.19, green: 0.23, blue: 0.32)
        let red = RGB(red: 0.8, green: 0.1, blue: 0.1)
        #expect(navy.distance(to: almostNavy) < navy.distance(to: red))
        #expect(MatchQuality(distance: navy.distance(to: almostNavy)) == .nearlyIdentical)
    }

    @Test func colorRoundTripsThroughPaint() {
        let paint = Paint()
        paint.swatch = Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6)
        #expect(abs(paint.swatchRed - 0.2) < 0.01)
        #expect(abs(paint.swatchGreen - 0.4) < 0.01)
        #expect(abs(paint.swatchBlue - 0.6) < 0.01)
    }
}

// MARK: - Image sampling

struct ImageSamplingTests {
    /// 20×10 image: top half red, bottom half blue.
    private func makeImage() throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 20, height: 10, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: space,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // Core Graphics origin is bottom-left, so y 5...10 is the top half.
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 5, width: 20, height: 5))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 5))
        return try #require(context.makeImage())
    }

    @Test func samplesTheTappedArea() throws {
        let image = try makeImage()
        let top = try #require(ImageLoader.averageColor(in: image, at: CGPoint(x: 10, y: 1), radius: 1))
        let bottom = try #require(ImageLoader.averageColor(in: image, at: CGPoint(x: 10, y: 8), radius: 1))
        #expect(top.red > 0.95 && top.blue < 0.05)
        #expect(bottom.blue > 0.95 && bottom.red < 0.05)
    }

    @Test func ignoresPixelsOutsideTheImage() throws {
        let image = try makeImage()
        let corner = try #require(ImageLoader.averageColor(in: image, at: CGPoint(x: 0, y: 0), radius: 3))
        #expect(corner.red > 0.95) // transparent area outside the edge isn't averaged in
    }

    @Test func decodesEncodedImageData() throws {
        let image = try makeImage()
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))

        let decoded = try #require(ImageLoader.cgImage(from: data as Data, maxPixelSize: 100))
        #expect(decoded.width == 20 && decoded.height == 10)
    }
}

// MARK: - Models

@MainActor
struct ModelTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Paint.self, PaintPhoto.self, Room.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test func deletingARoomKeepsItsPaints() throws {
        let context = try makeContext()
        let room = Room(name: "Kitchen")
        let paint = Paint()
        paint.colorName = "Naval"
        context.insert(room)
        context.insert(paint)
        paint.room = room
        try context.save()
        #expect(room.paints.count == 1)

        context.delete(room)
        try context.save()

        let paints = try context.fetch(FetchDescriptor<Paint>())
        #expect(paints.count == 1)
        #expect(paints.first?.room == nil)
    }

    @Test func deletingAPaintDeletesItsPhotos() throws {
        let context = try makeContext()
        let paint = Paint()
        context.insert(paint)
        paint.photos.append(PaintPhoto(data: Data([1, 2, 3])))
        paint.photos.append(PaintPhoto(data: Data([4, 5, 6])))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<PaintPhoto>()) == 2)

        context.delete(paint)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<PaintPhoto>()) == 0)
    }

    @Test func summariesSkipEmptyFields() {
        let paint = Paint()
        paint.colorName = "Chantilly Lace"
        paint.code = "OC-65"
        #expect(paint.subtitle == "OC-65")
        #expect(!paint.shareSummary.contains("Room:"))
        #expect(Paint().displayName == "Untitled Paint")
    }
}

// MARK: - Backup, CSV and sorting

@MainActor
struct BackupTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Paint.self, PaintPhoto.self, Room.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func seed(_ context: ModelContext) throws {
        let kitchen = Room(name: "Kitchen")
        context.insert(kitchen)
        let naval = Paint()
        context.insert(naval)
        naval.colorName = "Naval"
        naval.brand = "Sherwin-Williams"
        naval.sheen = .satin
        naval.swatchRGB = RGB(red: 0.18, green: 0.23, blue: 0.31)
        naval.room = kitchen
        naval.photos.append(PaintPhoto(data: Data([1, 2, 3])))
        let white = Paint()
        context.insert(white)
        white.colorName = "Chantilly Lace"
        try context.save()
    }

    @Test func backupRoundTripsEverything() throws {
        let source = try makeContext()
        try seed(source)
        let data = try LibraryBackup.makeBackup(from: source)

        let destination = try makeContext()
        let counts = try LibraryBackup.restore(data, into: destination, replacing: false)
        #expect(counts.paints == 2 && counts.rooms == 1)

        let paints = try destination.fetch(FetchDescriptor<Paint>())
        let naval = try #require(paints.first { $0.colorName == "Naval" })
        #expect(naval.brand == "Sherwin-Williams")
        #expect(naval.sheen == .satin)
        #expect(naval.swatchRGB.hex == RGB(red: 0.18, green: 0.23, blue: 0.31).hex)
        #expect(naval.room?.name == "Kitchen")
        #expect(naval.photos.first?.data == Data([1, 2, 3]))
    }

    @Test func addingReusesRoomsAndReplacingClearsFirst() throws {
        let context = try makeContext()
        try seed(context)
        let data = try LibraryBackup.makeBackup(from: context)

        try LibraryBackup.restore(data, into: context, replacing: false)
        #expect(try context.fetchCount(FetchDescriptor<Paint>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<Room>()) == 1) // same-named room reused

        try LibraryBackup.restore(data, into: context, replacing: true)
        #expect(try context.fetchCount(FetchDescriptor<Paint>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Room>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PaintPhoto>()) == 1)
    }

    @Test func rejectsFilesThatAreNotBackups() {
        #expect(throws: LibraryBackup.BackupError.self) {
            try LibraryBackup.inspect(Data("{\"hello\": 1}".utf8))
        }
        #expect(throws: LibraryBackup.BackupError.self) {
            try LibraryBackup.inspect(Data("{\"version\": 99}".utf8))
        }
    }

    @Test func csvQuotesFieldsThatNeedIt() throws {
        #expect(LibraryBackup.csvField("plain") == "plain")
        #expect(LibraryBackup.csvField("a, b") == "\"a, b\"")
        #expect(LibraryBackup.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(LibraryBackup.csvField("two\nlines") == "\"two\nlines\"")

        let context = try makeContext()
        try seed(context)
        let csv = LibraryBackup.makeCSV(from: try context.fetch(FetchDescriptor<Paint>()))
        let lines = csv.split(separator: "\r\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "Name,Brand,Code,Sheen,Base,Color,Room,Notes,Added")
    }

    @Test func sortsByRoomWithUnassignedLast() throws {
        let context = try makeContext()
        try seed(context)
        let sorted = PaintSort.room.sorted(try context.fetch(FetchDescriptor<Paint>()))
        #expect(sorted.map(\.colorName) == ["Naval", "Chantilly Lace"])
        let byName = PaintSort.name.sorted(sorted)
        #expect(byName.map(\.colorName) == ["Chantilly Lace", "Naval"])
    }
}

// MARK: - PDF export

@MainActor
struct PDFExportTests {
    @Test func paginatesThreePaintsPerPage() throws {
        let snapshot = PaintSnapshot(name: "Naval", subtitle: "SW 6244", finish: "Eggshell · Water-based",
                                     room: "Kitchen", notes: "Two coats", rgb: RGB(red: 0.18, green: 0.23, blue: 0.31),
                                     photos: [])
        let url = try PaintSheetRenderer.writePDF(title: "Kitchen / Pantry", paints: Array(repeating: snapshot, count: 4))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "Kitchen - Pantry.pdf") // slash removed from file name
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 2)
    }

    @Test func usesTheChosenPaperSize() throws {
        let snapshot = PaintSnapshot(name: "Naval", subtitle: "", finish: "", room: nil, notes: "",
                                     rgb: RGB(red: 0, green: 0, blue: 0), photos: [])
        let url = try PaintSheetRenderer.writePDF(title: "A4", paints: [snapshot], paper: .a4)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let page = try #require(CGPDFDocument(url as CFURL)?.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(box.width == 595 && box.height == 842)
    }
}
