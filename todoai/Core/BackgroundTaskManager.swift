//
//  BackgroundTaskManager.swift
//  todoai
//
//  Created by AI Assistant on 1/4/25.
//

import Foundation
#if os(iOS)
import BackgroundTasks
#endif
import SwiftData
import UserNotifications

// MARK: - Background Task Manager
@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    // Background task identifiers
    private let refreshTaskIdentifier = "com.todoai.background.refresh"
    private let processTaskIdentifier = "com.todoai.background.process"
    
    @Published var lastBackgroundRefresh: Date?
    @Published var isBackgroundProcessingEnabled = false
    
    private let taskScheduler = TaskScheduler.shared
    private let notificationService = NotificationService.shared
    private let logger = StructuredLogger.shared
    
    var modelContext: ModelContext?
    
    private init() {
        setupBackgroundTasks()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Background Task Setup
    
    private func setupBackgroundTasks() {
        #if os(iOS)
        // Register background app refresh task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Register background processing task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processTaskIdentifier, using: nil) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
        
        logger.info("Background tasks registered")
        #else
        logger.info("Background tasks not supported on macOS")
        #endif
    }
    
    // MARK: - Background Task Handlers
    
    #if os(iOS)
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        logger.info("Background refresh task started")
        
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            self.logger.warning("Background refresh task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform the refresh
        Task {
            do {
                await self.refreshScheduledTasks()
                await self.cleanupExpiredNotifications()
                
                self.lastBackgroundRefresh = Date()
                task.setTaskCompleted(success: true)
                self.logger.info("Background refresh completed successfully")
            } catch {
                self.logger.error("Background refresh failed", error: error)
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        logger.info("Background processing task started")
        
        // Schedule the next background processing
        scheduleBackgroundProcessing()
        
        // Set expiration handler
        task.expirationHandler = {
            self.logger.warning("Background processing task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform processing
        Task {
            do {
                await self.processScheduledTasks()
                await self.updateRecurringTasks()
                
                task.setTaskCompleted(success: true)
                self.logger.info("Background processing completed successfully")
            } catch {
                self.logger.error("Background processing failed", error: error)
                task.setTaskCompleted(success: false)
            }
        }
    }
    #endif
    
    // MARK: - Background Task Scheduling
    
    func scheduleBackgroundRefresh() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled")
        } catch {
            logger.error("Failed to schedule background refresh", error: error)
        }
        #else
        logger.info("Background refresh not supported on macOS")
        #endif
    }
    
    func scheduleBackgroundProcessing() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: processTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background processing scheduled")
        } catch {
            logger.error("Failed to schedule background processing", error: error)
        }
        #else
        logger.info("Background processing not supported on macOS")
        #endif
    }
    
    // MARK: - Background Operations
    
    private func refreshScheduledTasks() async {
        logger.info("Refreshing scheduled tasks in background")
        
        guard let context = modelContext else {
            logger.error("Model context not available for background refresh")
            return
        }
        
        // Fetch all active tasks
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate<Todo> { !$0.isCompleted }
        )
        
        do {
            let activeTasks = try context.fetch(descriptor)
            
            // Update notifications for tasks that need rescheduling
            for todo in activeTasks {
                if !todo.scheduleDescription.isEmpty {
                    // This task has a schedule, ensure it has proper notifications
                    await refreshNotificationsForTask(todo)
                }
            }
            
            logger.info("Refreshed notifications for \(activeTasks.count) tasks")
        } catch {
            logger.error("Failed to refresh scheduled tasks", error: error)
        }
    }
    
    private func refreshNotificationsForTask(_ todo: Todo) async {
        // Check if task needs notification refresh
        // This would convert the Todo to EnhancedTask and reschedule if needed
        
        // For now, this is a placeholder implementation
        logger.info("Refreshing notifications for task: \(todo.title)")
    }
    
    private func cleanupExpiredNotifications() async {
        logger.info("Cleaning up expired notifications")
        
        // Get all pending notifications
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        
        let now = Date()
        var expiredIdentifiers: [String] = []
        
        for request in pendingRequests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate(),
               nextTriggerDate < now {
                expiredIdentifiers.append(request.identifier)
            }
        }
        
        if !expiredIdentifiers.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIdentifiers)
            logger.info("Removed \(expiredIdentifiers.count) expired notifications")
        }
    }
    
    private func processScheduledTasks() async {
        logger.info("Processing scheduled tasks in background")
        
        guard let context = modelContext else {
            logger.error("Model context not available for background processing")
            return
        }
        
        // Process tasks that might need updates
        let descriptor = FetchDescriptor<Todo>()
        
        do {
            let allTasks = try context.fetch(descriptor)
            
            // Process each task
            for todo in allTasks {
                await processTask(todo)
            }
            
            logger.info("Processed \(allTasks.count) tasks")
        } catch {
            logger.error("Failed to process scheduled tasks", error: error)
        }
    }
    
    private func processTask(_ todo: Todo) async {
        // Check if task needs any updates
        // This could include updating recurring tasks, checking deadlines, etc.
        
        logger.debug("Processing task: \(todo.title)")
        
        // Placeholder for task processing logic
        // This would be expanded based on specific requirements
    }
    
    private func updateRecurringTasks() async {
        logger.info("Updating recurring tasks")
        
        // Check for recurring tasks that need to be updated
        // This would handle tasks like daily habits, weekly reminders, etc.
        
        guard let context = modelContext else {
            logger.error("Model context not available for recurring task updates")
            return
        }
        
        // Find tasks with recurring schedules
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate<Todo> { !$0.scheduleDescription.isEmpty }
        )
        
        do {
            let scheduledTasks = try context.fetch(descriptor)
            
            for todo in scheduledTasks {
                await updateRecurringTask(todo)
            }
            
            logger.info("Updated \(scheduledTasks.count) recurring tasks")
        } catch {
            logger.error("Failed to update recurring tasks", error: error)
        }
    }
    
    private func updateRecurringTask(_ todo: Todo) async {
        // Update a specific recurring task
        // This would check if the task should create a new occurrence
        
        logger.debug("Updating recurring task: \(todo.title)")
        
        // Placeholder for recurring task update logic
    }
    
    // MARK: - App Lifecycle Integration
    
    func handleAppDidEnterBackground() {
        logger.info("App entered background - scheduling background tasks")
        
        // Schedule background tasks when app goes to background
        scheduleBackgroundRefresh()
        scheduleBackgroundProcessing()
    }
    
    func handleAppWillEnterForeground() {
        logger.info("App entering foreground - cancelling background tasks")
        
        #if os(iOS)
        // Cancel pending background tasks since app is active
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processTaskIdentifier)
        #endif
        
        // Perform immediate refresh
        Task {
            await refreshScheduledTasks()
        }
    }
    
    func handleAppDidBecomeActive() {
        logger.info("App became active")
        
        // Check if we need to refresh anything
        if let lastRefresh = lastBackgroundRefresh {
            let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
            
            // If it's been more than 30 minutes, refresh
            if timeSinceRefresh > 30 * 60 {
                Task {
                    await refreshScheduledTasks()
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    func getBackgroundTaskStatus() -> String {
        if isBackgroundProcessingEnabled {
            return "Background processing enabled"
        } else {
            return "Background processing disabled"
        }
    }
    
    func getPendingBackgroundTasks() -> [String] {
        // Return list of pending background tasks
        // This would be used for debugging/monitoring
        return [refreshTaskIdentifier, processTaskIdentifier]
    }
    
    func cancelAllBackgroundTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.cancelAllTaskRequests()
        logger.info("All background tasks cancelled")
        #else
        logger.info("Background tasks not supported on macOS")
        #endif
    }
}

// MARK: - Extensions for Integration
extension BackgroundTaskManager {
    
    /// Enable background processing
    func enableBackgroundProcessing() {
        isBackgroundProcessingEnabled = true
        scheduleBackgroundRefresh()
        scheduleBackgroundProcessing()
        logger.info("Background processing enabled")
    }
    
    /// Disable background processing
    func disableBackgroundProcessing() {
        isBackgroundProcessingEnabled = false
        cancelAllBackgroundTasks()
        logger.info("Background processing disabled")
    }
    
    /// Force refresh of all scheduled tasks
    func forceRefresh() async {
        logger.info("Force refreshing all scheduled tasks")
        await refreshScheduledTasks()
        await cleanupExpiredNotifications()
    }
} 