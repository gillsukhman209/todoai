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
        
        // Schedule up to 64 notifications (iOS limit)
        let maxNotifications = 64
        var currentDate = Date()
        
        for i in 0..<maxNotifications {
            guard let nextOccurrence = schedule.calculateNextOccurrence(after: currentDate) else {
                break
            }
            
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
            
            try await notificationCenter.add(request)
            currentDate = nextOccurrence
        }
        
        logger.info("Scheduled recurring notifications for task: \(task.title)")
    }
    
    // MARK: - Notification Management
    
    /// Cancel notification for a specific task
    func cancelNotification(for taskId: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
        logger.info("Cancelled notification for task: \(taskId)")
    }
    
    /// Cancel all notifications for a task (including recurring)
    func cancelAllNotifications(for taskId: UUID) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiersToCancel = requests.compactMap { request in
                request.identifier.starts(with: taskId.uuidString) ? request.identifier : nil
            }
            
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            self.logger.info("Cancelled all notifications for task: \(taskId)")
        }
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        logger.info("Cancelled all pending notifications")
    }
    
    /// Get pending notifications count
    func getPendingNotificationsCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
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