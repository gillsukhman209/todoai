import Foundation
import SwiftData

@Model
final class TaskTemplateModel {
    var id: UUID
    var title: String
    var taskDescription: String?
    var category: CategoryModel?
    var priority: TaskPriority
    var estimatedDuration: TimeInterval?
    var recurrenceType: RecurrenceType
    var recurrenceInterval: Int // Every X days/weeks/months
    var recurrenceEndDate: Date?
    var lastGeneratedDate: Date?
    var isActive: Bool
    var createdAt: Date
    var templateType: TemplateType
    
    // Payment reminder specific
    var amount: Double? // For payment reminders
    var paymentMethod: String? // "Credit Card", "Bank Transfer", etc.
    var reminderDaysBefore: Int // Days before due date to remind
    
    init(
        title: String,
        description: String? = nil,
        category: CategoryModel? = nil,
        priority: TaskPriority = .medium,
        estimatedDuration: TimeInterval? = nil,
        recurrenceType: RecurrenceType = .daily,
        recurrenceInterval: Int = 1,
        templateType: TemplateType = .general,
        amount: Double? = nil,
        paymentMethod: String? = nil,
        reminderDaysBefore: Int = 3
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = description
        self.category = category
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.recurrenceType = recurrenceType
        self.recurrenceInterval = recurrenceInterval
        self.isActive = true
        self.createdAt = Date()
        self.templateType = templateType
        self.amount = amount
        self.paymentMethod = paymentMethod
        self.reminderDaysBefore = reminderDaysBefore
    }
    
    func generateNextTask() -> TaskModel? {
        guard isActive else { return nil }
        
        let nextDueDate = calculateNextDueDate()
        let task = TaskModel(
            title: title,
            description: taskDescription,
            dueDate: nextDueDate,
            priority: priority,
            estimatedDuration: estimatedDuration,
            isRecurring: true
        )
        
        task.category = category
        task.recurringTemplate = self
        lastGeneratedDate = Date()
        
        return task
    }
    
    private func calculateNextDueDate() -> Date {
        let baseDate = lastGeneratedDate ?? Date()
        let calendar = Calendar.current
        
        switch recurrenceType {
        case .daily:
            return calendar.date(byAdding: .day, value: recurrenceInterval, to: baseDate) ?? baseDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: recurrenceInterval, to: baseDate) ?? baseDate
        case .monthly:
            return calendar.date(byAdding: .month, value: recurrenceInterval, to: baseDate) ?? baseDate
        case .yearly:
            return calendar.date(byAdding: .year, value: recurrenceInterval, to: baseDate) ?? baseDate
        }
    }
    
    static func createDefaultPaymentTemplates() -> [TaskTemplateModel] {
        return [
            TaskTemplateModel(
                title: "Rent Payment",
                description: "Monthly rent payment",
                priority: .high,
                recurrenceType: .monthly,
                templateType: .payment,
                reminderDaysBefore: 5
            ),
            TaskTemplateModel(
                title: "Credit Card Bill",
                description: "Monthly credit card payment",
                priority: .high,
                recurrenceType: .monthly,
                templateType: .payment,
                reminderDaysBefore: 7
            ),
            TaskTemplateModel(
                title: "Utility Bills",
                description: "Monthly utility payment",
                priority: .medium,
                recurrenceType: .monthly,
                templateType: .payment,
                reminderDaysBefore: 5
            )
        ]
    }
}

enum RecurrenceType: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum TemplateType: String, CaseIterable, Codable {
    case general = "general"
    case payment = "payment"
    case subscription = "subscription"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .payment: return "Payment"
        case .subscription: return "Subscription"
        case .maintenance: return "Maintenance"
        }
    }
} 