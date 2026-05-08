//
//  Item.swift
//  The Friendly Fitness Companion V2
//
//  Created by Larry Fields III on 5/8/26.
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
