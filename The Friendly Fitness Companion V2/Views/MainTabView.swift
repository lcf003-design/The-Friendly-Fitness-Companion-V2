import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var allExercises: [Exercise]
    @Query private var sessions: [WorkoutSession]
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "square.grid.2x2.fill")
                }
            
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
            
            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
            
            ProfileView()
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(Theme.accent)
        .onAppear {
            seedInitialData()
        }
        .preferredColorScheme(settings.first?.themePreference == 1 ? .light : (settings.first?.themePreference == 2 ? .dark : nil))
    }
    
    private func seedInitialData() {
        // Only seed if settings doesn't exist or isSeeded is false
        if settings.isEmpty {
            let newSettings = UserSettings()
            newSettings.weightUnit = "lb"
            newSettings.isSeeded = true
            modelContext.insert(newSettings)
            
            let defaultExercises: [Exercise] = [
                Exercise(name: "Bench Press", targetMuscle: "Chest", notes: "Keep your feet planted and squeeze your chest at the top."),
                Exercise(name: "Overhead Press", targetMuscle: "Shoulders", notes: "Stay tall and press directly overhead."),
                Exercise(name: "Squat", targetMuscle: "Quads", notes: "Focus on a smooth, deep movement."),
                Exercise(name: "Deadlift", targetMuscle: "Back", notes: "Keep your back straight and lift with intent."),
                Exercise(name: "Barbell Row", targetMuscle: "Back", notes: "Pull the bar toward your navel."),
                Exercise(name: "Leg Press", targetMuscle: "Quads", notes: "Control the weight on the way down."),
                Exercise(name: "Lat Pulldowns", targetMuscle: "Lats", notes: "Think about pulling with your elbows."),
                Exercise(name: "Bicep Curls", targetMuscle: "Arms", notes: "Focus on the curl, not the swing.")
            ]
            
            for ex in defaultExercises {
                modelContext.insert(ex)
            }
            
            try? modelContext.save()
        }
        
    }
}

#Preview {
    let schema = Schema([
        Exercise.self,
        WorkoutSession.self,
        WorkoutExercise.self,
        ExerciseSet.self,
        UserSettings.self,
        FastingSession.self,
        WorkoutTemplate.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return MainTabView()
        .modelContainer(container)
}
