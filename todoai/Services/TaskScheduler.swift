//
//  TaskScheduler.swift
//  todoai
//
//  Created by AI Assistant on 1/4/25.
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - Scheduling Result
enum SchedulingResult {
    case success
    case permissionDenied
    case invalidDate
    case schedulingFailed(String)
}

// MARK: - Task Scheduler
@MainActor
class TaskScheduler: ObservableObject {
    static let shared = TaskScheduler()
    
    @Published var isSchedulingTasks = false
    @Published var scheduledTasksCount = 0
    
    private let notificationService = NotificationService.shared
    private let logger = StructuredLogger.shared
    
    private init() {
        // TaskScheduler initialization
        // Note: NotificationDelegate handles notification actions
    }
    
    // MARK: - Task Scheduling
    
    /// Schedule notifications for a task
    func scheduleTask(_ task: EnhancedTask) async -> SchedulingResult {
        guard notificationService.permissionStatus == .authorized || 
              notificationService.permissionStatus == .provisional else {
            return .permissionDenied
        }
        
        do {
            if task.schedule?.type == .once {
                try await notificationService.scheduleNotification(for: task)
            } else {
                try await notificationService.scheduleRecurringNotifications(for: task)
            }
            
            // Update task notification state
            task.notificationState = .scheduled
            task.lastScheduledDate = Date()
            
            await updateScheduledTasksCount()
            
            logger.info("Successfully scheduled task: \(task.title)")
            return .success
            
        } catch let error as NotificationError {
            logger.error("Failed to schedule task", error: error)
            task.notificationState = .failed
            
            switch error {
            case .permissionDenied:
                return .permissionDenied
            case .invalidDate:
                return .invalidDate
            case .schedulingFailed(let reason):
                return .schedulingFailed(reason)
            default:
                return .schedulingFailed(error.localizedDescription)
            }
        } catch {
            logger.error("Unexpected error scheduling task", error: error)
            return .schedulingFailed(error.localizedDescription)
        }
    }
    
    /// Convert existing Todo to EnhancedTask and schedule
    func convertAndScheduleTask(_ todo: Todo, withSchedule schedule: EnhancedSchedule) async -> SchedulingResult {
        logger.info("Converting and scheduling task: '\(todo.title)'")
        logger.info("Schedule details: type=\(schedule.type), weekdays=\(schedule.weekdays?.map { $0.rawValue } ?? []), timeRange=\(schedule.timeRange?.startTime.formatted(date: .abbreviated, time: .shortened) ?? "nil")")
        
        let enhancedTask = EnhancedTask(
            title: todo.title,
            notes: "",
            type: .reminder,
            priority: .medium,
            schedule: schedule,
            tags: [],
            context: "",
            estimatedDuration: 0,
            energy: .medium,
            difficulty: .medium
        )
        
        logger.info("Created EnhancedTask with ID: \(enhancedTask.id)")
        
        let result = await scheduleTask(enhancedTask)
        
        // Update the original Todo with schedule information if successful
        if case .success = result {
            updateTodoWithScheduleInfo(todo, schedule: schedule)
            logger.info("Successfully scheduled and updated Todo: '\(todo.title)'")
        } else {
            logger.error("Failed to schedule task: '\(todo.title)' - Result: \(result)")
        }
        
        return result
    }
    
    /// Update Todo with schedule information
    private func updateTodoWithScheduleInfo(_ todo: Todo, schedule: EnhancedSchedule) {
        // Set due date and time for one-time tasks
        if schedule.type == .once {
            todo.dueDate = schedule.startDate
            todo.dueTime = schedule.timeRange?.startTime ?? schedule.startDate
        } else {
            // For recurring tasks, create a RecurrenceConfig
            let config = RecurrenceConfig()
            
            // Map EnhancedRecurrenceType to RecurrenceType
            switch schedule.type {
            case .daily:
                config.type = .daily
            case .weekly:
                config.type = .weekly
            case .monthly:
                config.type = .monthly
            case .yearly:
                config.type = .yearly
            case .weekdays:
                config.type = .specificDays
                // Use actual weekdays from schedule, or default to Monday-Friday
                if let weekdays = schedule.weekdays {
                    config.specificWeekdays = weekdays.map { $0.rawValue }
                } else {
                    config.specificWeekdays = [1, 2, 3, 4, 5] // Monday to Friday
                }
            default:
                config.type = .daily // Default fallback
            }
            
            config.interval = schedule.interval
            
            // Set time range if available
            if let timeRange = schedule.timeRange {
                config.timeRange = TimeRange(
                    startTime: timeRange.startTime,
                    endTime: timeRange.endTime
                )
                
                // Also set specificTimes for recurring tasks that need specific times
                // This is crucial for calculateNextSpecificDaysOccurrence to work properly
                config.specificTimes = [timeRange.startTime]
            }
            
            todo.recurrenceConfig = config
        }
    }
    
