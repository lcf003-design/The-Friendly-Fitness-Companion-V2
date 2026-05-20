import SwiftUI
import SwiftData

struct ActiveExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutExercise: WorkoutExercise
    var isEditMode: Bool = true
    
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
    
    // Plate Calculator State
    @State private var showPlateCalculator = false
    @State private var isShowingHelp = false
    
    init(workoutExercise: WorkoutExercise, isEditMode: Bool = true) {
        self.workoutExercise = workoutExercise
        self.isEditMode = isEditMode
        
        let targetId = workoutExercise.exerciseRef?.id ?? UUID()
        let filter = #Predicate<WorkoutExercise> { wex in
            wex.exerciseRef?.id == targetId
        }
        _history = Query(filter: filter)
    }
    
    // Finds the most recent past performance or the All-Time PR based on user preference
    private var ghost: WorkoutExercise? {
        let pastPerformances = history.filter { $0.id != workoutExercise.id && !$0.sets.isEmpty }
        
        if userSettings.first?.ghostTrackingPreference == 1 {
            // All-Time PR: Find the workout exercise containing the single set with the highest weight
            return pastPerformances.max(by: { a, b in
                let maxA = a.sets.map { $0.weight }.max() ?? 0.0
                let maxB = b.sets.map { $0.weight }.max() ?? 0.0
                return maxA < maxB
            })
        } else {
            // Most Recent
            return pastPerformances.last
        }
    }
    
    // Calculates max weight from the ghost
    private var ghostMaxWeight: Double {
        ghost?.sets.map { $0.weight }.max() ?? 0.0
    }
    
    // Calculates the recommended target load (2.5% increase, rounded to nearest 2.5)
    private var recommendedLoad: Double {
        if ghostMaxWeight > 0 {
            let increased = ghostMaxWeight * 1.025
            return round(increased / 2.5) * 2.5
        }
        return 0.0
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
                    let rawName = workoutExercise.loggedName.isEmpty ? (workoutExercise.exerciseRef?.name ?? "UNKNOWN") : workoutExercise.loggedName
                    Text(rawName.uppercased())
                        .font(Theme.Typography.technical(24, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    if ghost != nil, ghostMaxWeight > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "ghost.fill")
                            let ghostLabel = userSettings.first?.ghostTrackingPreference == 1 ? "GHOST (PR):" : "GHOST (RECENT):"
                            let weightStr = String(format: "%.1f", ghostMaxWeight)
                            Text("\(ghostLabel) \(weightStr) \(userSettings.first?.weightUnit ?? "lb")")
                        }
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 4)
                    }
                    
                    if estimated1RM > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(Theme.warningOrange)
                            let est1RMStr = String(format: "%.1f", estimated1RM)
                            Text("EST 1RM: \(est1RMStr) \(userSettings.first?.weightUnit ?? "lb")")
                        }
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 2)
                    }
                }
                .padding(.top)
                
                if recommendedLoad > 0 {
                    Button(action: {
                        showPlateCalculator = true
                    }) {
                        VStack(spacing: 4) {
                            Text("COACH'S RECOMMENDATION")
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.accent)
                            
                            Text("TARGET LOAD: \(recommendedLoad, specifier: "%.1f") \(userSettings.first?.weightUnit ?? "lb")")
                                .font(Theme.Typography.technical(14, weight: .black))
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
                                .background(Theme.accent.opacity(0.1))
                        )
                    }
                    .padding(.top, 16)
                    .sheet(isPresented: $showPlateCalculator) {
                        PlateCalculatorPopover(
                            weight: recommendedLoad,
                            unit: userSettings.first?.weightUnit ?? "lb"
                        )
                        .presentationDetents([.height(350)])
                    }
                }
                
                // Set Header
                HStack {
                    Text("SET")
                        .frame(width: 40, alignment: .center)
                    let unit = userSettings.first?.weightUnit ?? "lb"
                    Text(unit.uppercased())
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
                        ForEach(Array(workoutExercise.sets.enumerated()), id: \.element.id) { index, exerciseSet in
                            SetRowView(
                                setIndex: index + 1,
                                exerciseSet: exerciseSet,
                                ghostMaxWeight: ghostMaxWeight,
                                tempoProfile: userSettings.first?.tempoProfile ?? "1-1-1",
                                isEditMode: isEditMode,
                                onComplete: { startTimer() },
                                onDelete: { deleteSet(exerciseSet) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollDismissesKeyboard(.interactively)
                
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
                
                if isEditMode {
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
        }
        .navigationTitle("The Grind")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isShowingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    if userSettings.first?.isHapticMetronomeEnabled == true {
                        Button(action: toggleMetronome) {
                            Image(systemName: isMetronomeActive ? "metronome.fill" : "metronome")
                                .foregroundColor(isMetronomeActive ? Theme.warningOrange : Theme.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingHelp) {
            ActiveExerciseHelpView()
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
    
    private func deleteSet(_ set: ExerciseSet) {
        if let index = workoutExercise.sets.firstIndex(where: { $0.id == set.id }) {
            workoutExercise.sets.remove(at: index)
            modelContext.delete(set)
            HapticManager.shared.playHeavyImpact()
        }
    }
}

struct SetRowView: View {
    let setIndex: Int
    @Bindable var exerciseSet: ExerciseSet
    let ghostMaxWeight: Double
    let tempoProfile: String
    var isEditMode: Bool = true
    var onComplete: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    @State private var rpCountdown: Int = 0
    @State private var isRPActive: Bool = false
    @State private var rpTimer: Timer?
    @State private var isShowingNotes: Bool = false
    
    private var parsedTempoDuration: Int {
        let digits = tempoProfile.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        let sum = digits.reduce(0, +)
        return sum > 0 ? sum : 1
    }
    
    private var tutSeconds: Int {
        return exerciseSet.reps * parsedTempoDuration
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // MAIN INTENSITY MATRIX
                HStack(alignment: .top, spacing: 8) {
                    
                    // COLUMN 1: CHECKMARK
                    Button(action: {
                        if isEditMode {
                            exerciseSet.isCompleted.toggle()
                            if exerciseSet.isCompleted {
                                HapticManager.shared.playSuccess()
                                onComplete?()
                            }
                        }
                    }) {
                        Image(systemName: exerciseSet.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(exerciseSet.isCompleted ? Theme.apexGreen : Theme.textSecondary)
                            .font(.title3)
                    }
                    .disabled(!isEditMode)
                    .frame(width: 40, height: 44, alignment: .center)
                    
                    // COLUMN 2: METRICS MATRIX
                    VStack(spacing: 6) {
                        // Top Row: Primary Metrics (Weight & Reps)
                        HStack(spacing: 8) {
                            TextField("-", text: $weightString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.title2.bold())
                                .monospacedDigit()
                                .foregroundColor((exerciseSet.weight > ghostMaxWeight && ghostMaxWeight > 0) ? Theme.warningOrange : Theme.textPrimary)
                                .frame(height: 44)
                                .background(Theme.surface)
                                .cornerRadius(8)
                                .disabled(!isEditMode)
                                .onChange(of: weightString) { 
                                    let newWeight = Double(weightString) ?? 0.0
                                    if newWeight > ghostMaxWeight && exerciseSet.weight <= ghostMaxWeight && ghostMaxWeight > 0 {
                                        HapticManager.shared.playPR()
                                    }
                                    exerciseSet.weight = newWeight 
                                }
                            
                            TextField("-", text: $repsString)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title2.bold())
                                .monospacedDigit()
                                .foregroundColor(Theme.textPrimary)
                                .frame(height: 44)
                                .background(Theme.surface)
                                .cornerRadius(8)
                                .disabled(!isEditMode)
                                .onChange(of: repsString) { exerciseSet.reps = Int(repsString) ?? 0 }
                        }
                        
                        // Middle Row: Inroad Gauge
                        GeometryReader { geo in
                            let ratio = ghostMaxWeight > 0 ? min(exerciseSet.weight / ghostMaxWeight, 1.0) : 0.0
                            let isBreakthrough = ghostMaxWeight > 0 && exerciseSet.weight > ghostMaxWeight
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Theme.surface)
                                Rectangle()
                                    .fill(isBreakthrough ? Theme.warningOrange : Theme.accent)
                                    .frame(width: geo.size.width * ratio)
                                    .animation(.spring(), value: ratio)
                                    .symbolEffect(.pulse, options: .repeating, isActive: isBreakthrough)
                            }
                        }
                        .frame(height: 4)
                        .clipShape(Capsule())
                        
                        // Bottom Row: Micro-Metrics
                        HStack {
                            Text("TUT: \(tutSeconds)S")
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(Theme.textSecondary)
                            
                            Spacer()
                            
                            // Forced Reps
                            HStack(spacing: 4) {
                                Text("F")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Button("-") { if exerciseSet.forcedReps > 0 { exerciseSet.forcedReps -= 1; HapticManager.shared.playSelection() } }.disabled(!isEditMode)
                                Text("\(exerciseSet.forcedReps)")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(Theme.accent)
                                Button("+") { exerciseSet.forcedReps += 1; HapticManager.shared.playSelection() }.disabled(!isEditMode)
                            }
                            
                            Spacer()
                            
                            // Negatives
                            HStack(spacing: 4) {
                                Text("N")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Button("-") { if exerciseSet.negatives > 0 { exerciseSet.negatives -= 1; HapticManager.shared.playSelection() } }.disabled(!isEditMode)
                                Text("\(exerciseSet.negatives)")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(Theme.warningOrange)
                                Button("+") { exerciseSet.negatives += 1; HapticManager.shared.playSelection() }.disabled(!isEditMode)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // COLUMN 3: ACTIONS
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            exerciseSet.restPauses.append(0)
                            rpTimer?.invalidate()
                            rpCountdown = 15
                            isRPActive = true
                            rpTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                if rpCountdown > 0 {
                                    rpCountdown -= 1
                                } else {
                                    timer.invalidate()
                                    isRPActive = false
                                    HapticManager.shared.playHeavyImpact()
                                }
                            }
                        }) {
                            Image(systemName: "plus.forwardslash.minus")
                                .foregroundColor(Theme.warningOrange)
                        }
                        .disabled(!isEditMode)
                        
                        Button(action: {
                            HapticManager.shared.playHeavyImpact()
                            exerciseSet.hitFailure.toggle()
                        }) {
                            Image(systemName: exerciseSet.hitFailure ? "flame.fill" : "flame")
                                .foregroundColor(exerciseSet.hitFailure ? Theme.dangerRed : Theme.border)
                        }
                        .disabled(!isEditMode)
                        
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            withAnimation { isShowingNotes.toggle() }
                        }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor((isShowingNotes || !exerciseSet.notes.isEmpty) ? Theme.accent : Theme.border)
                        }
                        
                        Button(action: {
                            HapticManager.shared.playHeavyImpact()
                            onDelete?()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(Theme.dangerRed)
                        }
                        .disabled(!isEditMode)
                    }
                    .frame(width: 120, height: 44, alignment: .center)
                }
                
                // NOTES ROW
                if isShowingNotes || !exerciseSet.notes.isEmpty {
                    TextField("Set notes...", text: Binding(
                        get: { exerciseSet.notes },
                        set: { exerciseSet.notes = $0 }
                    ))
                    .font(Theme.Typography.technical(14))
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Theme.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                    )
                    .disabled(!isEditMode)
                    .padding(.leading, 40)
                    .padding(.trailing, 10)
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
                            .disabled(!isEditMode)
                        }
                        Spacer()
                    }
                    .padding(.leading, 50)
                }
                
                if isRPActive {
                    HStack {
                        // Restart Button
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            rpCountdown = 15
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3)
                                .foregroundColor(Theme.warningOrange)
                        }
                        
                        Spacer()
                        
                        Text("REST-PAUSE: \(rpCountdown)s")
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(Theme.warningOrange)
                            
                        Spacer()
                        
                        // Stop Button
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            rpTimer?.invalidate()
                            isRPActive = false
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title3)
                                .foregroundColor(Theme.warningOrange)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.warningOrange, lineWidth: 2)
                    )
                }
            }
        }
        .contextMenu {
            if isEditMode {
                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("Delete Set", systemImage: "trash")
                }
            }
        }
        .onAppear {
            if exerciseSet.weight > 0 { weightString = String(format: "%.1f", exerciseSet.weight) }
            if exerciseSet.reps > 0 { repsString = String(exerciseSet.reps) }
        }
        .onDisappear {
            rpTimer?.invalidate()
        }
    }
}

