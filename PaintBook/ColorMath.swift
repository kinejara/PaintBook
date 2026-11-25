//
//  ColorMath.swift
//  PaintBook
//
//  Colour storage, conversion and matching.
//

import SwiftUI

/// An sRGB colour with components in 0...1.
nonisolated struct RGB: Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: Color) {
        let c = color.resolve(in: EnvironmentValues())
        self.init(red: Double(c.red), green: Double(c.green), blue: Double(c.blue))
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    var hex: String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// CIE L*a*b* (D65), used for perceptual colour distance.
    var lab: (l: Double, a: Double, b: Double) {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linear(red), g = linear(green), b = linear(blue)

        let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
        let y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
        let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

        func f(_ t: Double) -> Double {
            t > 0.008856 ? cbrt(t) : (7.787 * t) + 16.0 / 116.0
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// CIE76 ΔE: about 2.3 is "just noticeable"; under 10 reads as the same colour family.
    func distance(to other: RGB) -> Double {
        let p = lab, q = other.lab
        return sqrt(pow(p.l - q.l, 2) + pow(p.a - q.a, 2) + pow(p.b - q.b, 2))
    }

    /// The perceived brightness, for choosing readable text on top of the colour.
    var isLight: Bool { lab.l > 60 }
}

enum MatchQuality {
    case nearlyIdentical, close, similar, distant

    init(distance: Double) {
        switch distance {
        case ..<3: self = .nearlyIdentical
        case ..<8: self = .close
        case ..<18: self = .similar
        default: self = .distant
        }
    }

    var label: String {
        switch self {
        case .nearlyIdentical: "Nearly identical"
        case .close: "Close match"
        case .similar: "Similar"
        case .distant: "Different"
        }
    }
}
