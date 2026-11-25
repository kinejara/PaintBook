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
    @State private var showingNewPaint = false

    var body: some View {
        NavigationViewWrapper {
            List {
                ForEach(paints) { paint in
                    NavigationLink {
                        Text(paint.colorName)   // placeholder detail screen for now
                    } label: {
                        PaintRow(paint: paint)
                    }
                }
                .onDelete(perform: deletePaints)
            }
            .overlay {
                if paints.isEmpty {
                    ContentUnavailableView("No Paints Yet",
                                           systemImage: "paintpalette",
                                           description: Text("Tap + to add your first paint."))
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                
                ToolbarItem {
                    Button(action: addPaint) {
                        Label("Add Paint", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewPaint) {
                PaintForm()
            }
        }
    }

    private func addPaint() {
        showingNewPaint = true
    }

    private func deletePaints(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(paints[index])
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

struct PaintRow: View {
    let paint: Paint

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(paint.swatch)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(.secondary.opacity(0.3)))

            VStack(alignment: .leading) {
                Text(paint.colorName)
                    .font(.headline)
                Text("\(paint.brand) · \(paint.code)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(paint.sheen.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Paint.self, inMemory: true)
}
