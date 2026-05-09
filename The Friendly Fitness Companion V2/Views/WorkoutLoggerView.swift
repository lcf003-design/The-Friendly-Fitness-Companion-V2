import SwiftUI
import SwiftData

struct WorkoutLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    @Query private var userSettings: [UserSettings]
    @State private var isShowingExerciseSelection = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Input
                    TextField("Workout Name", text: $session.name)
                        .font(.title2.bold())
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                        .background(Theme.surface)
                    
                    if session.exercises.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.border)
                            Text("No exercises added.")
                                .font(Theme.Typography.technical(16))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(session.exercises) { wEx in
                                NavigationLink(destination: ActiveExerciseView(workoutExercise: wEx)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(wEx.exerciseRef?.name ?? "Unknown")
                                                .font(.headline)
                                                .foregroundColor(Theme.textPrimary)
                                            Text("\(wEx.sets.count) Sets")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Theme.border)
                                    }
                                }
                                .listRowBackground(Theme.surface)
                            }
                            .onDelete(perform: deleteExercise)
                        }
                        .scrollContentBackground(.hidden)
                    }
                    
                    // Add Exercise Button
                    Button(action: {
                        isShowingExerciseSelection = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("ADD EXERCISE")
                                .font(Theme.Typography.technical(14, weight: .bold))
                        }
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }
                    .padding()
                    
                    // Finish Button
                    Button(action: finishWorkout) {
                        Text("FINISH WORKOUT")
                            .font(Theme.Typography.technical(16, weight: .black))
                            .foregroundColor(Theme.midnightMatte)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Theme.accent)
                    }
                }
            }
            .navigationTitle("Current Grind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        modelContext.delete(session) // Rollback
                        dismiss()
                    }
                    .foregroundColor(Theme.dangerRed)
                }
            }
            .sheet(isPresented: $isShowingExerciseSelection) {
                ExerciseSelectionView { selectedExercise in
                    let newWorkoutEx = WorkoutExercise(exerciseRef: selectedExercise)
                    modelContext.insert(newWorkoutEx)
                    session.exercises.append(newWorkoutEx)
                    try? modelContext.save() // Force SwiftData to broadcast the relationship update to SwiftUI
                }
            }
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        for index in offsets {
            let ex = session.exercises[index]
            modelContext.delete(ex)
        }
        session.exercises.remove(atOffsets: offsets)
    }
    
    private func finishWorkout() {
        if session.exercises.isEmpty {
            modelContext.delete(session)
        } else {
            session.endTime = Date()
            try? modelContext.save()
            
            if userSettings.first?.isHealthKitSyncEnabled == true {
                HealthKitManager.shared.saveStrengthWorkout(
                    startTime: session.timestamp,
                    endTime: session.endTime ?? Date(),
                    name: session.name
                ) { success, error in
                    if let error = error {
                        print("HealthKit sync failed: \(error)")
                    }
                }
            }
        }
        dismiss()
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let dummySession = WorkoutSession(name: "Preview Grind", timestamp: Date(), rpe: 8, exercises: [])
    container.mainContext.insert(dummySession)
    
    return WorkoutLoggerView(session: dummySession)
        .modelContainer(container)
}
