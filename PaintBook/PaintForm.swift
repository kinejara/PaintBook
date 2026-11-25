//
//  PaintForm.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Adds a new paint, or edits an existing one when `paint` is given.
/// Changes are kept in a draft until Save, so Cancel always discards them.
struct PaintForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]

    private let paint: Paint?

    @State private var colorName: String
    @State private var brand: String
    @State private var sheen: Sheen
    @State private var base: PaintBase
    @State private var code: String
    @State private var notes: String
    @State private var swatch: Color
    @State private var room: Room?
    @State private var photos: [DraftPhoto]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingNewRoom = false
    @State private var showingColorMatch = false

    init(paint: Paint? = nil, room: Room? = nil) {
        self.paint = paint
        _colorName = State(initialValue: paint?.colorName ?? "")
        _brand = State(initialValue: paint?.brand ?? "")
        _sheen = State(initialValue: paint?.sheen ?? .eggshell)
        _base = State(initialValue: paint?.base ?? .water)
        _code = State(initialValue: paint?.code ?? "")
        _notes = State(initialValue: paint?.notes ?? "")
        _swatch = State(initialValue: paint?.swatch ?? .white)
        _room = State(initialValue: paint?.room ?? room)
        _photos = State(initialValue: paint?.sortedPhotos.map { DraftPhoto(data: $0.data, existing: $0) } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                colorSection
                photosSection
                roomSection

                Section("Notes") {
                    TextField("Where it's used, how many coats, where you bought it…",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(paint == nil ? "New Paint" : "Edit Paint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(colorName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photos.append(DraftPhoto(data: data))
                        }
                    }
                    pickerItems = []
                }
            }
            .sheet(isPresented: $showingColorMatch) {
                ColorMatchView(suggestedPhotos: photos.map(\.data)) { rgb in
                    swatch = rgb.color
                }
            }
#if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in photos.append(DraftPhoto(data: data)) }
                    .ignoresSafeArea()
            }
#endif
            .newRoomAlert(isPresented: $showingNewRoom) { newRoom in
                room = newRoom
            }
        }
    }

    // MARK: Sections

    private var detailsSection: some View {
        Section("Paint Details") {
            TextField("Color", text: $colorName)
            TextField("Brand", text: $brand)

            Picker("Sheen", selection: $sheen) {
                ForEach(Sheen.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Picker("Base", selection: $base) {
                ForEach(PaintBase.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            TextField("Code", text: $code)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.characters)
#endif
        }
    }

    private var colorSection: some View {
        Section("Swatch") {
            HStack {
                ColorPicker("Swatch color", selection: $swatch, supportsOpacity: false)
                Text(RGB(swatch).hex)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            Button("Match from a Photo", systemImage: "eyedropper") {
                showingColorMatch = true
            }
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            if !photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            PhotoThumbnail(data: photo.data)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        photos.removeAll { $0.id == photo.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                    .accessibilityLabel("Remove photo")
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                Label("Add from Library", systemImage: "photo.on.rectangle")
            }

#if os(iOS)
            if CameraPicker.isAvailable {
                Button("Take Photo", systemImage: "camera") { showingCamera = true }
            }
#endif
        }
    }

    private var roomSection: some View {
        Section("Room") {
            Picker("Room", selection: $room) {
                Text("None").tag(nil as Room?)
                ForEach(rooms) { room in
                    Text(room.displayName).tag(room as Room?)
                }
            }
            Button("New Room…", systemImage: "plus") { showingNewRoom = true }
        }
    }

    // MARK: Saving

    private func save() {
        let target: Paint
        if let paint {
            target = paint
        } else {
            target = Paint()
            modelContext.insert(target)
        }

        target.colorName = colorName.trimmingCharacters(in: .whitespaces)
        target.brand = brand.trimmingCharacters(in: .whitespaces)
        target.sheen = sheen
        target.base = base
        target.code = code.trimmingCharacters(in: .whitespaces)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.swatch = swatch
        target.room = room

        // Photos: delete the ones removed in the draft, add the new ones in order.
        let kept = Set(photos.compactMap { $0.existing?.persistentModelID })
        for photo in Array(target.photos) where !kept.contains(photo.persistentModelID) {
            modelContext.delete(photo)
        }
        let start = Date.now
        for (index, draft) in photos.filter({ $0.existing == nil }).enumerated() {
            let photo = PaintPhoto(data: draft.data)
            photo.addedAt = start.addingTimeInterval(Double(index) / 1000)
            target.photos.append(photo)
        }

        try? modelContext.save()
        dismiss()
    }
}

/// A photo in the form before saving: either already saved (`existing`) or newly added.
private struct DraftPhoto: Identifiable {
    let id = UUID()
    let data: Data
    var existing: PaintPhoto? = nil
}

#Preview("New") {
    PaintForm()
        .modelContainer(for: Paint.self, inMemory: true)
}
