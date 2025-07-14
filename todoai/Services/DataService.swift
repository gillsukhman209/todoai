import Foundation
import SwiftData

@MainActor
class DataService: ObservableObject {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    // Service dependencies
    let taskService: TaskService
    let categoryService: CategoryService
    
    init() {
        // Setup SwiftData container
        let schema = Schema([
            TaskModel.self,
            CategoryModel.self,
            TaskTemplateModel.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = modelContainer.mainContext
            
            // Initialize services
            taskService = TaskService(modelContext: modelContext)
            categoryService = CategoryService(modelContext: modelContext)
            
            // Initialize default data
            initializeDefaultData()
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private func initializeDefaultData() {
        categoryService.initializeDefaultCategories()
    }
    
    // MARK: - Convenience Methods
    
    func save() {
        try? modelContext.save()
    }
    
    // MARK: - Development/Testing Support
    
    func createSampleData() {
        let categories = categoryService.getAllCategories()
        guard let workCategory = categories.first(where: { $0.name == "Work" }),
              let personalCategory = categories.first(where: { $0.name == "Personal" }),
              let financeCategory = categories.first(where: { $0.name == "Finance" }) else {
            return
        }
        
        // Create sample tasks
        let sampleTasks = [
            (title: "Complete project proposal", category: workCategory, priority: TaskPriority.high, dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())),
            (title: "Call dentist for appointment", category: personalCategory, priority: TaskPriority.medium, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())),
            (title: "Review monthly expenses", category: financeCategory, priority: TaskPriority.low, dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())),
            (title: "Team meeting at 3 PM", category: workCategory, priority: TaskPriority.urgent, dueDate: Date()),
            (title: "Buy groceries", category: personalCategory, priority: TaskPriority.medium, dueDate: nil)
        ]
        
        for (title, category, priority, dueDate) in sampleTasks {
            _ = taskService.createTask(
                title: title,
                priority: priority,
                category: category,
                estimatedDuration: 1800 // 30 minutes
            )
            if let dueDate = dueDate {
                let task = taskService.getAllTasks().first { $0.title == title }
                task?.updateDueDate(dueDate)
            }
        }
        
        save()
    }
} 