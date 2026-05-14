import SwiftUI
import SwiftData

struct WorkoutLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    @Query private var userSettings: [UserSettings]
    @State private var isShowingExerciseSelection = false
    @State private var isEditMode: Bool = false
    var isNewSession: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                    
                    if session.exercises.isEmpty {
                        emptyStateSection
                    } else {
                        exerciseListSection
                    }
                    
                    if isEditMode {
                        footerActionSection
                    }
                }
            }
            .navigationTitle("Current Grind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarButton
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarButton
                }
            }
            .onAppear {
                // HARD LOCK: If this is an existing session opened from the Journal, 
                // it opens in Read-Only mode NO MATTER WHAT. 
                // The user must press "Edit" to modify old sessions.
                isEditMode = isNewSession
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
    
    @ViewBuilder
    private var headerSection: some View {
        TextField("Workout Name", text: $session.name)
            .font(.title2.bold())
            .foregroundColor(Theme.textPrimary)
            .padding()
            .background(Theme.surface)
            .disabled(!isEditMode)
    }
    
    @ViewBuilder
    private var emptyStateSection: some View {
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
    }
    
    @ViewBuilder
    private var exerciseListSection: some View {
        List {
            ForEach(session.exercises) { wEx in
                NavigationLink(destination: ActiveExerciseView(workoutExercise: wEx, isEditMode: isEditMode)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(wEx.loggedName.isEmpty ? (wEx.exerciseRef?.name ?? "Unknown") : wEx.loggedName)
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
    
    @ViewBuilder
    private var footerActionSection: some View {
        VStack {
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
            
            Button(action: finishWorkout) {
                Text(session.endTime == nil ? "FINISH WORKOUT" : "SAVE EDITS")
                    .font(Theme.Typography.technical(16, weight: .black))
                    .foregroundColor(Theme.midnightMatte)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.accent)
            }
        }
    }
    
    @ViewBuilder
    private var trailingToolbarButton: some View {
        Button("Edit") {
            isEditMode = true
        }
        .foregroundColor(Theme.accent)
        .font(Theme.Typography.technical(16, weight: .bold))
        .opacity(!isEditMode ? 1 : 0)
        .disabled(isEditMode)
    }
    
    @ViewBuilder
    private var leadingToolbarButton: some View {
        if isEditMode {
            Button("Cancel") {
                if session.endTime == nil {
                    modelContext.delete(session) // Rollback only if it's a new unfinished session
                } else {
                    isEditMode = false // Turn off edit mode without saving new edits
                }
                dismiss()
            }
            .foregroundColor(Theme.dangerRed)
        } else {
            Button("Done") {
                dismiss()
            }
            .foregroundColor(Theme.accent)
            .font(Theme.Typography.technical(16, weight: .bold))
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard isEditMode else { return }
        for index in offsets {
            let ex = session.exercises[index]
            modelContext.delete(ex)
        }
        session.exercises.remove(atOffsets: offsets)
    }
    
    private func finishWorkout() {
        if session.exercises.isEmpty && session.endTime == nil {
            modelContext.delete(session)
            dismiss()
            return
        }
        
        if session.endTime == nil {
            // Finalizing a brand new session
            session.endTime = Date()
            try? modelContext.save()
            
            if userSettings.first?.isHealthKitSyncEnabled == true {
                var weightKg: Double? = nil
                if let settings = userSettings.first, settings.bodyWeight > 0 {
                    weightKg = settings.weightUnit == "lb" ? settings.bodyWeight * 0.453592 : settings.bodyWeight
                }
                
                HealthKitManager.shared.saveStrengthWorkout(
                    startTime: session.timestamp,
                    endTime: session.endTime ?? Date(),
                    name: session.name,
                    bodyWeight: weightKg
                ) { success, error in
                    if let error = error {
                        print("HealthKit sync failed: \(error)")
                    }
                }
            }
        } else {
            // Saving historical edits
            try? modelContext.save()
        }
        
        dismiss()
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let dummySession = WorkoutSession(name: "Preview Grind", timestamp: Date(), rpe: 8, exercises: [])
    container.mainContext.insert(dummySession)
    
    return WorkoutLoggerView(session: dummySession)
        .modelContainer(container)
}
