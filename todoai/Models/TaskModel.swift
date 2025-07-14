import Foundation
import SwiftData

@Model
final class TaskModel {
    var id: UUID
    var title: String
    var taskDescription: String?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var priority: TaskPriority
    var estimatedDuration: TimeInterval? // For Pomodoro integration
    var category: CategoryModel?
    var isRecurring: Bool
    var recurringTemplate: TaskTemplateModel?
    var completedAt: Date?
    var originalText: String? // For natural language input tracking
    
    init(
        title: String,
        description: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        estimatedDuration: TimeInterval? = nil,
        isRecurring: Bool = false,
        originalText: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = description
        self.isCompleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dueDate = dueDate
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.isRecurring = isRecurring
        self.originalText = originalText
    }
    
    func markCompleted() {
        isCompleted = true
        completedAt = Date()
        updatedAt = Date()
    }
    
    func markIncomplete() {
        isCompleted = false
        completedAt = nil
        updatedAt = Date()
    }
    
    func updateTitle(_ newTitle: String) {
        title = newTitle
        updatedAt = Date()
    }
    
    func updateDescription(_ newDescription: String?) {
        taskDescription = newDescription
        updatedAt = Date()
    }
    
    func updateDueDate(_ newDueDate: Date?) {
        dueDate = newDueDate
        updatedAt = Date()
    }
    
    func updatePriority(_ newPriority: TaskPriority) {
        priority = newPriority
        updatedAt = Date()
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .urgent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
} 