struct PlateCalculatorPopover: View {
    let weight: Double
    let unit: String
    
    private var plates: [(plate: Double, count: Int)] {
        let barWeight = unit == "kg" ? 20.0 : 45.0
        let availablePlates = unit == "kg" ? [20.0, 15.0, 10.0, 5.0, 2.5, 1.25] : [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
        var targetPerSide = (weight - barWeight) / 2.0
        if targetPerSide <= 0 { return [] }
        
        var result: [(plate: Double, count: Int)] = []
        for plate in availablePlates {
            if targetPerSide >= plate {
                let count = Int(targetPerSide / plate)
                result.append((plate, count))
                targetPerSide -= Double(count) * plate
            }
        }
        return result
    }
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("PLATE BLUEPRINT")
                    .font(Theme.Typography.technical(16, weight: .black))
                    .foregroundColor(Theme.accent)
                
                Divider().background(Theme.border.opacity(0.3))
                
                Text("TOTAL: \(weight, specifier: "%.1f") \(unit)")
                    .font(Theme.Typography.technical(18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text("BAR: \(unit == "kg" ? 20 : 45) \(unit)")
                    .font(Theme.Typography.technical(12))
                    .foregroundColor(Theme.textSecondary)
                
                if plates.isEmpty {
                    Text("Bar only.")
                        .font(Theme.Typography.technical(14))
                        .foregroundColor(Theme.warningOrange)
                        .padding(.top)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PER SIDE:")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        ForEach(plates, id: \.plate) { item in
                            HStack {
                                Text("\(item.plate, specifier: "%g") \(unit) plate")
                                    .font(Theme.Typography.technical(16))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("x\(item.count)")
                                    .font(Theme.Typography.technical(16, weight: .black))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top, 24)
        }
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try? ModelContainer(for: schema, configurations: [config])
    
    guard let safeContainer = container else {
        return AnyView(Text("Preview failed to load container"))
    }
    let dummyRef = Exercise(name: "Incline Dumbbell Press", targetMuscle: "Chest")
    let dummyWex = WorkoutExercise(exerciseRef: dummyRef)
    safeContainer.mainContext.insert(dummyRef)
    safeContainer.mainContext.insert(dummyWex)
    
    // Add dummy set
    let dummySet = ExerciseSet(weight: 80, reps: 10, hitFailure: true, restPauses: [4, 2])
    dummyWex.sets.append(dummySet)
    
    return AnyView(NavigationStack {
        ActiveExerciseView(workoutExercise: dummyWex)
    }
    .modelContainer(safeContainer))
}
