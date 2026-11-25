//
//  Sharing.swift
//  PaintBook
//
//  Text sharing and PDF "paint sheet" export.
//

import SwiftUI

/// A plain copy of a paint's data used to draw the PDF.
nonisolated struct PaintSnapshot: Hashable, Sendable {
    var name: String
    var subtitle: String
    var finish: String
    var room: String?
    var notes: String
    var rgb: RGB
    var photos: [Data]
}

enum PaintSheetRenderer {
    static let paintsPerPage = 3

    static func writePDF(title: String, paints: [PaintSnapshot], paper: PaperSize = .letter) throws -> URL {
        let pageSize = paper.pageSize
        let safeTitle = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(safeTitle).pdf")

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let pages = stride(from: 0, to: max(paints.count, 1), by: paintsPerPage).map {
            Array(paints[$0..<min($0 + paintsPerPage, paints.count)])
        }

        for (index, pagePaints) in pages.enumerated() {
            let page = PaintSheetPage(title: title,
                                      paints: pagePaints,
                                      pageNumber: index + 1,
                                      pageCount: pages.count)
                .frame(width: pageSize.width, height: pageSize.height, alignment: .top)
                .background(.white)
                .environment(\.colorScheme, .light)

            ImageRenderer(content: page).render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return url
    }
}

private struct PaintSheetPage: View {
    let title: String
    let paints: [PaintSnapshot]
    let pageNumber: Int
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.bold())
                Text(Date.now, format: .dateTime.day().month(.wide).year())
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(paints.enumerated()), id: \.offset) { _, paint in
                PaintSheetCard(paint: paint)
            }

            Spacer(minLength: 0)

            if pageCount > 1 {
                Text("Page \(pageNumber) of \(pageCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(40)
        .foregroundStyle(.black)
    }
}

private struct PaintSheetCard: View {
    let paint: PaintSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                SwatchView(color: paint.rgb.color)
                    .frame(width: 100, height: 100)
                Text(paint.rgb.hex)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(paint.name).font(.title2.bold())
                if !paint.subtitle.isEmpty { Text(paint.subtitle) }
                Text(paint.finish).foregroundStyle(.secondary)
                if let room = paint.room {
                    Text("Room: \(room)").foregroundStyle(.secondary)
                }
                if !paint.notes.isEmpty {
                    Text(paint.notes)
                        .font(.callout)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
                if !paint.photos.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(paint.photos.enumerated()), id: \.offset) { _, data in
                            if let image = ImageLoader.cgImage(from: data, maxPixelSize: 240) {
                                Image(decorative: image, scale: 1)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(.rect(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 190, alignment: .top)
        .clipped()
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.gray.opacity(0.3)))
    }
}

/// List section offering a text share and a PDF export.
/// The PDF is rendered ahead of time (and again whenever the content changes),
/// so the share sheet always gets a ready file.
struct ShareSection: View {
    let text: String
    let title: String
    let paints: [PaintSnapshot]

    @State private var pdfURL: URL?
    @AppStorage(SettingsKey.paperSize) private var paperSize: PaperSize = .letter

    private struct PDFInput: Hashable {
        var paints: [PaintSnapshot]
        var paper: PaperSize
    }

    var body: some View {
        Section("Share") {
            ShareLink(item: text) {
                Label("Share as Text", systemImage: "square.and.arrow.up")
            }
            if let pdfURL {
                ShareLink(item: pdfURL) {
                    Label("Export to PDF", systemImage: "doc.richtext")
                }
            } else {
                Label("Preparing PDF…", systemImage: "doc.richtext")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: PDFInput(paints: paints, paper: paperSize)) {
            pdfURL = try? PaintSheetRenderer.writePDF(title: title, paints: paints, paper: paperSize)
        }
    }
}
