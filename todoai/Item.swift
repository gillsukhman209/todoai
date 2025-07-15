//
//  Item.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import Foundation
import SwiftData

@Model
final class Todo: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
