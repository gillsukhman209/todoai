import Foundation
import SwiftData

@Model
final class CategoryModel {
    var id: UUID
    var name: String
    var color: String // Hex color string
    var icon: String // SF Symbol name
    var isSystemCategory: Bool
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \TaskModel.category)
    var tasks: [TaskModel] = []
    
    init(
        name: String,
        color: String = "#007AFF", // Default to system blue
        icon: String = "folder",
        isSystemCategory: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.icon = icon
        self.isSystemCategory = isSystemCategory
        self.createdAt = Date()
    }
    
    static func createDefaultCategories() -> [CategoryModel] {
        return [
            CategoryModel(name: "Personal", color: "#007AFF", icon: "person", isSystemCategory: true),
            CategoryModel(name: "Work", color: "#FF9500", icon: "briefcase", isSystemCategory: true),
            CategoryModel(name: "Health", color: "#FF3B30", icon: "heart", isSystemCategory: true),
            CategoryModel(name: "Finance", color: "#34C759", icon: "dollarsign.circle", isSystemCategory: true),
            CategoryModel(name: "Shopping", color: "#AF52DE", icon: "cart", isSystemCategory: true),
            CategoryModel(name: "Home", color: "#FF2D92", icon: "house", isSystemCategory: true)
        ]
    }
} 