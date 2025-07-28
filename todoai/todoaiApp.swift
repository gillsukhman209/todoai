//
//  todoaiApp.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct todoaiApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Todo.self, TimeRange.self, RecurrenceConfig.self])
            let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            print("Failed to create ModelContainer: \(error)")
            // Create directory if it doesn't exist
            let url = URL.applicationSupportDirectory.appendingPathComponent("todoai")
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            
            // Try again with explicit URL
            let dbURL = url.appendingPathComponent("TodoDB.sqlite")
            let config = ModelConfiguration(
                schema: schema,
                url: dbURL,
                allowsSave: true
            )
            
            do {
                return try ModelContainer(for: schema, configurations: config)
        } catch {
                print("Second attempt failed: \(error)")
                // Last resort: create a basic persistent container
                do {
                    return try ModelContainer(for: Todo.self)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
    }
}
