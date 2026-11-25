//
//  RootView.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                ContentView()
            }

            Tab("Rooms", systemImage: "house") {
                RoomsView()
            }

            Tab("Settings", systemImage: "gearshape") {
                Text("Settings")
            }
        }
    }
}

#Preview {
    RootView().modelContainer(for: Paint.self, inMemory: true)
}
