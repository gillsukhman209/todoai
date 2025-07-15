//
//  todoaiApp.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import SwiftUI
import SwiftData

@main
struct todoaiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Todo.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
                return try ModelContainer(for: schema, configurations: [config])
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
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 800, height: 600)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
