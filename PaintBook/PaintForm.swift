//
//  PaintForm.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import SwiftUI
import SwiftData

struct PaintForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var colorName = ""
    @State private var brand = ""
    @State private var sheen: Sheen = .eggshell
    @State private var base: PaintBase = .water
    @State private var code = ""
    
    var body: some View {
        NavigationStack {
            Form {
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
                    .pickerStyle(.segmented)

                    TextField("Code", text: $code)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.characters)
#endif
                }
            }
            .navigationTitle("New Paint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(colorName.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let paint = Paint()
        paint.colorName = colorName
        paint.brand = brand
        paint.sheen = sheen
        paint.base = base
        paint.code = code
        modelContext.insert(paint)
        dismiss()
    }
}

#Preview {
    PaintForm()
        .modelContainer(for: Paint.self, inMemory: true)
}
