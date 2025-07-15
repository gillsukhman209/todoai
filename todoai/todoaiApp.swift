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
        do {
            let schema = Schema([Todo.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If there's a schema migration issue, try with in-memory storage as fallback
            print("Failed to create persistent ModelContainer: \(error)")
            do {
                let schema = Schema([Todo.self])
                let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
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
