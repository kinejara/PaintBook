//
//  Components.swift
//  PaintBook
//
//  Small views shared across screens.
//

import SwiftUI
import SwiftData

/// A colour chip with a faint outline so white and very light colours stay visible.
struct SwatchView: View {
    let color: Color
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.secondary.opacity(0.3))
            )
    }
}

struct PaintRow: View {
    let paint: Paint
    var showsRoom = true

    var body: some View {
        HStack(spacing: 12) {
            SwatchView(color: paint.swatch, cornerRadius: 18)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(paint.displayName)
                    .font(.headline)
                if !paint.subtitle.isEmpty {
                    Text(paint.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(paint.sheen.rawValue)
                if showsRoom, let room = paint.room {
                    Text(room.displayName)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Adds an alert that asks for a room name and saves the new room.
private struct NewRoomAlert: ViewModifier {
    @Binding var isPresented: Bool
    var onCreate: (Room) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func body(content: Content) -> some View {
        content.alert("New Room", isPresented: $isPresented) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) { name = "" }
            // Alerts don't refresh a button's disabled state while typing,
            // so an empty name is ignored here instead.
            Button("Add") {
                guard !trimmedName.isEmpty else { return }
                let room = Room(name: trimmedName)
                modelContext.insert(room)
                onCreate(room)
                name = ""
            }
        } message: {
            Text("For example Kitchen or Guest Bedroom.")
        }
    }
}

extension View {
    func newRoomAlert(isPresented: Binding<Bool>,
                      onCreate: @escaping (Room) -> Void = { _ in }) -> some View {
        modifier(NewRoomAlert(isPresented: isPresented, onCreate: onCreate))
    }
}
