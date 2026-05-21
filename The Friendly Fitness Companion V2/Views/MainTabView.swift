import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @State private var showOnboarding: Bool = false
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
            if let userSettings = settings.first, !userSettings.isOnboarded {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
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
                // Chest
                Exercise(name: "Barbell Bench Press", targetMuscle: "Chest"),
                Exercise(name: "Incline Dumbbell Press", targetMuscle: "Chest"),
                Exercise(name: "Pec Deck Fly", targetMuscle: "Chest"),
                Exercise(name: "Cable Crossover", targetMuscle: "Chest"),
                Exercise(name: "Dips", targetMuscle: "Chest"),
                
                // Back
                Exercise(name: "Barbell Deadlift", targetMuscle: "Back"),
                Exercise(name: "Pull-Ups", targetMuscle: "Back"),
                Exercise(name: "Lat Pulldown", targetMuscle: "Back"),
                Exercise(name: "Barbell Row", targetMuscle: "Back"),
                Exercise(name: "Seated Cable Row", targetMuscle: "Back"),
                Exercise(name: "Dumbbell Row", targetMuscle: "Back"),
                
                // Legs (Quads, Hamstrings, Glutes, Calves)
                Exercise(name: "Barbell Back Squat", targetMuscle: "Quads"),
                Exercise(name: "Leg Press", targetMuscle: "Quads"),
                Exercise(name: "Bulgarian Split Squat", targetMuscle: "Quads"),
                Exercise(name: "Leg Extension", targetMuscle: "Quads"),
                Exercise(name: "Romanian Deadlift (RDL)", targetMuscle: "Hamstrings"),
                Exercise(name: "Lying Leg Curl", targetMuscle: "Hamstrings"),
                Exercise(name: "Barbell Hip Thrust", targetMuscle: "Glutes"),
                Exercise(name: "Standing Calf Raise", targetMuscle: "Calves"),
                Exercise(name: "Seated Calf Raise", targetMuscle: "Calves"),
                
                // Shoulders
                Exercise(name: "Overhead Press", targetMuscle: "Shoulders"),
                Exercise(name: "Dumbbell Lateral Raise", targetMuscle: "Shoulders"),
                Exercise(name: "Cable Lateral Raise", targetMuscle: "Shoulders"),
                Exercise(name: "Reverse Pec Deck", targetMuscle: "Shoulders"),
                Exercise(name: "Face Pulls", targetMuscle: "Shoulders"),
                
                // Arms (Biceps, Triceps)
                Exercise(name: "Barbell Bicep Curl", targetMuscle: "Arms"),
                Exercise(name: "Incline Dumbbell Curl", targetMuscle: "Arms"),
                Exercise(name: "Hammer Curl", targetMuscle: "Arms"),
                Exercise(name: "Tricep Pushdown", targetMuscle: "Arms"),
                Exercise(name: "Overhead Tricep Extension", targetMuscle: "Arms"),
                Exercise(name: "Skullcrushers", targetMuscle: "Arms"),
                
                // Abs
                Exercise(name: "Cable Crunch", targetMuscle: "Abs"),
                Exercise(name: "Hanging Leg Raise", targetMuscle: "Abs"),
                Exercise(name: "Plank", targetMuscle: "Abs")
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
        WorkoutTemplate.self,
        PhysiquePhoto.self,
        BiometricLog.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return MainTabView()
        .modelContainer(container)
}
