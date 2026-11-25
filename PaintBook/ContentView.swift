//
//  ContentView.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Paint.createdAt, order: .reverse) private var paints: [Paint]
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var showingNewPaint = false
    @State private var showingColorMatch = false
    @State private var searchText = ""
    @State private var roomFilter: Room?
    @State private var sheenFilter: Sheen?

    private var isFiltering: Bool {
        roomFilter != nil || sheenFilter != nil
    }

    private var filteredPaints: [Paint] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return paints.filter { paint in
            if let roomFilter, paint.room != roomFilter { return false }
            if let sheenFilter, paint.sheen != sheenFilter { return false }
            guard !query.isEmpty else { return true }
            return [paint.colorName, paint.brand, paint.code, paint.notes, paint.room?.name ?? ""]
                .contains { $0.localizedStandardContains(query) }
        }
    }

    var body: some View {
        NavigationViewWrapper {
            List {
                ForEach(filteredPaints) { paint in
                    NavigationLink {
                        PaintDetailView(paint: paint)
                    } label: {
                        PaintRow(paint: paint)
                    }
                }
                .onDelete(perform: deletePaints)
            }
            .overlay { emptyState }
            .navigationTitle("Paints")
            .searchable(text: $searchText, prompt: "Name, brand, code or room")
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    filterMenu
                }
                ToolbarItem {
                    Button {
                        showingColorMatch = true
                    } label: {
                        Label("Match a Color", systemImage: "eyedropper")
                    }
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
                PaintForm()
            }
            .sheet(isPresented: $showingColorMatch) {
                ColorMatchView()
            }
            .onChange(of: rooms) { _, rooms in
                // Clear the filter if its room was deleted.
                if let roomFilter, !rooms.contains(roomFilter) { self.roomFilter = nil }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if paints.isEmpty {
            ContentUnavailableView("No Paints Yet",
                                   systemImage: "paintpalette",
                                   description: Text("Tap + to add your first paint."))
        } else if filteredPaints.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Matching Paints", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No paints match the current filters.")
                } actions: {
                    Button("Clear Filters") { clearFilters() }
                }
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Room", selection: $roomFilter) {
                Text("All Rooms").tag(nil as Room?)
                ForEach(rooms) { room in
                    Text(room.displayName).tag(room as Room?)
                }
            }
            Picker("Sheen", selection: $sheenFilter) {
                Text("All Sheens").tag(nil as Sheen?)
                ForEach(Sheen.allCases) { sheen in
                    Text(sheen.rawValue).tag(sheen as Sheen?)
                }
            }
            if isFiltering {
                Divider()
                Button("Clear Filters", systemImage: "xmark") { clearFilters() }
            }
        } label: {
            Label("Filter", systemImage: isFiltering
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
    }

    private func clearFilters() {
        roomFilter = nil
        sheenFilter = nil
    }

    private func deletePaints(offsets: IndexSet) {
        let visible = filteredPaints
        withAnimation {
            for index in offsets {
                modelContext.delete(visible[index])
            }
        }
    }
}

struct NavigationViewWrapper<Content: View>: View {
    let content: () -> Content

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            content()
        } detail: {
            Text("Select a paint")
        }
#else
        NavigationStack {
            content()
        }
#endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Paint.self, inMemory: true)
}
