//
//  Room.swift
//  PaintBook
//

import Foundation
import SwiftData

@Model
final class Room {
    var name: String = ""
    var createdAt: Date = Date.now

    /// Deleting a room keeps its paints; they just lose their room.
    @Relationship(deleteRule: .nullify, inverse: \Paint.room)
    var paints: [Paint] = []

    init(name: String) {
        self.name = name
    }

    var displayName: String {
        name.isEmpty ? "Untitled Room" : name
    }

    var sortedPaints: [Paint] {
        paints.sorted { $0.colorName.localizedStandardCompare($1.colorName) == .orderedAscending }
    }

    var shareSummary: String {
        let list = sortedPaints.map { paint in
            "• " + paint.shareSummary.replacingOccurrences(of: "\n", with: "\n  ")
        }
        return ([displayName] + list).joined(separator: "\n")
    }
}
