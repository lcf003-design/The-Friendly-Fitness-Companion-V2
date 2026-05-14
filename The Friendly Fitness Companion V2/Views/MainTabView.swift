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
        
        // Temporary auto-seed for historical Chart data if empty or sparse
        if sessions.count < 4 {
            if let benchPress = allExercises.first(where: { $0.name == "Bench Press" }) {
                
                let day1 = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
                let day2 = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
                let day3 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
                let day4 = Date()
                
                let s1 = WorkoutSession(name: "Chest Day", timestamp: day1, rpe: 8, exercises: [])
                s1.exercises.append(WorkoutExercise(exerciseRef: benchPress, sets: [ExerciseSet(weight: 185, reps: 8)]))
                
                let s2 = WorkoutSession(name: "Heavy Push", timestamp: day2, rpe: 9, exercises: [])
                s2.exercises.append(WorkoutExercise(exerciseRef: benchPress, sets: [ExerciseSet(weight: 195, reps: 7)]))
                
                let s3 = WorkoutSession(name: "Chest Grind", timestamp: day3, rpe: 9, exercises: [])
                s3.exercises.append(WorkoutExercise(exerciseRef: benchPress, sets: [ExerciseSet(weight: 205, reps: 6)]))
                
                let s4 = WorkoutSession(name: "PR Attempt", timestamp: day4, rpe: 10, exercises: [])
                s4.exercises.append(WorkoutExercise(exerciseRef: benchPress, sets: [ExerciseSet(weight: 225, reps: 3)]))
                
                modelContext.insert(s1)
                modelContext.insert(s2)
                modelContext.insert(s3)
                modelContext.insert(s4)
                
                try? modelContext.save()
            }
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
