//
//  NotificationDelegate.swift
//  todoai
//
//  Created by AI Assistant on 1/4/25.
//

import Foundation
import UserNotifications
import SwiftData
import SwiftUI

// MARK: - Notification Delegate
@MainActor
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    @Published var lastNotificationAction: String?
    @Published var shouldShowApp = false
    
    private let taskScheduler = TaskScheduler.shared
    private let notificationService = NotificationService.shared
    private let logger = StructuredLogger.shared
    
    var modelContext: ModelContext?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.info("Notification received while app is active")
        
        // Show notification with banner, sound, and badge
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        logger.info("Notification action received: \(actionIdentifier)")
        
        Task {
            await handleNotificationAction(actionIdentifier, userInfo: userInfo)
            completionHandler()
        }
    }
    
    // MARK: - Action Handling
    
    private func handleNotificationAction(_ actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        
        guard let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            logger.error("Invalid task ID in notification")
            return
        }
        
        lastNotificationAction = actionIdentifier
        
        // Handle data model updates and UI actions
        switch actionIdentifier {
        case "COMPLETE_ACTION", "MARK_DONE_ACTION":
            await handleCompleteAction(taskId: taskId)
            
        case "VIEW_PROJECT_ACTION", "ADD_ITEM_ACTION", UNNotificationDefaultActionIdentifier:
            await handleDefaultAction(taskId: taskId)
            
        default:
            break
        }
        
        // Delegate to TaskScheduler for notification-specific actions
        await taskScheduler.handleNotificationAction(actionIdentifier, taskId: taskId, userInfo: userInfo)
    }
    
    // MARK: - Specific Action Handlers
    
    private func handleCompleteAction(taskId: UUID) async {
        logger.info("Completing task from notification: \(taskId)")
        
        // Try to find the task in the current model context
        if let context = modelContext {
            let descriptor = FetchDescriptor<Todo>()
            do {
                let todos = try context.fetch(descriptor)
                if let todo = todos.first(where: { $0.id == taskId }) {
                    todo.isCompleted = true
                    try context.save()
                    logger.info("Task marked as completed: \(todo.title)")
                } else {
                    logger.warning("Task not found for completion: \(taskId)")
                }
            } catch {
                logger.error("Error completing task", error: error)
            }
        }
        
        // Cancel future notifications for this task
        notificationService.cancelAllNotifications(for: taskId)
    }
    

    
    private func handleDefaultAction(taskId: UUID) async {
        logger.info("Default action (tap) for task: \(taskId)")
        
        // Show the app when user taps the notification
        shouldShowApp = true
    }
    
    // MARK: - Utility Methods
    
    /// Update task status in the data model
    func updateTaskStatus(taskId: UUID, isCompleted: Bool) async {
        guard let context = modelContext else {
            logger.error("Model context not available")
            return
        }
        
        let descriptor = FetchDescriptor<Todo>()
        do {
            let todos = try context.fetch(descriptor)
            if let todo = todos.first(where: { $0.id == taskId }) {
                todo.isCompleted = isCompleted
                try context.save()
                logger.info("Task status updated: \(todo.title) - completed: \(isCompleted)")
            } else {
                logger.warning("Task not found for status update: \(taskId)")
            }
        } catch {
            logger.error("Error updating task status", error: error)
        }
    }
    
    /// Handle app activation from notification
    func handleAppActivation() {
        if shouldShowApp {
            logger.info("App activated from notification")
            shouldShowApp = false
            
            // Additional logic for app activation could go here
            // For example, navigating to a specific view
        }
    }
    
    /// Clear notification actions
    func clearNotificationAction() {
        lastNotificationAction = nil
    }
    
    /// Get user-friendly action description
    func getActionDescription(_ actionIdentifier: String) -> String {
        switch actionIdentifier {
        case "COMPLETE_ACTION":
            return "Task completed"
        case "MARK_DONE_ACTION":
            return "Task marked as done"
        case "SNOOZE_ACTION":
            return "Task snoozed for 15 minutes"
        case "POSTPONE_ACTION":
            return "Task postponed for 1 hour"
        case "SKIP_ACTION":
            return "Task skipped for today"
        case "VIEW_PROJECT_ACTION":
            return "Opening project view"
        case "ADD_ITEM_ACTION":
            return "Adding item to list"
        case UNNotificationDefaultActionIdentifier:
            return "Opening app"
        default:
            return "Unknown action"
        }
    }
}

// MARK: - Extension for SwiftUI Integration
extension NotificationDelegate {
    
    /// Show a temporary status message in the UI
    func showStatusMessage(_ message: String) {
        // This could be enhanced to show a temporary message in the UI
        logger.info("Status message: \(message)")
    }
    
    /// Check if there are any pending actions to handle
    func hasPendingActions() -> Bool {
        return lastNotificationAction != nil || shouldShowApp
    }
} 