    /// Schedule a quick reminder for a specific date/time
    func scheduleQuickReminder(
        title: String,
        date: Date,
        notes: String = "",
        priority: TaskPriority = .medium
    ) async -> SchedulingResult {
        let schedule = EnhancedSchedule(
            type: .once,
            interval: 1,
            startDate: date,
            endDate: nil,
            timezone: TimeZone.current.identifier
        )
        
        // Set up time range after initialization
        let timeRange = EnhancedTimeRange(
            startTime: date,
            endTime: date.addingTimeInterval(3600), // 1 hour duration
            timezone: TimeZone.current.identifier
        )
        schedule.timeRange = timeRange
        
        let task = EnhancedTask(
            title: title,
            notes: notes,
            type: .reminder,
            priority: priority,
            schedule: schedule,
            tags: [],
            context: "",
            estimatedDuration: 0,
            energy: .medium,
            difficulty: .medium
        )
        
        return await scheduleTask(task)
    }
    
    /// Reschedule a task to a new date/time
    func rescheduleTask(_ task: EnhancedTask, to newDate: Date) async -> SchedulingResult {
        // Cancel existing notifications
        await notificationService.cancelAllNotifications(for: task.id)
        
        // Update schedule
        task.schedule?.startDate = newDate
        task.schedule?.timeRange?.start = Calendar.current.dateComponents([.hour, .minute], from: newDate)
        
        // Reschedule
        return await scheduleTask(task)
    }
    
    /// Cancel scheduling for a task
    func cancelTaskScheduling(_ task: EnhancedTask) async {
        await notificationService.cancelAllNotifications(for: task.id)
        task.notificationState = .none
        
        await updateScheduledTasksCount()
        
        logger.info("Cancelled scheduling for task: \(task.title)")
    }
    
    /// Handle task completion
    func markTaskCompleted(_ task: EnhancedTask) async {
        // Cancel future notifications
        await notificationService.cancelAllNotifications(for: task.id)
        
        // Update task state
        task.status = .completed
        task.completedDate = Date()
        task.notificationState = .none
        
        // If it's a recurring task, schedule the next occurrence
        if task.schedule?.type != .once {
            _ = await scheduleTask(task)
        }
        
        await updateScheduledTasksCount()
        
        logger.info("Marked task completed: \(task.title)")
    }
    
    // MARK: - Batch Operations
    
    /// Schedule multiple tasks at once
    func scheduleTasks(_ tasks: [EnhancedTask]) async -> [SchedulingResult] {
        isSchedulingTasks = true
        defer { isSchedulingTasks = false }
        
        var results: [SchedulingResult] = []
        
        for task in tasks {
            let result = await scheduleTask(task)
            results.append(result)
        }
        
        return results
    }
    
    /// Refresh all scheduled notifications
    func refreshAllScheduledTasks(_ tasks: [EnhancedTask]) async {
        isSchedulingTasks = true
        defer { isSchedulingTasks = false }
        
        // Cancel all existing notifications
        notificationService.cancelAllNotifications()
        
        // Reschedule all active tasks
        for task in tasks where task.status != .completed && task.status != .cancelled {
            _ = await scheduleTask(task)
        }
        
        logger.info("Refreshed all scheduled tasks")
    }
    
    // MARK: - Utilities
    
    /// Get the next scheduled notification date for a task
    func getNextScheduledDate(for task: EnhancedTask) -> Date? {
        return task.schedule?.nextOccurrence()
    }
    
    /// Check if a task is scheduled
    func isTaskScheduled(_ task: EnhancedTask) -> Bool {
        return task.notificationState == .scheduled
    }
    
