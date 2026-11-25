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
    @State private var roomToRename: Room?

    var body: some View {
        NavigationStack {
            List {
                ForEach(rooms.live) { room in
                    NavigationLink {
                        RoomDetailView(room: room)
                    } label: {
                        RoomRow(room: room)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Rename", systemImage: "pencil") { roomToRename = room }
                            .tint(.blue)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { roomToRename = room }
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
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
#endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewRoom = true
                    } label: {
                        Label("Add Room", systemImage: "plus")
                    }
                }
            }
            .newRoomAlert(isPresented: $showingNewRoom)
            .renameRoomAlert(room: $roomToRename)
        }
    }

    private func deleteRooms(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(rooms.live[index]) // its paints are kept, just unassigned
            }
        }
    }
}

private struct RoomRow: View {
    let room: Room

    var body: some View {
        if room.modelContext == nil || room.isDeleted {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
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
                Text(room.sortedPaints.count == 1 ? "1 paint" : "\(room.sortedPaints.count) paints")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RoomDetailView: View {
    let room: Room
    @State private var showingNewPaint = false
    @State private var roomToRename: Room?

    var body: some View {
        if room.modelContext == nil || room.isDeleted {
            ContentUnavailableView("Room Deleted", systemImage: "trash")
        } else {
            details
        }
    }

    private var details: some View {
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
                Button("Rename") { roomToRename = room }
            }
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
        .renameRoomAlert(room: $roomToRename)
    }
}
