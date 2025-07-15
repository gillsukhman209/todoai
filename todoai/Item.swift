//
//  Item.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import Foundation
import SwiftData

@Model
final class Todo {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(title: String) {
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
