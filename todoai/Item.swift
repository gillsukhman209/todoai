//
//  Item.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import Foundation
import SwiftData
import CoreTransferable


@Model
final class Todo: Identifiable, Transferable {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    // MARK: - Scheduling Properties
    var dueDate: Date?
    var dueTime: Date?
    var recurrenceConfig: RecurrenceConfig?
    var originalInput: String? // Store the original natural language input
    var aiDescription: String? // Store AI-generated description/context
    
    // MARK: - Background Processing Properties
    var isProcessing: Bool = false // Track if OpenAI parsing is in progress
    var processingError: String? // Track any errors during background processing
    
    // MARK: - Ordering Properties
    var sortOrder: Int = 0 // For manual reordering
    
    // MARK: - Rich Data Properties (Phase 4)
    var priority: TaskPriority? // Task priority level (optional for migration)
    var category: TaskCategory? // Task category for organization (optional for migration)
    var completionDates: [Date] = [] // Track individual completions for recurring tasks
    var deletedDates: [Date] = [] // Track dates where recurring todo is hidden/deleted
    
    // MARK: - Computed Properties
    var isRecurring: Bool {
        return recurrenceConfig?.isRecurring ?? false
    }
    
    var hasTimeConstraints: Bool {
        return dueTime != nil || (recurrenceConfig?.hasTimeRange ?? false) || (recurrenceConfig?.hasMultipleTimes ?? false)
    }
    
    var displayTitle: String {
        return title
    }
    
    var scheduleDescription: String {
        guard let config = recurrenceConfig else {
            if let dueDate = dueDate {
                var dateTimeString = dueDate.dateString()
                if let dueTime = dueTime {
                    dateTimeString += " at \(dueTime.timeString())"
                }
                return "⏰ \(dateTimeString)"
            }
            return ""
        }
        
        switch config.type {
        case .none:
            return ""
        case .daily:
            if let timeRange = config.timeRange {
                return "Daily from \(timeRange.startTime.timeString()) to \(timeRange.endTime.timeString())"
            } else if !config.specificTimes.isEmpty {
                let times = config.specificTimes.map { $0.timeString() }.joined(separator: ", ")
                return "Daily at \(times)"
            } else {
                return "Daily"
            }
        case .weekly:
            return "Weekly"
        case .monthly:
            if let day = config.monthlyDay {
                return "Monthly on the \(day)\(day.ordinalSuffix)"
            }
            return "Monthly"
        case .hourly:
            if config.interval > 1 {
                return "Every \(config.interval) hours"
            }
            return "Hourly"
        case .customInterval:
            return "Every \(config.interval) \(config.interval == 1 ? "time" : "times")"
        case .specificDays:
            let days = config.weekdays.map { $0.shortName }.joined(separator: ", ")
            return "Weekly on \(days)"
        case .multipleDailyTimes:
            let times = config.specificTimes.map { $0.timeString() }.joined(separator: ", ")
            return "Daily at \(times)"
        case .yearly:
            return "Yearly"
        }
    }
    
    /// Get the next 4 upcoming reminders for this todo (for recurring tasks)
    var upcomingReminders: [String] {
        guard let config = recurrenceConfig, config.isRecurring else { return [] }
        // Use a fixed reference point (start of today) to prevent dynamic time updates
        let today = Calendar.current.startOfDay(for: Date())
        return config.getNextOccurrencesFormatted(count: 4, after: today)
    }
    
    /// Get a formatted string showing upcoming reminders
    var upcomingRemindersText: String {
        let reminders = upcomingReminders
        guard !reminders.isEmpty else { return "" }
        
        let prefix = reminders.count == 1 ? "Next reminder:" : "Next reminders:"
        return "\(prefix)\n" + reminders.prefix(4).map { "• \($0)" }.joined(separator: "\n")
    }
    
    // MARK: - Phase 4 Enhanced Properties
    
    /// Check if this todo is completed on a specific date (for recurring tasks)
    func isCompletedOnDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        
        // For simple todos, check overall completion status
        if !isRecurring {
            return isCompleted
        }
        
        // For recurring todos, check if this specific date is in completionDates
        return completionDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    /// Mark todo as completed on a specific date (for recurring tasks)
    func markCompletedOnDate(_ date: Date) {
        let calendar = Calendar.current
        
        // For simple todos, mark overall completion
        if !isRecurring {
            isCompleted = true
            return
        }
        
        // For recurring todos, add the date to completionDates if not already there
        let alreadyCompleted = completionDates.contains { calendar.isDate($0, inSameDayAs: date) }
        if !alreadyCompleted {
            completionDates.append(calendar.startOfDay(for: date))
        }
    }
    
    /// Check if this todo is deleted/hidden on a specific date (for recurring tasks)
    func isDeletedOnDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return deletedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    /// Mark todo as deleted/hidden on a specific date (for recurring tasks)
    func markDeletedOnDate(_ date: Date) {
        let calendar = Calendar.current
        
        // For recurring todos, add the date to deletedDates if not already there
        let alreadyDeleted = deletedDates.contains { calendar.isDate($0, inSameDayAs: date) }
        if !alreadyDeleted {
            deletedDates.append(calendar.startOfDay(for: date))
        }
    }
    
