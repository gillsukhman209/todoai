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
    static let showPomodoroView = Notification.Name("showPomodoroView")
}

@main
struct todoaiApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Todo.self, TimeRange.self, RecurrenceConfig.self, PomodoroSession.self, PomodoroSettings.self])
        
        // Create a dedicated directory for our app data
        let appSupportURL = URL.applicationSupportDirectory.appendingPathComponent("TodoAI")
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        let dbURL = appSupportURL.appendingPathComponent("TodoDatabase.sqlite")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: modelConfiguration)
            print("✅ Database loaded successfully at: \(dbURL.path)")
            
            // Check if database file exists and log its size
            if FileManager.default.fileExists(atPath: dbURL.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: dbURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("📊 Database file size: \(fileSize) bytes")
                } catch {
                    print("⚠️ Could not read database file size: \(error)")
                }
            } else {
                print("⚠️ Database file does not exist yet - will be created on first save")
            }
            
            return container
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            print("Database location: \(dbURL.path)")
            
            // Try one more time with error recovery (but don't delete existing data)
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    url: dbURL,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: fallbackConfig)
                print("✅ Database recovered successfully")
                return container
            } catch {
                print("❌ Database recovery failed: \(error)")
                fatalError("Could not create persistent ModelContainer. Check console for details.")
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
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
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
                
                Button("Show Pomodoro") {
                    NotificationCenter.default.post(name: .showPomodoroView, object: nil)
                }
                .keyboardShortcut("p", modifiers: [])
            }
        }
    }
}
