import Foundation
import SwiftData
import OSLog

// MARK: - Task Type
enum TaskType: String, Codable, CaseIterable {
    case reminder = "reminder"
    case habit = "habit"
    case project = "project"
    case shopping = "shopping"
    case work = "work"
    case personal = "personal"
    case health = "health"
    case finance = "finance"
    case social = "social"
    case learning = "learning"
    case maintenance = "maintenance"
    case travel = "travel"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .reminder: return "Reminder"
        case .habit: return "Habit"
        case .project: return "Project"
        case .shopping: return "Shopping"
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .finance: return "Finance"
        case .social: return "Social"
        case .learning: return "Learning"
        case .maintenance: return "Maintenance"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }
    
    var systemImage: String {
        switch self {
        case .reminder: return "bell"
        case .habit: return "repeat"
        case .project: return "folder"
        case .shopping: return "cart"
        case .work: return "briefcase"
        case .personal: return "person"
        case .health: return "heart"
        case .finance: return "dollarsign.circle"
        case .social: return "person.2"
        case .learning: return "book"
        case .maintenance: return "wrench"
        case .travel: return "airplane"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Task Priority
enum TaskPriority: String, Codable, CaseIterable {
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
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}

// MARK: - Task Status
enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case snoozed = "snoozed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .snoozed: return "Snoozed"
        }
    }
}

// MARK: - Notification State
enum NotificationState: String, Codable, CaseIterable {
    case none = "none"
    case scheduled = "scheduled"
    case delivered = "delivered"
    case failed = "failed"
    case dismissed = "dismissed"
    case actioned = "actioned"
    
    var displayName: String {
        switch self {
        case .none: return "No Notification"
        case .scheduled: return "Scheduled"
        case .delivered: return "Delivered"
        case .failed: return "Failed"
        case .dismissed: return "Dismissed"
        case .actioned: return "Actioned"
        }
    }
}

// MARK: - AI Confidence Level
enum AIConfidence: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
    
    var threshold: Double {
        switch self {
        case .low: return 0.0
        case .medium: return 0.4
        case .high: return 0.7
        case .veryHigh: return 0.9
        }
    }
    
    /// Convert numeric confidence value to enum case
    static func fromValue(_ value: Double) -> AIConfidence {
        let clampedValue = max(0.0, min(1.0, value))
        
        if clampedValue >= 0.9 {
            return .veryHigh
        } else if clampedValue >= 0.7 {
            return .high
        } else if clampedValue >= 0.4 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Task Energy Level
enum TaskEnergy: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low Energy"
        case .medium: return "Medium Energy"
        case .high: return "High Energy"
        }
    }
}

// MARK: - Task Difficulty Level
enum TaskDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

// MARK: - Enhanced Task Model
@Model
final class EnhancedTask {
    // MARK: - Core Properties
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var status: TaskStatus
    var priority: TaskPriority
    var type: TaskType
    var createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    var completedDate: Date? // Alias for completedAt for backward compatibility
    var dueDate: Date?
    
    // MARK: - AI Processing Properties
    var originalInput: String? // Original natural language input
    var aiParsedIntent: String? // AI's interpretation
    var aiConfidence: Double // 0.0 to 1.0
    var aiConfidenceLevel: AIConfidence
    var processingAttempts: Int // Track retry attempts
    var lastProcessingError: String?
    
    // MARK: - Scheduling Properties
    var schedule: EnhancedSchedule?
    var nextOccurrence: Date?
    var lastOccurrence: Date?
    var lastScheduledDate: Date? // Track when task was last scheduled
    var snoozeUntil: Date?
    var timezone: String // Store timezone for accurate scheduling
    
    // MARK: - Notification Properties
    var notificationState: NotificationState
    var notificationIdentifiers: String // Comma-separated notification IDs
    var notificationDeliveryAttempts: Int
    var lastNotificationAttempt: Date?
    var lastNotificationSuccess: Date?
    
    // MARK: - Organization Properties
    var tags: String // Comma-separated tags
    var category: String?
    var project: String?
    var context: String
    var estimatedDuration: Int // In minutes
    var energy: TaskEnergy
    var difficulty: TaskDifficulty
    
    // MARK: - Performance Properties
    var searchableContent: String // Pre-computed search index
    var sortOrder: Int // Manual sort order
    
    // MARK: - Validation Properties
    var isValid: Bool
    var validationErrors: String // Comma-separated validation errors
    var dataVersion: Int // For migration tracking
    
    // MARK: - Initialization
    init(
        title: String,
        notes: String = "",
        type: TaskType = .reminder,
        priority: TaskPriority = .medium,
        schedule: EnhancedSchedule? = nil,
        tags: [String] = [],
        context: String = "",
        estimatedDuration: Int = 0,
        energy: TaskEnergy = .medium,
        difficulty: TaskDifficulty = .medium,
        originalInput: String? = nil
    ) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.taskDescription = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = .pending
        self.priority = priority
        self.type = type
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.originalInput = originalInput
        self.aiConfidence = 0.0
        self.aiConfidenceLevel = .low
        self.processingAttempts = 0
        self.schedule = schedule
        self.notificationState = .none
        self.notificationIdentifiers = ""
        self.notificationDeliveryAttempts = 0
        self.tags = tags.joined(separator: ",")
        self.context = context
        self.estimatedDuration = estimatedDuration
        self.energy = energy
        self.difficulty = difficulty
        self.timezone = TimeZone.current.identifier
        self.searchableContent = ""
        self.sortOrder = 0
        self.isValid = false
        self.validationErrors = ""
        self.dataVersion = 1
        
