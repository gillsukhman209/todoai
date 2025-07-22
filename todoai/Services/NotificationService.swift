//
//  NotificationService.swift
//  todoai
//
//  Created by AI Assistant on 1/4/25.
//

import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Permission Status
enum NotificationPermissionStatus {
    case notRequested
    case denied
    case authorized
    case provisional
    case ephemeral
}

// MARK: - Notification Error
enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed(String)
    case invalidDate
    case notificationNotFound
    case systemError(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed(let reason):
            return "Failed to schedule notification: \(reason)"
        case .invalidDate:
            return "Invalid notification date"
        case .notificationNotFound:
            return "Notification not found"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Categories
enum NotificationCategory: String, CaseIterable {
    case taskReminder = "TASK_REMINDER"
    case habitReminder = "HABIT_REMINDER"
    case projectDeadline = "PROJECT_DEADLINE"
    case shoppingReminder = "SHOPPING_REMINDER"
    case pomodoroAlert = "POMODORO_ALERT"
    
    var identifier: String { rawValue }
    
    var actions: [UNNotificationAction] {
        switch self {
        case .taskReminder:
            return [
                UNNotificationAction(
                    identifier: "COMPLETE_ACTION",
                    title: "Complete",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SNOOZE_ACTION",
                    title: "Snooze 15 min",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "POSTPONE_ACTION",
                    title: "Postpone 1 hour",
                    options: []
                )
            ]
        case .habitReminder:
            return [
                UNNotificationAction(
                    identifier: "MARK_DONE_ACTION",
                    title: "Mark Done",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SKIP_ACTION",
                    title: "Skip Today",
                    options: []
                )
            ]
        case .projectDeadline:
            return [
                UNNotificationAction(
                    identifier: "VIEW_PROJECT_ACTION",
                    title: "View Project",
                    options: [.foreground]
                )
            ]
        case .shoppingReminder:
            return [
                UNNotificationAction(
                    identifier: "COMPLETE_ACTION",
                    title: "Complete",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "ADD_ITEM_ACTION",
                    title: "Add Item",
                    options: [.foreground]
                )
            ]
        case .pomodoroAlert:
            return [
                UNNotificationAction(
                    identifier: "START_BREAK_ACTION",
                    title: "Start Break",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "START_WORK_ACTION",
                    title: "Start Work",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS_ACTION",
                    title: "Dismiss",
                    options: []
                )
            ]
        }
    }
}

// MARK: - Notification Service
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var permissionStatus: NotificationPermissionStatus = .notRequested
    @Published var isProcessingPermission = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let logger = StructuredLogger.shared
    
    private init() {
        setupNotificationCategories()
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions with comprehensive options
    func requestPermission() async -> Bool {
        isProcessingPermission = true
        defer { isProcessingPermission = false }
        
        do {
            let options: UNAuthorizationOptions = [
                .alert,
                .badge,
                .sound,
                .provisional
            ]
            
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await updatePermissionStatus()
            
            if granted {
                logger.info("Notification permission granted")
                return true
            } else {
                logger.warning("Notification permission denied")
                return false
            }
        } catch {
            logger.error("Failed to request notification permission", error: error)
            return false
        }
    }
    
    /// Check current permission status
    func checkPermissionStatus() {
        Task {
            await updatePermissionStatus()
        }
    }
    
    private func updatePermissionStatus() async {
        let settings = await notificationCenter.notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            permissionStatus = .notRequested
        case .denied:
            permissionStatus = .denied
        case .authorized:
            permissionStatus = .authorized
        case .provisional:
            permissionStatus = .provisional
        case .ephemeral:
            permissionStatus = .ephemeral
        @unknown default:
            permissionStatus = .notRequested
        }
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule a notification for a task
    func scheduleNotification(for task: EnhancedTask) async throws {
        guard permissionStatus == .authorized || permissionStatus == .provisional else {
            throw NotificationError.permissionDenied
        }
        
        // Clean up old notifications before scheduling new ones
        await cleanupOldNotifications()
        
        guard let nextOccurrence = task.schedule?.nextOccurrence() else {
            throw NotificationError.invalidDate
        }
        
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = createNotificationBody(for: task)
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = task.type.notificationCategory.identifier
        
        // Add custom user info
        content.userInfo = [
            "taskId": task.id.uuidString,
            "taskType": task.type.rawValue,
            "priority": task.priority.rawValue
        ]
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextOccurrence),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            logger.info("Scheduled notification for task: \(task.title)")
        } catch {
            logger.error("Failed to schedule notification", error: error)
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }
    
    /// Schedule recurring notifications for a task
    func scheduleRecurringNotifications(for task: EnhancedTask) async throws {
        guard let schedule = task.schedule else {
            throw NotificationError.invalidDate
        }
        
        // Clean up old notifications before scheduling new ones
        await cleanupOldNotifications()
        
        logger.info("Scheduling recurring notifications for task: '\(task.title)'")
        logger.info("Schedule type: \(schedule.type), weekdays: \(schedule.weekdays?.map { $0.rawValue } ?? [])")
        logger.info("Schedule timeRange: \(schedule.timeRange?.startTime.formatted(date: .abbreviated, time: .shortened) ?? "nil")")
        
        print("🔔 Scheduling recurring notifications for: '\(task.title)'")
        print("🔔 Schedule type: \(schedule.type)")
        print("🔔 Schedule weekdays: \(schedule.weekdays?.map { $0.rawValue } ?? [])")
        print("🔔 Schedule timeRange: \(schedule.timeRange?.startTime.formatted(date: .abbreviated, time: .shortened) ?? "nil")")
        
        // Schedule up to 64 notifications (iOS limit)
        let maxNotifications = 64
        var currentDate = Date()
        var successfullyScheduled = 0
        
        // Check notifications before scheduling
        let notificationsBefore = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        print("🔔 Notifications before scheduling: \(notificationsBefore.count)")
        
        for i in 0..<maxNotifications {
            guard let nextOccurrence = schedule.calculateNextOccurrence(after: currentDate) else {
                print("🔔 No more occurrences found after \(currentDate.formatted(date: .abbreviated, time: .shortened))")
                logger.info("No more occurrences found after \(currentDate.formatted(date: .abbreviated, time: .shortened))")
                break
            }
            
            print("🔔 Scheduling notification \(i + 1): \(nextOccurrence.formatted(date: .abbreviated, time: .shortened))")
            logger.info("Scheduling notification \(i + 1): \(nextOccurrence.formatted(date: .abbreviated, time: .shortened))")
            
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = createNotificationBody(for: task)
            content.sound = .default
            content.badge = 1
            content.categoryIdentifier = task.type.notificationCategory.identifier
            
            content.userInfo = [
                "taskId": task.id.uuidString,
                "taskType": task.type.rawValue,
                "priority": task.priority.rawValue,
                "occurrenceNumber": i + 1
            ]
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextOccurrence),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "\(task.id.uuidString)-\(i)",
                content: content,
                trigger: trigger
            )
            
            do {
                print("🔔 Attempting to schedule notification \(i + 1) with ID: \(request.identifier)")
                try await notificationCenter.add(request)
                print("✅ Successfully scheduled notification \(i + 1) for \(nextOccurrence.formatted(date: .abbreviated, time: .shortened))")
                logger.info("✅ Successfully scheduled notification \(i + 1) for \(nextOccurrence.formatted(date: .abbreviated, time: .shortened))")
                successfullyScheduled += 1
            } catch {
                print("❌ Failed to schedule notification \(i + 1): \(error.localizedDescription)")
                logger.error("❌ Failed to schedule notification \(i + 1): \(error.localizedDescription)")
            }
            
            currentDate = nextOccurrence
        }
        
        // Verify notifications were actually scheduled
        let notificationsAfter = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        print("🔔 Notifications after scheduling: \(notificationsAfter.count)")
        print("🔔 Successfully scheduled \(successfullyScheduled) out of \(maxNotifications) attempted notifications")
        
        logger.info("Scheduled recurring notifications for task: \(task.title) - \(successfullyScheduled) successful")
    }
    
    // MARK: - Notification Management
    
    /// Cancel notification for a specific task
    func cancelNotification(for taskId: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
        logger.info("Cancelled notification for task: \(taskId)")
    }
    
    /// Cancel all notifications for a task (including recurring)
    func cancelAllNotifications(for taskId: UUID) async {
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        let identifiersToCancel = requests.compactMap { request in
            request.identifier.starts(with: taskId.uuidString) ? request.identifier : nil
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        logger.info("Cancelled all notifications for task: \(taskId)")
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        logger.info("Cancelled all pending notifications")
    }
    
    /// Clean up old and expired notifications to stay under iOS 64 notification limit
    func cleanupOldNotifications() async {
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        print("🧹 Found \(requests.count) pending notifications before cleanup")
        
        guard requests.count > 50 else { // Start cleanup when we have more than 50
            print("🧹 Notification count (\(requests.count)) is acceptable, no cleanup needed")
            return
        }
        
        let now = Date()
        var toRemove: [String] = []
        
        // Remove expired notifications first
        for request in requests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate(),
               nextTriggerDate < now {
                toRemove.append(request.identifier)
            }
        }
        
        // If we still have too many, remove the oldest ones
        if requests.count - toRemove.count > 50 {
            let sortedRequests = requests.compactMap { request -> (request: UNNotificationRequest, date: Date)? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let triggerDate = trigger.nextTriggerDate() else { return nil }
                return (request, triggerDate)
            }.sorted { $0.date < $1.date }
            
            let targetCount = 45 // Keep 45 notifications, remove the rest
            if sortedRequests.count > targetCount {
                let oldestToRemove = sortedRequests.prefix(sortedRequests.count - targetCount)
                toRemove.append(contentsOf: oldestToRemove.map { $0.request.identifier })
            }
        }
        
        if !toRemove.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: toRemove)
            print("🧹 Removed \(toRemove.count) old notifications")
            logger.info("Cleaned up \(toRemove.count) old notifications")
        }
        
        let remainingCount = requests.count - toRemove.count
        print("🧹 Cleanup complete. Remaining notifications: \(remainingCount)")
    }
    
    /// Get pending notifications count
    func getPendingNotificationsCount() async -> Int {
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        return requests.count
    }
    
    /// Get all pending notifications with details (for debugging)
    func getAllPendingNotifications() async -> [(identifier: String, title: String, triggerDate: Date?)] {
        print("🔔 getAllPendingNotifications() called")
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        print("🔔 Found \(requests.count) pending notification requests")
        
        return requests.map { request in
            let triggerDate: Date?
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                triggerDate = calendarTrigger.nextTriggerDate()
            } else {
                triggerDate = nil
            }
            
            return (
                identifier: request.identifier,
                title: request.content.title,
                triggerDate: triggerDate
            )
        }
    }
    
    /// Check if a task has scheduled notifications
    func hasScheduledNotifications(for taskId: UUID) async -> Bool {
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        return requests.contains { request in
            request.identifier.starts(with: taskId.uuidString)
        }
    }
    
    /// Snooze a notification by specified minutes
    func snoozeNotification(taskId: UUID, minutes: Int = 15) async throws {
        let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        // Cancel existing notification
        cancelNotification(for: taskId)
        
        // Create new notification for snooze time
        let content = UNMutableNotificationContent()
        content.title = "Snoozed Reminder"
        content.body = "Your reminder is back!"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "taskId": taskId.uuidString,
            "isSnoozed": true
        ]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: snoozeDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(taskId.uuidString)-snoozed",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        logger.info("Snoozed notification for \(minutes) minutes")
    }
    
    // MARK: - Pomodoro Notifications
    
    /// Send immediate notification for Pomodoro session completion
    func sendPomodoroNotification(title: String, body: String, sessionId: UUID, isWorkSession: Bool) async throws {
        guard permissionStatus == .authorized || permissionStatus == .provisional else {
            throw NotificationError.permissionDenied
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = NotificationCategory.pomodoroAlert.identifier
        
        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "isWorkSession": isWorkSession,
            "type": "pomodoro_completion"
        ]
        
        // Use immediate trigger for instant notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "pomodoro-\(sessionId.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            logger.info("Sent Pomodoro notification: \(title)")
        } catch {
            logger.error("Failed to send Pomodoro notification", error: error)
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }
    
    /// Schedule notification for when Pomodoro session will complete
    func schedulePomodoroCompletionNotification(sessionName: String, completionDate: Date, sessionId: UUID, isWorkSession: Bool) async throws {
        guard permissionStatus == .authorized || permissionStatus == .provisional else {
            throw NotificationError.permissionDenied
        }
        
        let content = UNMutableNotificationContent()
        content.title = isWorkSession ? "Work Session Complete!" : "Break Complete!"
        content.body = isWorkSession ? "Time for a break! Great job on '\(sessionName)'" : "Break's over! Ready to get back to work?"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = NotificationCategory.pomodoroAlert.identifier
        
        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "isWorkSession": isWorkSession,
            "type": "pomodoro_completion",
            "sessionName": sessionName
        ]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: completionDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "pomodoro-scheduled-\(sessionId.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            logger.info("Scheduled Pomodoro completion notification for: \(completionDate)")
        } catch {
            logger.error("Failed to schedule Pomodoro completion notification", error: error)
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }
    
    /// Cancel Pomodoro notifications for a session
    func cancelPomodoroNotifications(sessionId: UUID) {
        let identifiers = [
            "pomodoro-\(sessionId.uuidString)",
            "pomodoro-scheduled-\(sessionId.uuidString)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        logger.info("Cancelled Pomodoro notifications for session: \(sessionId)")
    }
    
    // MARK: - Private Helpers
    
    private func setupNotificationCategories() {
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions,
                intentIdentifiers: [],
                options: []
            )
        }
        
        notificationCenter.setNotificationCategories(Set(categories))
    }
    
    private func createNotificationBody(for task: EnhancedTask) -> String {
        switch task.type {
        case .reminder:
            return task.notes.isEmpty ? "Time for your reminder!" : task.notes
        case .habit:
            return "Don't forget your daily habit!"
        case .project:
            return "Project deadline approaching"
        case .shopping:
            return "Shopping reminder"
        case .work:
            return "Work task reminder"
        case .personal:
            return "Personal task reminder"
        case .health:
            return "Health reminder"
        case .finance:
            return "Finance task reminder"
        case .social:
            return "Social reminder"
        case .learning:
            return "Learning reminder"
        case .maintenance:
            return "Maintenance reminder"
        case .travel:
            return "Travel reminder"
        case .other:
            return "Task reminder"
        }
    }
}

// MARK: - Task Type Extension
extension TaskType {
    var notificationCategory: NotificationCategory {
        switch self {
        case .reminder, .work, .personal, .health, .finance, .social, .learning, .maintenance, .travel, .other:
            return .taskReminder
        case .habit:
            return .habitReminder
        case .project:
            return .projectDeadline
        case .shopping:
            return .shoppingReminder
        }
    }
} 