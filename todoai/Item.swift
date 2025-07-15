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
    
    // MARK: - Scheduling Properties
    var dueDate: Date?
    var dueTime: Date?
    var recurrenceConfig: RecurrenceConfig?
    var originalInput: String? // Store the original natural language input
    var aiDescription: String? // Store AI-generated description/context
    
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
    
    init(title: String, originalInput: String? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.originalInput = originalInput
    }
    
    // MARK: - Factory Methods
    static func from(parsedData: ParsedTaskData, originalInput: String) -> Todo {
        let todo = Todo(title: parsedData.cleanTitle, originalInput: originalInput)
        
        // Set due date/time for one-time tasks
        if let dueDateString = parsedData.dueDate {
            todo.dueDate = ISO8601DateFormatter().date(from: dueDateString)
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
        
        return todo
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
