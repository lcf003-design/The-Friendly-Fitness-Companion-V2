import SwiftUI
import SwiftData

struct ActiveExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutExercise: WorkoutExercise
    
    // Fetch all instances of this specific exercise across history to find the Ghost
    @Query private var history: [WorkoutExercise]
    @Query private var userSettings: [UserSettings]
    
    // Rest Timer State
    @State private var timeRemaining: Int = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer?
    
    // Metronome State
    @State private var isMetronomeActive = false
    @State private var metronomeTimer: Timer?
    
    init(workoutExercise: WorkoutExercise) {
        self.workoutExercise = workoutExercise
        
        let targetId = workoutExercise.exerciseRef?.id ?? UUID()
        let filter = #Predicate<WorkoutExercise> { wex in
            wex.exerciseRef?.id == targetId
        }
        _history = Query(filter: filter)
    }
    
    // Finds the most recent past performance
    private var ghost: WorkoutExercise? {
        // Sort manually since SwiftData sometimes struggles with nested relationships in predicates
        let pastPerformances = history.filter { $0.id != workoutExercise.id && !$0.sets.isEmpty }
        return pastPerformances.last // Assuming appending chronological order
    }
    
    // Calculates max weight from the ghost
    private var ghostMaxWeight: Double {
        ghost?.sets.map { $0.weight }.max() ?? 0.0
    }
    
    // Calculates the Estimated 1-Rep Max for the current active workout exercise using the Epley formula
    private var estimated1RM: Double {
        let completedSets = workoutExercise.sets.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
        let maxProjected = completedSets.map { set in
            // Epley formula matches the 1RM Calculator tool
            return set.weight * (1.0 + (Double(set.reps) / 30.0))
        }.max() ?? 0.0
        return maxProjected
    }
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            VStack {
                VStack(spacing: 4) {
                    Text(workoutExercise.exerciseRef?.name.uppercased() ?? "UNKNOWN")
                        .font(Theme.Typography.technical(24, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    if ghost != nil, ghostMaxWeight > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "ghost.fill")
                            Text("GHOST: \(ghostMaxWeight, specifier: "%.1f") lbs")
                        }
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 4)
                    }
                    
                    if estimated1RM > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(Theme.warningOrange)
                            Text("EST 1RM: \(estimated1RM, specifier: "%.1f") lbs")
                        }
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 2)
                    }
                }
                .padding(.top)
                
                // Set Header
                HStack {
                    Text("SET")
                        .frame(width: 40, alignment: .center)
                    Text("LBS")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("REPS")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("RP/FAIL")
                        .frame(width: 80, alignment: .center)
                }
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Sets List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(workoutExercise.sets.indices, id: \.self) { index in
                            SetRowView(setIndex: index + 1, exerciseSet: workoutExercise.sets[index], ghostMaxWeight: ghostMaxWeight) {
                                startTimer()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Rest Timer HUD
                if isTimerRunning {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(Theme.warningOrange)
                        Text(String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60))
                            .font(Theme.Typography.technical(20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        
                        Button(action: {
                            timeRemaining += 30
                        }) {
                            Text("+30s")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.surface)
                                .cornerRadius(8)
                        }
                        
                        Button(action: stopTimer) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding()
                    .background(Theme.midnightMatte)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.warningOrange, lineWidth: 2)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Add Set Button
                Button(action: addSet) {
                    Text("ADD SET")
                        .font(Theme.Typography.technical(16, weight: .bold))
                        .foregroundColor(Theme.midnightMatte)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
        .navigationTitle("The Grind")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if userSettings.first?.isHapticMetronomeEnabled == true {
                    Button(action: toggleMetronome) {
                        Image(systemName: isMetronomeActive ? "metronome.fill" : "metronome")
                            .foregroundColor(isMetronomeActive ? Theme.warningOrange : Theme.accent)
                    }
                }
            }
        }
        .onDisappear {
            stopTimer()
            stopMetronome()
        }
    }
    
    private func startTimer() {
        let isRestTimerEnabled = userSettings.first?.isRestTimerEnabled ?? true
        guard isRestTimerEnabled else { return }
        
        stopTimer()
        timeRemaining = 120 // Default 2 minutes
        isTimerRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
                HapticManager.shared.playHeavyImpact() // Timer done
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        withAnimation {
            isTimerRunning = false
        }
    }
    
    private func toggleMetronome() {
        if isMetronomeActive {
            stopMetronome()
        } else {
            isMetronomeActive = true
            
            let profile = userSettings.first?.tempoProfile ?? "Standard Hypertrophy (3-1-3)"
            let numbers = profile.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            let tempo = numbers.count == 3 ? numbers : [3, 1, 3]
            
            var phase = 0 // 0 = eccentric, 1 = pause, 2 = concentric
            var ticksInPhase = 0
            
            HapticManager.shared.playSuccess() // Announce start
            
            metronomeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if phase == 0 { // Eccentric (lowering)
                    HapticManager.shared.playLightImpact()
                    ticksInPhase += 1
                    if ticksInPhase >= tempo[0] { phase = 1; ticksInPhase = 0 }
                } else if phase == 1 { // Pause (bottom)
                    if tempo[1] > 0 { HapticManager.shared.playLightImpact() }
                    ticksInPhase += 1
                    if ticksInPhase >= tempo[1] { phase = 2; ticksInPhase = 0 }
                } else if phase == 2 { // Concentric (lifting)
                    HapticManager.shared.playHeavyImpact()
                    ticksInPhase += 1
                    if ticksInPhase >= tempo[2] { 
                        phase = 0; ticksInPhase = 0
                        HapticManager.shared.playSuccess() // Rep complete
                    }
                }
            }
        }
    }
    
    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        isMetronomeActive = false
    }
    
    private func addSet() {
        let newSet = ExerciseSet(weight: 0.0, reps: 0)
        modelContext.insert(newSet)
        workoutExercise.sets.append(newSet)
        
        HapticManager.shared.playLightImpact()
    }
}

