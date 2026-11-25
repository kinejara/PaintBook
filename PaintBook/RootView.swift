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
            Tab("Paints", systemImage: "paintbrush") {
                ContentView()
            }

            Tab("Rooms", systemImage: "house") {
                RoomsView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootView().modelContainer(for: Paint.self, inMemory: true)
}
