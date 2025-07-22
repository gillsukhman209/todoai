//
//  todoaiApp.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import SwiftUI
import SwiftData
import AppKit

extension Notification.Name {
    static let focusTaskInput = Notification.Name("focusTaskInput")
    static let showTodayView = Notification.Name("showTodayView")
    static let showUpcomingView = Notification.Name("showUpcomingView")
    static let showCalendarView = Notification.Name("showCalendarView")
    static let showAllView = Notification.Name("showAllView")
}

@main
struct todoaiApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Todo.self, TimeRange.self, RecurrenceConfig.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            print("Failed to create ModelContainer: \(error)")
            
            // Try deleting the old database for migration
            let url = URL.applicationSupportDirectory.appendingPathComponent("todoai")
            let dbURL = url.appendingPathComponent("TodoDB.sqlite")
            
            // Remove old database files
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("shm"))
            
            // Create fresh directory
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            
            // Try again with fresh database
            let config = ModelConfiguration(
                schema: schema,
                url: dbURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                print("Second attempt failed: \(error)")
                // Last resort: in-memory container
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                
                do {
                    return try ModelContainer(for: schema, configurations: memoryConfig)
                } catch {
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ModernSpeedContentView()
                .environmentObject(notificationDelegate)
                .environmentObject(backgroundTaskManager)
                .onAppear {
                    // Set up the model context for services
                    notificationDelegate.setModelContext(sharedModelContainer.mainContext)
                    backgroundTaskManager.setModelContext(sharedModelContainer.mainContext)
                    
                    // Enable background processing
                    backgroundTaskManager.enableBackgroundProcessing()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    backgroundTaskManager.handleAppDidEnterBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
                    backgroundTaskManager.handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    backgroundTaskManager.handleAppDidBecomeActive()
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 800, height: 600)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .focusTaskInput, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                
                Button("Show Today") {
                    NotificationCenter.default.post(name: .showTodayView, object: nil)
                }
                .keyboardShortcut("t", modifiers: [])
                
                Button("Show Upcoming") {
                    NotificationCenter.default.post(name: .showUpcomingView, object: nil)
                }
                .keyboardShortcut("u", modifiers: [])
                
                Button("Show Calendar") {
                    NotificationCenter.default.post(name: .showCalendarView, object: nil)
                }
                .keyboardShortcut("c", modifiers: [])
                
                Button("Show All Tasks") {
                    NotificationCenter.default.post(name: .showAllView, object: nil)
                }
                .keyboardShortcut("a", modifiers: [])
            }
        }
    }
}
