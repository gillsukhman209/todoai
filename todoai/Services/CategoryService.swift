import Foundation
import SwiftData

@MainActor
class CategoryService: ObservableObject {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Category Operations
    
    func createCategory(
        name: String,
        color: String = "#007AFF",
        icon: String = "folder"
    ) -> CategoryModel {
        let category = CategoryModel(
            name: name,
            color: color,
            icon: icon,
            isSystemCategory: false
        )
        
        modelContext.insert(category)
        try? modelContext.save()
        return category
    }
    
    func updateCategory(_ category: CategoryModel) {
        try? modelContext.save()
    }
    
    func deleteCategory(_ category: CategoryModel) {
        guard !category.isSystemCategory else { return }
        modelContext.delete(category)
        try? modelContext.save()
    }
    
    // MARK: - Queries
    
    func getAllCategories() -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>()
        let categories = (try? modelContext.fetch(descriptor)) ?? []
        return categories.sorted { first, second in
            if first.isSystemCategory != second.isSystemCategory {
                return first.isSystemCategory && !second.isSystemCategory
            }
            return first.name < second.name
        }
    }
    
    func getSystemCategories() -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate { $0.isSystemCategory }
        )
        let categories = (try? modelContext.fetch(descriptor)) ?? []
        return categories.sorted { $0.name < $1.name }
    }
    
    func getUserCategories() -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate { !$0.isSystemCategory }
        )
        let categories = (try? modelContext.fetch(descriptor)) ?? []
        return categories.sorted { $0.name < $1.name }
    }
    
    // MARK: - Initialization
    
    func initializeDefaultCategories() {
        let existingCategories = getSystemCategories()
        
        // Only create default categories if none exist
        if existingCategories.isEmpty {
            let defaultCategories = CategoryModel.createDefaultCategories()
            for category in defaultCategories {
                modelContext.insert(category)
            }
            try? modelContext.save()
        }
    }
} 