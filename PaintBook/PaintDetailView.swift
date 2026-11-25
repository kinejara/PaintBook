//
//  PaintDetailView.swift
//  PaintBook
//

import SwiftUI
import SwiftData

struct PaintDetailView: View {
    let paint: Paint

    @State private var showingEditor = false

    var body: some View {
        if paint.modelContext == nil || paint.isDeleted {
            ContentUnavailableView("Paint Deleted", systemImage: "trash")
        } else {
            details
        }
    }

    private var details: some View {
        List {
            Section {
                SwatchView(color: paint.swatch, cornerRadius: 12)
                    .frame(height: 160)
                    .overlay(alignment: .bottomLeading) {
                        Text(paint.swatchRGB.hex)
                            .font(.headline.monospaced())
                            .foregroundStyle(paint.swatchRGB.isLight ? .black : .white)
                            .padding(12)
                    }
                    .listRowInsets(EdgeInsets())
            }

            Section("Details") {
                LabeledContent("Brand", value: display(paint.brand))
                LabeledContent("Code", value: display(paint.code))
                LabeledContent("Sheen", value: paint.sheen.rawValue)
                LabeledContent("Base", value: paint.base.rawValue)
                LabeledContent("Room", value: paint.room?.displayName ?? "—")
            }

            if !paint.photos.isEmpty {
                Section("Photos") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(paint.sortedPhotos) { photo in
                                PhotoThumbnail(data: photo.data, size: 120)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !paint.notes.isEmpty {
                Section("Notes") {
                    Text(paint.notes)
                }
            }

            ShareSection(text: paint.shareSummary,
                         title: paint.displayName,
                         paints: [paint.snapshot])
        }
        .navigationTitle(paint.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            PaintForm(paint: paint)
        }
    }

    private func display(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }
}
