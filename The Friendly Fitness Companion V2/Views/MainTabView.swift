import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    var body: some View {
        TabView {
            Text("Dashboard (Coming Soon)")
                .tabItem {
                    Label("Home", systemImage: "square.grid.2x2.fill")
                }
            
            Text("Journal (Coming Soon)")
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
            
            Text("Progress (Coming Soon)")
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
            
            Text("Settings (Coming Soon)")
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Theme.accent)
        .onAppear {
            seedInitialData()
        }
    }
    
    private func seedInitialData() {
        // Only seed if settings doesn't exist or isSeeded is false
        if settings.isEmpty {
            let newSettings = UserSettings(weightUnit: "lb", isSeeded: true)
            modelContext.insert(newSettings)
            
            let defaultExercises = [
                ("Bench Press", "Chest", "Keep your feet planted and squeeze your chest at the top."),
                ("Overhead Press", "Shoulders", "Stay tall and press directly overhead."),
                ("Squat", "Quads", "Focus on a smooth, deep movement."),
                ("Deadlift", "Back", "Keep your back straight and lift with intent."),
                ("Barbell Row", "Back", "Pull the bar toward your navel."),
                ("Leg Press", "Quads", "Control the weight on the way down."),
                ("Lat Pulldowns", "Lats", "Think about pulling with your elbows."),
                ("Bicep Curls", "Arms", "Focus on the curl, not the swing.")
            ]
            
            for ex in defaultExercises {
                let exercise = Exercise(name: ex.0, targetMuscle: ex.1, notes: ex.2)
                modelContext.insert(exercise)
            }
            
            try? modelContext.save()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [
            Exercise.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            UserSettings.self
        ], inMemory: true)
}