    /// Remove todo from deleted dates (restore it for a specific date)
    func restoreOnDate(_ date: Date) {
        let calendar = Calendar.current
        deletedDates.removeAll { calendar.isDate($0, inSameDayAs: date) }
    }
    
    /// Toggle completion status for a specific date (smart toggle for recurring tasks)
    func toggleCompletionOnDate(_ date: Date) {
        let calendar = Calendar.current
        
        // For simple todos, toggle overall completion
        if !isRecurring {
            isCompleted.toggle()
            return
        }
        
        // For recurring todos, toggle completion for this specific date
        if isCompletedOnDate(date) {
            // Remove from completion dates
            completionDates.removeAll { calendar.isDate($0, inSameDayAs: date) }
        } else {
            // Add to completion dates
            markCompletedOnDate(date)
        }
    }
    
    /// Priority display color for UI (with default fallback)
    var priorityColor: String {
        return (priority ?? .medium).color
    }
    
    /// Category icon for UI (with default fallback)
    var categoryIcon: String {
        return (category ?? .other).systemImage
    }
    
    /// Get actual priority with fallback to medium
    var actualPriority: TaskPriority {
        return priority ?? .medium
    }
    
    /// Get actual category with fallback to other
    var actualCategory: TaskCategory {
        return category ?? .other
    }
    
    init(title: String, originalInput: String? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.originalInput = originalInput
        self.sortOrder = Int(Date().timeIntervalSince1970) // Use timestamp for unique ordering
        
        // Set default values for new properties
        self.priority = .medium
        self.category = .other
    }
    
    // MARK: - Factory Methods
    static func from(parsedData: ParsedTaskData, originalInput: String) -> Todo {
        let todo = Todo(title: parsedData.cleanTitle, originalInput: originalInput)
        
        // Set due date/time for one-time tasks
        if let dueDateString = parsedData.dueDate {
            // Try enhanced date parsing first
            if let date = Date.from(dateString: dueDateString) {
                todo.dueDate = date
            } else {
                // Fallback to ISO8601 format
                todo.dueDate = ISO8601DateFormatter().date(from: dueDateString)
            }
        }
        
        if let dueTimeString = parsedData.dueTime {
            todo.dueTime = Date.from(timeString: dueTimeString)
        }
        
        // Set up recurrence if specified
        if parsedData.recurrenceType != "none" {
            let config = RecurrenceConfig()
            
            // Map recurrence type properly
            switch parsedData.recurrenceType {
            case "specific_days":
                config.type = .specificDays
            case "custom_interval":
                config.type = .customInterval
            case "multiple_daily_times":
                config.type = .multipleDailyTimes
            default:
                if let recurrenceType = RecurrenceType(rawValue: parsedData.recurrenceType) {
                    config.type = recurrenceType
                }
            }
            
            config.interval = parsedData.interval ?? 1
            config.monthlyDay = parsedData.monthlyDay
            
            // Handle specific weekdays
            if let weekdayStrings = parsedData.specificWeekdays {
                config.specificWeekdays = weekdayStrings.compactMap { dayString in
                    Weekday.allCases.first { $0.name.lowercased() == dayString.lowercased() }?.rawValue
                }
            }
            
            // Handle specific times (for specific_days and multiple_daily_times)
            if let timeStrings = parsedData.specificTimes {
                config.specificTimes = timeStrings.compactMap { Date.from(timeString: $0) }
            }
            
            // Handle time ranges
            if let startTime = parsedData.timeRangeStart,
               let endTime = parsedData.timeRangeEnd,
               let start = Date.from(timeString: startTime),
               let end = Date.from(timeString: endTime) {
                config.timeRange = TimeRange(startTime: start, endTime: end)
            }
            
            todo.recurrenceConfig = config
        }
        
        todo.aiDescription = parsedData.description
        
        // Set priority from AI parsing with fallback to medium
        if let priorityString = parsedData.priority {
            todo.priority = TaskPriority(rawValue: priorityString) ?? .medium
        } else {
            todo.priority = .medium
        }
        
        // Set category from AI parsing with fallback to other
        if let categoryString = parsedData.category {
            todo.category = TaskCategory(rawValue: categoryString) ?? .other
        } else {
            todo.category = .other
        }
        
        return todo
    }
    
    // MARK: - Transferable Conformance
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .data) { todo in
            try JSONEncoder().encode(TodoReference(id: todo.id))
        } importing: { data in
            let reference = try JSONDecoder().decode(TodoReference.self, from: data)
            // This is a placeholder - the actual todo will be found by ID in the drop handler
            return Todo(title: "placeholder")
        }
    }
}

// MARK: - Transfer Reference
struct TodoReference: Codable, Transferable {
    let id: UUID
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}



// MARK: - Helper Extensions
extension Int {
    var ordinalSuffix: String {
        let lastDigit = self % 10
        let lastTwoDigits = self % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "th"
        }
        
        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
