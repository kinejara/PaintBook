//
//  Paint.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import SwiftUI
import SwiftData

enum Sheen: String, Codable, CaseIterable, Identifiable {
    case flat = "Flat",
         matte = "Matte",
         eggshell = "Eggshell",
         satin = "Satin",
         semiGloss = "Semi-Gloss",
         gloss = "Gloss"
    
    var id: Self { self }
}

enum PaintBase: String, Codable, CaseIterable, Identifiable {
    case water = "Water-based", oil = "Oil-based"
    var id: Self { self }
}

@Model
final class Paint {
    var colorName: String = ""
    var brand: String = ""
    
    var sheen: Sheen = Sheen.eggshell
    var base: PaintBase = PaintBase.water
    var code: String = ""
    var room: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    
    // Swatch stored as RGB components
    var swatchRed: Double = 1
    var swatchGreen: Double = 1
    var swatchBlue: Double = 1
    
    @Relationship(deleteRule: .cascade) var photos: [PaintPhoto] = []
    
    init() {
        
    }
    
    var swatch: Color {
            get { Color(red: swatchRed, green: swatchGreen, blue: swatchBlue) }
            set {
                let c = newValue.resolve(in: EnvironmentValues())
                swatchRed = Double(c.red)
                swatchGreen = Double(c.green)
                swatchBlue = Double(c.blue)
            }
        }
    
    var shareSummary: String {
            """
            \(colorName) — \(brand)
            Code: \(code)
            \(sheen.rawValue), \(base.rawValue)
            Room: \(room)
            \(notes)
            """
    }
}

@Model
final class PaintPhoto {
    @Attribute(.externalStorage) var data: Data
    var paint: Paint?
    
    init(data: Data) { self.data = data }
}