    /// Update the count of scheduled tasks
    private func updateScheduledTasksCount() async {
        scheduledTasksCount = await notificationService.getPendingNotificationsCount()
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions if needed
    func requestNotificationPermissionIfNeeded() async -> Bool {
        if notificationService.permissionStatus == .notRequested {
            return await notificationService.requestPermission()
        }
        return notificationService.permissionStatus == .authorized || 
               notificationService.permissionStatus == .provisional
    }
    
    /// Check and handle permission status
    func checkPermissionStatus() -> NotificationPermissionStatus {
        return notificationService.permissionStatus
    }
    
    /// Debug method to check all scheduled notifications
    func debugScheduledNotifications() async {
        print("🔔 debugScheduledNotifications() called")
        
        // Check permissions first
        let permissionStatus = notificationService.permissionStatus
        print("🔔 Notification permission status: \(permissionStatus)")
        
        let notifications = await notificationService.getAllPendingNotifications()
        
        print("=== SCHEDULED NOTIFICATIONS DEBUG ===")
        print("Total scheduled notifications: \(notifications.count)")
        print("Permission status: \(permissionStatus)")
        
        logger.info("=== SCHEDULED NOTIFICATIONS DEBUG ===")
        logger.info("Total scheduled notifications: \(notifications.count)")
        logger.info("Permission status: \(permissionStatus)")
        
        for (index, notification) in notifications.enumerated() {
            let triggerDateString = notification.triggerDate?.formatted(date: .abbreviated, time: .shortened) ?? "No trigger date"
            print("[\(index + 1)] '\(notification.title)' - ID: \(notification.identifier) - Trigger: \(triggerDateString)")
            logger.info("[\(index + 1)] '\(notification.title)' - ID: \(notification.identifier) - Trigger: \(triggerDateString)")
        }
        
        if notifications.isEmpty {
            print("⚠️ No notifications are scheduled!")
            logger.warning("⚠️ No notifications are scheduled!")
        }
        
        print("=== END DEBUG ===")
        logger.info("=== END DEBUG ===")
    }
}

// MARK: - Notification Integration
extension TaskScheduler {
    
    /// Handle notification action (called by NotificationDelegate)
    func handleNotificationAction(
        _ actionIdentifier: String,
        taskId: UUID,
        userInfo: [AnyHashable: Any]
    ) async {
        
        switch actionIdentifier {
        case "COMPLETE_ACTION", "MARK_DONE_ACTION":
            // Find and mark task as completed
            // This would need to be connected to the actual data model
            logger.info("Task completed via notification: \(taskId)")
            
        case "SNOOZE_ACTION":
            // Snooze for 15 minutes
            do {
                try await notificationService.snoozeNotification(taskId: taskId, minutes: 15)
                logger.info("Task snoozed for 15 minutes: \(taskId)")
            } catch {
                logger.error("Failed to snooze task", error: error)
            }
            
        case "POSTPONE_ACTION":
            // Postpone for 1 hour
            do {
                try await notificationService.snoozeNotification(taskId: taskId, minutes: 60)
                logger.info("Task postponed for 1 hour: \(taskId)")
            } catch {
                logger.error("Failed to postpone task", error: error)
            }
            
        case "SKIP_ACTION":
            // Skip for today (for habits)
            logger.info("Task skipped for today: \(taskId)")
            
        case "VIEW_PROJECT_ACTION":
            // Open project view
            logger.info("Opening project view for: \(taskId)")
            
        case "ADD_ITEM_ACTION":
            // Add item to shopping list
            logger.info("Adding item to shopping list: \(taskId)")
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            logger.info("User opened app from notification: \(taskId)")
            
        default:
            logger.info("Unknown notification action: \(actionIdentifier)")
        }
    }
}

// MARK: - Convenience Extensions
extension TaskScheduler {
    
    /// Create a daily habit reminder
    func createDailyHabit(
        title: String,
        time: DateComponents,
        notes: String = ""
    ) async -> SchedulingResult {
        let schedule = EnhancedSchedule(
            type: .daily,
            interval: 1,
            startDate: Date(),
            endDate: nil,
            timezone: TimeZone.current.identifier
        )
        
        // Set up time range after initialization
        let startTime = Calendar.current.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
        
        let timeRange = EnhancedTimeRange(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600), // 1 hour duration
            timezone: TimeZone.current.identifier
        )
        schedule.timeRange = timeRange
        
        let task = EnhancedTask(
            title: title,
            notes: notes,
            type: .habit,
            priority: .medium,
            schedule: schedule,
            tags: ["habit"],
            context: "",
            estimatedDuration: 0,
            energy: .medium,
            difficulty: .medium
        )
        
        return await scheduleTask(task)
    }
    
    /// Create a weekly recurring reminder
    func createWeeklyReminder(
        title: String,
        weekday: EnhancedWeekday,
        time: DateComponents,
        notes: String = ""
    ) async -> SchedulingResult {
        let schedule = EnhancedSchedule(
            type: .weekly,
            interval: 1,
            startDate: Date(),
            endDate: nil,
            timezone: TimeZone.current.identifier
        )
        
        // Set up time range after initialization
        let startTime = Calendar.current.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
        
        let timeRange = EnhancedTimeRange(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600), // 1 hour duration
            timezone: TimeZone.current.identifier
        )
        schedule.timeRange = timeRange
        
        // Set specific weekday
        schedule.weekdays = [weekday]
        
        let task = EnhancedTask(
            title: title,
            notes: notes,
            type: .reminder,
            priority: .medium,
            schedule: schedule,
            tags: ["weekly"],
            context: "",
            estimatedDuration: 0,
            energy: .medium,
            difficulty: .medium
        )
        
        return await scheduleTask(task)
    }
} 