        // Initial validation
        self.validate()
        self.updateSearchableContent()
    }
    
    // MARK: - Computed Properties
    var notes: String {
        get { taskDescription }
        set { taskDescription = newValue }
    }
    
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && !isCompleted
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var hasNotifications: Bool {
        return !notificationIdentifiers.isEmpty
    }
    
    var tagArray: [String] {
        get {
            guard !tags.isEmpty else { return [] }
            return tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ",")
        }
    }
    
    var notificationIDArray: [String] {
        get {
            guard !notificationIdentifiers.isEmpty else { return [] }
            return notificationIdentifiers.split(separator: ",").map { String($0) }
        }
        set {
            notificationIdentifiers = newValue.joined(separator: ",")
        }
    }
    
    var validationErrorArray: [String] {
        get {
            guard !validationErrors.isEmpty else { return [] }
            return validationErrors.split(separator: ",").map { String($0) }
        }
        set {
            validationErrors = newValue.joined(separator: ",")
        }
    }
    
    // MARK: - Methods
    func markCompleted() {
        status = .completed
        completedAt = Date()
        completedDate = completedAt // Keep in sync
        modifiedAt = Date()
        validate()
    }
    
    func markInProgress() {
        status = .inProgress
        modifiedAt = Date()
        validate()
    }
    
    func snooze(until: Date) {
        status = .snoozed
        snoozeUntil = until
        modifiedAt = Date()
        validate()
    }
    
    func updateTitle(_ newTitle: String) {
        title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        modifiedAt = Date()
        updateSearchableContent()
        validate()
    }
    
    func updateDescription(_ newDescription: String) {
        taskDescription = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        modifiedAt = Date()
        updateSearchableContent()
        validate()
    }
    
    func addTag(_ tag: String) {
        var tags = tagArray
        let cleanTag = tag.trimmingCharacters(in: .whitespaces)
        if !cleanTag.isEmpty && !tags.contains(cleanTag) {
            tags.append(cleanTag)
            tagArray = tags
            updateSearchableContent()
            validate()
        }
    }
    
    func removeTag(_ tag: String) {
        var tags = tagArray
        tags.removeAll { $0 == tag }
        tagArray = tags
        updateSearchableContent()
        validate()
    }
    
    func updatePriority(_ newPriority: TaskPriority) {
        priority = newPriority
        modifiedAt = Date()
        validate()
    }
    
    func updateSchedule(_ newSchedule: EnhancedSchedule?) {
        schedule = newSchedule
        modifiedAt = Date()
        validate()
    }
    
    func updateAIProcessing(intent: String?, confidence: Double, attempts: Int = 0) {
        aiParsedIntent = intent
        aiConfidence = max(0.0, min(1.0, confidence))
        aiConfidenceLevel = AIConfidence.fromValue(confidence)
        processingAttempts = attempts
        modifiedAt = Date()
        validate()
    }
    
    func recordNotificationAttempt(success: Bool) {
        notificationDeliveryAttempts += 1
        lastNotificationAttempt = Date()
        
        if success {
            lastNotificationSuccess = Date()
            notificationState = .delivered
        } else {
            notificationState = .failed
        }
        
        modifiedAt = Date()
        validate()
    }
    
    func clearNotifications() {
        notificationIdentifiers = ""
        notificationState = .none
        notificationDeliveryAttempts = 0
        lastNotificationAttempt = nil
        lastNotificationSuccess = nil
        modifiedAt = Date()
        validate()
    }
    
    // MARK: - Private Methods
    private func updateSearchableContent() {
        var content = [title, taskDescription]
        content.append(contentsOf: tagArray)
        if let category = category { content.append(category) }
        if let project = project { content.append(project) }
        if let aiIntent = aiParsedIntent { content.append(aiIntent) }
        if let originalInput = originalInput { content.append(originalInput) }
        
        searchableContent = content.joined(separator: " ").lowercased()
    }
    
    private func validate() {
        var errors: [String] = []
        
        // Title validation
        if title.isEmpty {
            errors.append("Title cannot be empty")
        } else if title.count > 500 {
            errors.append("Title too long (max 500 characters)")
        }
        
        // Description validation
        if taskDescription.count > 2000 {
            errors.append("Description too long (max 2000 characters)")
        }
        
        // AI confidence validation
        if aiConfidence < 0.0 || aiConfidence > 1.0 {
            errors.append("Invalid AI confidence value")
        }
        
        // Date validation
        if let dueDate = dueDate, dueDate < createdAt {
            errors.append("Due date cannot be before creation date")
        }
        
        // Snooze validation
        if let snoozeUntil = snoozeUntil, snoozeUntil < Date() {
            errors.append("Snooze date cannot be in the past")
        }
        
        // Status validation
        if status == .completed && completedAt == nil {
            errors.append("Completed tasks must have completion date")
        }
        
        validationErrorArray = errors
        isValid = errors.isEmpty
    }
} 