//
//  Settings.swift
//  PaintBook
//
//  User preferences, stored in UserDefaults through @AppStorage.
//

import SwiftUI

enum SettingsKey {
    static let defaultSheen = "defaultSheen"
    static let defaultBase = "defaultBase"
    static let paintSort = "paintSort"
    static let paperSize = "paperSize"
}

/// Reads settings outside of views (where @AppStorage isn't available).
enum AppDefaults {
    static var sheen: Sheen {
        stored(SettingsKey.defaultSheen) ?? .eggshell
    }

    static var base: PaintBase {
        stored(SettingsKey.defaultBase) ?? .water
    }

    static var paperSize: PaperSize {
        stored(SettingsKey.paperSize) ?? .letter
    }

    private static func stored<T: RawRepresentable>(_ key: String) -> T? where T.RawValue == String {
        UserDefaults.standard.string(forKey: key).flatMap(T.init(rawValue:))
    }
}

enum PaintSort: String, CaseIterable, Identifiable {
    case newest = "Newest First"
    case name = "Name"
    case brand = "Brand"
    case room = "Room"

    var id: Self { self }

    func sorted(_ paints: [Paint]) -> [Paint] {
        func ascending(_ a: String, _ b: String) -> Bool {
            a.localizedStandardCompare(b) == .orderedAscending
        }
        switch self {
        case .newest:
            return paints.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return paints.sorted { ascending($0.colorName, $1.colorName) }
        case .brand:
            return paints.sorted {
                $0.brand == $1.brand ? ascending($0.colorName, $1.colorName) : ascending($0.brand, $1.brand)
            }
        case .room:
            // Paints without a room go last.
            return paints.sorted {
                switch ($0.room?.name, $1.room?.name) {
                case let (a?, b?) where a != b: ascending(a, b)
                case (nil, _?): false
                case (_?, nil): true
                default: ascending($0.colorName, $1.colorName)
                }
            }
        }
    }
}

nonisolated enum PaperSize: String, CaseIterable, Identifiable, Sendable {
    case letter = "US Letter"
    case a4 = "A4"

    var id: Self { self }

    /// Page size in points (1/72 inch).
    var pageSize: CGSize {
        switch self {
        case .letter: CGSize(width: 612, height: 792)
        case .a4: CGSize(width: 595, height: 842)
        }
    }
}
