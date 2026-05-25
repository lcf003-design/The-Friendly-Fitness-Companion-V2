import SwiftUI
import SwiftData

struct WorkoutLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    @Query private var userSettings: [UserSettings]
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fastingSessions: [FastingSession]
    
    @State private var isShowingExerciseSelection = false
    @State private var isEditMode: Bool = false
    @State private var isShowingHelp: Bool = false
    var isNewSession: Bool = false
    
    var body: some View {
        NavigationStack {
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
            .background(Theme.midnightMatte.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                operationalSummaryHUD
            }
            .navigationTitle("Current Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarButton
                }
            }
            .onAppear {
                isEditMode = isNewSession
                if isNewSession, let settings = userSettings.first {
                    settings.activeWorkoutSessionId = session.id
                    try? modelContext.save()
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
            .sheet(isPresented: $isShowingHelp) {
                WorkoutLoggerHelpView()
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
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.border)
            Text("No exercises added.")
                .font(Theme.Typography.technical(16))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var exerciseListSection: some View {
        List {
            ForEach(session.exercises) { wEx in
                let hasFailure = wEx.sets.contains { $0.hitFailure }
                
                NavigationLink(destination: ActiveExerciseView(workoutExercise: wEx, isEditMode: isEditMode)) {
                    HStack(spacing: 12) {
                        if let groupId = wEx.supersetGroupId {
                            let color = Color(hue: Double(abs(groupId.hashValue) % 100) / 100.0, saturation: 0.8, brightness: 0.9)
                            Rectangle()
                                .fill(color)
                                .frame(width: 4)
                                .cornerRadius(2)
                                .padding(.vertical, 4)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(wEx.loggedName.isEmpty ? (wEx.exerciseRef?.name ?? "Unknown") : wEx.loggedName)
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                                .shadow(color: hasFailure ? Theme.dangerRed.opacity(0.8) : .clear, radius: 4)
                            
                            HStack(spacing: 6) {
                                Text("\(wEx.sets.count) Sets")
                                if wEx.supersetGroupId != nil {
                                    Text("• Superset")
                                        .foregroundColor(Theme.accent)
                                        .font(Theme.Typography.technical(8, weight: .bold))
                                }
                            }
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        if hasFailure {
                            Image(systemName: "flame.fill")
                                .foregroundColor(Theme.dangerRed)
                                .shadow(color: Theme.dangerRed.opacity(0.6), radius: 4)
                                .padding(.trailing, 4)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(Theme.border)
                    }
                }
                .listRowBackground(Theme.surface)
                .contextMenu {
                    if isEditMode {
                        Button(action: {
                            toggleSupersetLink(for: wEx)
                        }) {
                            Label(wEx.supersetGroupId == nil ? "Link as Superset" : "Unlink Superset", systemImage: "link")
                        }
                    }
                }
            }
            .onDelete(perform: deleteExercise)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder
    private var footerActionSection: some View {
        VStack {
            Button(action: {
                isShowingExerciseSelection = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Exercise")
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
                Text(session.endTime == nil ? "Finish Workout" : "Save Edits")
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
                    if let settings = userSettings.first {
                        settings.activeWorkoutSessionId = nil
                    }
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
    
    private func toggleSupersetLink(for exercise: WorkoutExercise) {
        guard let index = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        if exercise.supersetGroupId == nil {
            if index + 1 < session.exercises.count {
                let nextExercise = session.exercises[index + 1]
                let newGroupId = UUID()
                exercise.supersetGroupId = newGroupId
                nextExercise.supersetGroupId = newGroupId
            }
        } else {
            let oldGroupId = exercise.supersetGroupId
            for ex in session.exercises {
                if ex.supersetGroupId == oldGroupId {
                    ex.supersetGroupId = nil
                }
            }
        }
        try? modelContext.save()
        HapticManager.shared.playSelection()
    }
    
    private func finishWorkout() {
        if session.exercises.isEmpty && session.endTime == nil {
            if let settings = userSettings.first {
                settings.activeWorkoutSessionId = nil
            }
            modelContext.delete(session)
            dismiss()
            return
        }
        
        if session.endTime == nil {
            // Finalizing a brand new session
            session.endTime = Date()
            
            // Auto-tag Fasted Grind
            if let activeFast = fastingSessions.first(where: { !$0.isCompleted }) {
                let elapsed = Date().timeIntervalSince(activeFast.startTime)
                let hours = elapsed / 3600.0
                let phaseTitle = fastingPhaseTitle(for: hours)
                
                let defaultNames = ["Late Night Grind", "Morning Grind", "Afternoon Grind", "Workout Session", "New Grind"]
                if defaultNames.contains(session.name) || session.name.isEmpty {
                    session.name = "Fasted Workout"
                } else if !session.name.contains("Fasted") {
                    session.name += " (Fasted)"
                }
            }
            
            if let settings = userSettings.first {
                settings.activeWorkoutSessionId = nil
            }
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
    
    @ViewBuilder
    private var operationalSummaryHUD: some View {
        let totalTonnage = session.exercises.flatMap { $0.sets }.filter { $0.isCompleted }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        let failureCount = session.exercises.flatMap { $0.sets }.filter { $0.hitFailure }.count
        let isFasting = fastingSessions.contains(where: { !$0.isCompleted })
        
        VStack(spacing: 0) {
            if let activeFast = fastingSessions.first(where: { !$0.isCompleted }) {
                let elapsed = Date().timeIntervalSince(activeFast.startTime)
                let hours = elapsed / 3600.0
                let phaseTitle = fastingPhaseTitle(for: hours)
                
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.dangerRed)
                    Text("Fasted Workout Active")
                        .font(Theme.Typography.technical(9, weight: .black))
                        .foregroundColor(Theme.dangerRed)
                    Spacer()
                    Text("\(formatFastingDuration(elapsed)) // \(phaseTitle) Phase")
                        .font(Theme.Typography.technical(9, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Theme.dangerRed.opacity(0.12))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Theme.border.opacity(0.3))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Tonnage")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(totalTonnage, specifier: "%.1f")")
                        .font(Theme.Typography.technical(14, weight: .black))
                        .monospacedDigit()
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("Intensity Score")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(session.totalIntensityScore)")
                        .font(Theme.Typography.technical(14, weight: .black))
                        .monospacedDigit()
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Failure Count")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(failureCount)")
                        .font(Theme.Typography.technical(14, weight: .black))
                        .monospacedDigit()
                        .foregroundColor(failureCount > 0 ? Theme.dangerRed : Theme.textPrimary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(height: isFasting ? 108 : 80)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.border)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }
    
    private func fastingPhaseTitle(for hours: Double) -> String {
        if hours < 4 { return "Sugar Burner" }
        if hours < 12 { return "Glycogen Drain" }
        if hours < 16 { return "Ketosis Ignited" }
        return "Deep Autophagy"
    }
    
    private func formatFastingDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        return String(format: "%02dH %02dM", hrs, mins)
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        session.exercises.remove(atOffsets: offsets)
        try? modelContext.save()
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
