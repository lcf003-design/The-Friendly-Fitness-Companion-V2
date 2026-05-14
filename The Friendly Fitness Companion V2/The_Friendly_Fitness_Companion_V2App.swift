//
//  The_Friendly_Fitness_Companion_V2App.swift
//  The Friendly Fitness Companion V2
//
//  Created by Larry Fields III on 5/8/26.
//

import SwiftUI
import SwiftData

@main
struct The_Friendly_Fitness_Companion_V2App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            UserSettings.self,
            FastingSession.self,
            WorkoutTemplate.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Schema mismatch or CloudKit error detected. Wiping local database: \(error)")
            
            // Delete the default SwiftData SQLite files
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            
            do {
                // Retry creating the container with a fresh slate
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Critical Failure: Could not create ModelContainer even after wipe. \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
