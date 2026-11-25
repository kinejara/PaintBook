//
//  ColorMatchView.swift
//  PaintBook
//
//  Sample a colour from a photo and find the closest paints in the library.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ColorMatchView: View {
    /// Photos offered as quick sources (for example the ones already on the paint being edited).
    var suggestedPhotos: [Data] = []
    /// When set, shows a "Use Color" button that hands back the sampled colour.
    var onPick: ((RGB) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query private var paints: [Paint]

    @State private var image: CGImage?
    @State private var samplePoint: CGPoint?
    @State private var sample: RGB?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false

    private struct Match: Identifiable {
        let paint: Paint
        let distance: Double
        var id: PersistentIdentifier { paint.persistentModelID }
    }

    private var matches: [Match] {
        guard let sample else { return [] }
        return paints.live
            .map { Match(paint: $0, distance: sample.distance(to: $0.swatchRGB)) }
            .sorted { $0.distance < $1.distance }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let image {
                        SamplingImage(image: image, point: samplePoint) { point in
                            samplePoint = point
                            sample = ImageLoader.averageColor(in: image, at: point)
                        }
                        .frame(height: 320)
                        .listRowInsets(EdgeInsets())
                    } else {
                        ContentUnavailableView("Choose a Photo",
                                               systemImage: "eyedropper",
                                               description: Text("Pick a photo of a wall or paint chip, then tap or drag on it to sample the color."))
                    }
                } footer: {
                    if image != nil {
                        Text("Tap or drag to move the sampler. Daylight without flash gives the truest color.")
                    }
                }

                Section("Source") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
#if os(iOS)
                    if CameraPicker.isAvailable {
                        Button("Take Photo", systemImage: "camera") { showingCamera = true }
                    }
#endif
                    if !suggestedPhotos.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(Array(suggestedPhotos.enumerated()), id: \.offset) { _, data in
                                    Button {
                                        Task { await load(data) }
                                    } label: {
                                        PhotoThumbnail(data: data, size: 56)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if let sample {
                    Section("Sampled Color") {
                        HStack(spacing: 12) {
                            SwatchView(color: sample.color)
                                .frame(width: 56, height: 56)
                            Text(sample.hex)
                                .font(.title3.monospaced())
                        }
                    }

                    Section("Closest in Your Library") {
                        if matches.isEmpty {
                            Text("Add some paints to compare against.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(matches) { match in
                            matchRow(match)
                        }
                    }
                }
            }
            .navigationTitle("Match a Color")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onPick == nil ? "Done" : "Cancel") { dismiss() }
                }
                if let onPick {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Color") {
                            if let sample { onPick(sample) }
                            dismiss()
                        }
                        .disabled(sample == nil)
                    }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await load(data)
                    }
                    pickerItem = nil
                }
            }
#if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in Task { await load(data) } }
                    .ignoresSafeArea()
            }
#endif
        }
    }

    @ViewBuilder
    private func matchRow(_ match: Match) -> some View {
        let label = HStack(spacing: 12) {
            SwatchView(color: match.paint.swatch, cornerRadius: 18)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.paint.displayName).font(.headline)
                Text(match.paint.subtitle.isEmpty ? match.paint.swatchRGB.hex : match.paint.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MatchQuality(distance: match.distance).label)
                Text("ΔE \(match.distance, format: .number.precision(.fractionLength(1)))")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }

        if onPick == nil {
            NavigationLink { PaintDetailView(paint: match.paint) } label: { label }
        } else {
            label
        }
    }

    /// Shows a new photo and samples its centre.
    private func load(_ data: Data) async {
        guard let loaded = await ImageLoader.loadImage(from: data, maxPixelSize: 2048) else { return }
        image = loaded
        let center = CGPoint(x: loaded.width / 2, y: loaded.height / 2)
        samplePoint = center
        sample = ImageLoader.averageColor(in: loaded, at: center)
    }
}

/// Shows an image scaled to fit, with a ring at the sample point.
/// Reports taps and drags in image pixel coordinates.
private struct SamplingImage: View {
    let image: CGImage
    let point: CGPoint?
    let onSample: (CGPoint) -> Void

    var body: some View {
        GeometryReader { geometry in
            let imageSize = CGSize(width: image.width, height: image.height)
            let scale = min(geometry.size.width / imageSize.width,
                            geometry.size.height / imageSize.height)
            let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(x: (geometry.size.width - fitted.width) / 2,
                                 y: (geometry.size.height - fitted.height) / 2)

            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: origin.x + fitted.width / 2, y: origin.y + fitted.height / 2)

                if let point {
                    Circle()
                        .strokeBorder(.black.opacity(0.5), lineWidth: 5)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .frame(width: 30, height: 30)
                        .position(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = (value.location.x - origin.x) / scale
                        let y = (value.location.y - origin.y) / scale
                        guard x >= 0, y >= 0, x < imageSize.width, y < imageSize.height else { return }
                        onSample(CGPoint(x: x, y: y))
                    }
            )
        }
        .accessibilityLabel("Photo for color sampling")
    }
}
