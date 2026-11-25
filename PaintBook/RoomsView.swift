//
//  RoomsView.swift
//  PaintBook
//

import SwiftUI
import SwiftData

struct RoomsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    @State private var showingNewRoom = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(rooms) { room in
                    NavigationLink {
                        RoomDetailView(room: room)
                    } label: {
                        RoomRow(room: room)
                    }
                }
                .onDelete(perform: deleteRooms)
            }
            .overlay {
                if rooms.isEmpty {
                    ContentUnavailableView("No Rooms Yet",
                                           systemImage: "house",
                                           description: Text("Add rooms to group the paints used in each space."))
                }
            }
            .navigationTitle("Rooms")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingNewRoom = true
                    } label: {
                        Label("Add Room", systemImage: "plus")
                    }
                }
            }
            .newRoomAlert(isPresented: $showingNewRoom)
        }
    }

    private func deleteRooms(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(rooms[index]) // its paints are kept, just unassigned
            }
        }
    }
}

private struct RoomRow: View {
    let room: Room

    var body: some View {
        HStack(spacing: 12) {
            // Up to 5 overlapping swatches of the room's paints
            HStack(spacing: -10) {
                ForEach(room.sortedPaints.prefix(5)) { paint in
                    SwatchView(color: paint.swatch, cornerRadius: 12)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.displayName).font(.headline)
                Text(room.paints.count == 1 ? "1 paint" : "\(room.paints.count) paints")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RoomDetailView: View {
    let room: Room
    @State private var showingNewPaint = false

    var body: some View {
        List {
            ForEach(room.sortedPaints) { paint in
                NavigationLink {
                    PaintDetailView(paint: paint)
                } label: {
                    PaintRow(paint: paint, showsRoom: false)
                }
                .swipeActions {
                    Button("Remove", systemImage: "minus.circle") {
                        withAnimation { paint.room = nil }
                    }
                    .tint(.orange)
                }
            }

            if !room.paints.isEmpty {
                ShareSection(text: room.shareSummary,
                             title: room.displayName,
                             paints: room.sortedPaints.map(\.snapshot))
            }
        }
        .overlay {
            if room.paints.isEmpty {
                ContentUnavailableView("No Paints in \(room.displayName)",
                                       systemImage: "paintpalette",
                                       description: Text("Tap + to add one, or pick this room when editing a paint."))
            }
        }
        .navigationTitle(room.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewPaint = true
                } label: {
                    Label("Add Paint", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPaint) {
            PaintForm(room: room)
        }
    }
}
