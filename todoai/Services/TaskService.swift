import Foundation
import SwiftData

@MainActor
class TaskService: ObservableObject {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Task Operations
    
    func createTask(
        title: String,
        description: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        category: CategoryModel? = nil,
        estimatedDuration: TimeInterval? = nil,
        originalText: String? = nil
    ) -> TaskModel {
        let task = TaskModel(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority,
            estimatedDuration: estimatedDuration,
            originalText: originalText
        )
        
        task.category = category
        modelContext.insert(task)
        return task
    }
    
    func updateTask(_ task: TaskModel) {
        task.updatedAt = Date()
        try? modelContext.save()
    }
    
    func deleteTask(_ task: TaskModel) {
        modelContext.delete(task)
        try? modelContext.save()
    }
    
    func completeTask(_ task: TaskModel) {
        task.markCompleted()
        try? modelContext.save()
    }
    
    func uncompleteTask(_ task: TaskModel) {
        task.markIncomplete()
        try? modelContext.save()
    }
    
    // MARK: - Queries
    
    func getAllTasks() -> [TaskModel] {
        let descriptor = FetchDescriptor<TaskModel>()
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getTasks(for category: CategoryModel) -> [TaskModel] {
        let categoryId = category.id
        let descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { task in
                task.category?.id == categoryId
            }
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getPendingTasks() -> [TaskModel] {
        let descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.sorted { first, second in
            // Sort by due date first (nil dates go to end), then by priority, then by creation date
            if let firstDue = first.dueDate, let secondDue = second.dueDate {
                return firstDue < secondDue
            } else if first.dueDate != nil {
                return true
            } else if second.dueDate != nil {
                return false
            } else {
                if first.priority.sortOrder != second.priority.sortOrder {
                    return first.priority.sortOrder > second.priority.sortOrder
                }
                return first.createdAt > second.createdAt
            }
        }
    }
    
    func getCompletedTasks() -> [TaskModel] {
        let descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { $0.isCompleted }
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.sorted { first, second in
            if let firstCompleted = first.completedAt, let secondCompleted = second.completedAt {
                return firstCompleted > secondCompleted
            }
            return first.createdAt > second.createdAt
        }
    }
    
    func getTasksDueToday() -> [TaskModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { task in
                !task.isCompleted &&
                task.dueDate != nil &&
                task.dueDate! >= today &&
                task.dueDate! < tomorrow
            }
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.sorted { first, second in
            if let firstDue = first.dueDate, let secondDue = second.dueDate {
                return firstDue < secondDue
            }
            return false
        }
    }
    
    func getOverdueTasks() -> [TaskModel] {
        let today = Calendar.current.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { task in
                !task.isCompleted &&
                task.dueDate != nil &&
                task.dueDate! < today
            }
        )
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.sorted { first, second in
            if let firstDue = first.dueDate, let secondDue = second.dueDate {
                return firstDue < secondDue
            }
            return false
        }
    }
} 