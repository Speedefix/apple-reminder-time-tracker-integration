//
//  Item.swift
//  ReminderTimer
//
//  Created by Leonard Schulte on 07.11.25.
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