struct SetRowView: View {
    let setIndex: Int
    @Bindable var exerciseSet: ExerciseSet
    let ghostMaxWeight: Double
    var onComplete: (() -> Void)?
    
    // Local bindings for textfields
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    @State private var rpString: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Set Completion Checkmark
                Button(action: {
                    exerciseSet.isCompleted.toggle()
                    if exerciseSet.isCompleted {
                        HapticManager.shared.playSuccess()
                        onComplete?()
                    }
                }) {
                    Image(systemName: exerciseSet.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundColor(exerciseSet.isCompleted ? Theme.apexGreen : Theme.textSecondary)
                        .font(.title3)
                }
                .frame(width: 40, alignment: .center)
                
                // Weight
                TextField("-", text: $weightString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title2.bold())
                    // Gold highlight if beating the Ghost!
                    .foregroundColor((exerciseSet.weight > ghostMaxWeight && ghostMaxWeight > 0) ? Theme.warningOrange : Theme.textPrimary)
                    .padding(.vertical, 8)
                    .background(Theme.surface)
                    .cornerRadius(8)
                    .onChange(of: weightString) { 
                        let newWeight = Double(weightString) ?? 0.0
                        // Trigger PR Haptic if just crossed the threshold!
                        if newWeight > ghostMaxWeight && exerciseSet.weight <= ghostMaxWeight && ghostMaxWeight > 0 {
                            HapticManager.shared.playPR()
                        }
                        exerciseSet.weight = newWeight 
                    }
                
                // Reps
                TextField("-", text: $repsString)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                    .padding(.vertical, 8)
                    .background(Theme.surface)
                    .cornerRadius(8)
                    .onChange(of: repsString) { exerciseSet.reps = Int(repsString) ?? 0 }
                
                // Actions (Fail / Rest Pause)
                HStack(spacing: 12) {
                    // Rest Pause Button
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        exerciseSet.restPauses.append(0) // Add empty RP slot
                    }) {
                        Image(systemName: "plus.forwardslash.minus")
                            .foregroundColor(Theme.warningOrange)
                    }
                    
                    // Failure Toggle
                    Button(action: {
                        HapticManager.shared.playHeavyImpact()
                        exerciseSet.hitFailure.toggle()
                    }) {
                        Image(systemName: exerciseSet.hitFailure ? "flame.fill" : "flame")
                            .foregroundColor(exerciseSet.hitFailure ? Theme.dangerRed : Theme.border)
                    }
                }
                .frame(width: 80, alignment: .center)
            }
            
            // Rest Pauses Display
            if !exerciseSet.restPauses.isEmpty {
                HStack {
                    Text("+ RP:")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.warningOrange)
                    
                    ForEach(exerciseSet.restPauses.indices, id: \.self) { rpIndex in
                        TextField("0", value: Binding(
                            get: { exerciseSet.restPauses[rpIndex] },
                            set: { exerciseSet.restPauses[rpIndex] = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.body.bold())
                        .frame(width: 40)
                        .padding(4)
                        .background(Theme.surface)
                        .cornerRadius(6)
                        .foregroundColor(Theme.warningOrange)
                    }
                    Spacer()
                }
                .padding(.leading, 50)
            }
        }
        .onAppear {
            if exerciseSet.weight > 0 { weightString = String(format: "%.1f", exerciseSet.weight) }
            if exerciseSet.reps > 0 { repsString = String(exerciseSet.reps) }
        }
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let dummyRef = Exercise(name: "Incline Dumbbell Press", targetMuscle: "Chest")
    let dummyWex = WorkoutExercise(exerciseRef: dummyRef)
    container.mainContext.insert(dummyRef)
    container.mainContext.insert(dummyWex)
    
    // Add dummy set
    let dummySet = ExerciseSet(weight: 80, reps: 10, hitFailure: true, restPauses: [4, 2])
    dummyWex.sets.append(dummySet)
    
    return NavigationStack {
        ActiveExerciseView(workoutExercise: dummyWex)
    }
    .modelContainer(container)
}
