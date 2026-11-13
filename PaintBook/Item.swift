//
//  Item.swift
//  PaintBook
//
//  Created by Jorge Villanueva on 11/13/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
