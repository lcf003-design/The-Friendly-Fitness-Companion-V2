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
    
    // Celebration Particle State
    @State private var particles: [Particle] = []
    
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
    
    private var weightUnit: String {
        userSettings.first?.weightUnit ?? "lb"
    }
    
    // Calculates the recommended progressive overload target
    private var overloadAdvice: (targetWeight: Double, targetReps: Int, note: String) {
        guard let settings = userSettings.first else {
            return (0.0, 8, "Configure settings to enable progressive overload planner.")
        }
        
        // Find matching exercises in past performances from history
        let pastExercises = history.filter { $0.id != workoutExercise.id && !$0.sets.isEmpty }
        
        var lastWeight = 0.0
        var lastReps = 8
        var hitFailureLastTime = false
        var hasHistory = false
        
        // Find the most recent completed performance
        for wex in pastExercises.reversed() {
            let completedSets = wex.sets.filter { $0.isCompleted }
            if !completedSets.isEmpty {
                if let maxSet = completedSets.max(by: { $0.weight < $1.weight }) {
                    lastWeight = maxSet.weight
                    lastReps = maxSet.reps
                    hitFailureLastTime = maxSet.hitFailure
                    hasHistory = true
                }
                break
            }
        }
        
        if !hasHistory {
            return (0.0, 8, "No past logs. Establish a baseline today!")
        }
        
        let unit = settings.weightUnit.lowercased()
        let step = unit == "kg" ? 2.5 : 5.0
        let phase = settings.currentPhase.lowercased()
        
        if hitFailureLastTime {
            return (
                lastWeight,
                lastReps,
                "Last set hit failure. Solidify \(String(format: "%g", lastWeight)) \(unit) for \(lastReps) reps before adding weight."
            )
        }
        
        if phase.contains("strength") {
            if lastReps >= 5 {
                let nextWeight = lastWeight + step
                return (
                    nextWeight,
                    3,
                    "Strength target met. Load \(String(format: "%g", nextWeight)) \(unit) for 3–5 reps."
                )
            } else {
                return (
                    lastWeight,
                    lastReps + 1,
                    "Strength progression: Lift \(String(format: "%g", lastWeight)) \(unit) for \(lastReps + 1) reps."
                )
            }
        } else {
            if lastReps >= 12 {
                let nextWeight = lastWeight + step
                return (
                    nextWeight,
                    8,
                    "Hypertrophy ceiling hit. Step up to \(String(format: "%g", nextWeight)) \(unit) for 8 reps."
                )
            } else {
                return (
                    lastWeight,
                    lastReps + 1,
                    "Rep progression: Lift \(String(format: "%g", lastWeight)) \(unit) for \(lastReps + 1) reps."
                )
            }
        }
    }
    
    private func calculatePlates(for weight: Double) -> [(plate: Double, count: Int)] {
        let unit = weightUnit
        let allPlates = unit == "kg" ? [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25] : [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
        
        let activePlates: [Double]
        if let csv = userSettings.first?.availablePlatesCSV, !csv.isEmpty {
            let parsed = csv.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let intersected = parsed.filter { allPlates.contains($0) }
            activePlates = intersected.isEmpty ? allPlates : intersected
        } else {
            activePlates = allPlates
        }
        
        let barWeight = unit == "kg" ? 20.0 : 45.0
        var targetPerSide = (weight - barWeight) / 2.0
        if targetPerSide <= 0 { return [] }
        
        var result: [(plate: Double, count: Int)] = []
        for plate in activePlates.sorted(by: >) {
            if targetPerSide >= plate {
                let count = Int(targetPerSide / plate)
                result.append((plate, count))
                targetPerSide -= Double(count) * plate
            }
        }
        return result
    }
    
    // Calculates the Estimated 1-Rep Max for the current active workout exercise using the Epley formula
    private var estimated1RM: Double {
        let completedSets = workoutExercise.sets.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 && $0.setType != "warmup" }
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
                    let rawName = workoutExercise.loggedName.isEmpty ? (workoutExercise.exerciseRef?.name ?? "Unknown") : workoutExercise.loggedName
                    Text(rawName)
                        .font(Theme.Typography.technical(24, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    if ghost != nil, ghostMaxWeight > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "ghost.fill")
                            let ghostLabel = userSettings.first?.ghostTrackingPreference == 1 ? "Ghost (PR):" : "Ghost (Recent):"
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
                            Text("Est. 1RM: \(est1RMStr) \(userSettings.first?.weightUnit ?? "lb")")
                        }
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 2)
                    }
                    
                    if let exercise = workoutExercise.exerciseRef {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Rest Target: \(exercise.defaultRestTime)s")
                            
                            if isEditMode {
                                Button(action: {
                                    HapticManager.shared.playSelection()
                                    exercise.defaultRestTime = max(30, exercise.defaultRestTime - 15)
                                    try? modelContext.save()
                                }) {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    HapticManager.shared.playSelection()
                                    exercise.defaultRestTime = min(600, exercise.defaultRestTime + 15)
                                    try? modelContext.save()
                                }) {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 2)
                    }
                }
                .padding(.top)
                
                let advice = overloadAdvice
                if advice.targetWeight > 0 {
                    VStack(spacing: 12) {
                        VStack(spacing: 6) {
                            Text("Coach's Recommendation")
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.accent)
                            
                            Text("Target: \(advice.targetWeight, specifier: "%g") \(weightUnit) × \(advice.targetReps)")
                                .font(Theme.Typography.technical(16, weight: .black))
                                .foregroundColor(Theme.accent)
                            
                            Text(advice.note)
                                .font(Theme.Typography.technical(11))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                HapticManager.shared.playSuccess()
                                applyCoachRecommendation()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Apply Advice")
                                }
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.midnightMatte)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Theme.accent)
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                HapticManager.shared.playSelection()
                                showPlateCalculator = true
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("Load Plates")
                                }
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Theme.surface)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                            .background(Theme.accent.opacity(0.08))
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .sheet(isPresented: $showPlateCalculator) {
                        BarbellPlateLoaderSheet(
                            weight: advice.targetWeight,
                            unit: weightUnit,
                            plates: calculatePlates(for: advice.targetWeight),
                            barbellName: userSettings.first?.barbellType ?? (weightUnit == "kg" ? "Olympic Bar (20 kg)" : "Olympic Bar (45 lb)"),
                            barbellWeight: userSettings.first?.barbellWeight ?? (weightUnit == "kg" ? 20.0 : 45.0),
                            onApplyWeight: { appliedWeight in
                                applyCoachRecommendation()
                            }
                        )
                    }
                }
                
                // Set Header
                let isCardio = workoutExercise.exerciseRef?.targetMuscle == "Cardio"
                HStack {
                    Text("Set")
                        .frame(width: 40, alignment: .center)
                    if isCardio {
                        let distUnit = (userSettings.first?.weightUnit == "kg") ? "km" : "mi"
                        Text("Dist (\(distUnit))")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("Time")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("Kcal")
                            .frame(width: 80, alignment: .center)
                    } else {
                        let unit = userSettings.first?.weightUnit ?? "lb"
                        Text(unit)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("Reps")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("RP/Fail")
                            .frame(width: 80, alignment: .center)
                    }
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
                                isCardio: workoutExercise.exerciseRef?.targetMuscle == "Cardio",
                                ghostMaxWeight: ghostMaxWeight,
                                tempoProfile: userSettings.first?.tempoProfile ?? "1-1-1",
                                isEditMode: isEditMode,
                                onComplete: { 
                                    triggerBurst()
                                    startTimer() 
                                },
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
                        Text("Add Set")
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
            
            // Particle celebration overlay
            if !particles.isEmpty {
                ZStack {
                    ForEach(particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: particle.x, y: particle.y)
                            .opacity(particle.opacity)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .navigationTitle("Log Exercise")
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
        timeRemaining = workoutExercise.exerciseRef?.defaultRestTime ?? 120
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
    
    private func triggerBurst() {
        let colors: [Color] = [Theme.accent, Theme.warningOrange, Theme.apexGreen, .yellow, .white]
        var newParticles: [Particle] = []
        
        // Generate 30 random particles
        for _ in 0..<30 {
            let p = Particle(
                x: 0,
                y: 0,
                color: colors.randomElement() ?? Theme.accent,
                size: CGFloat.random(in: 4...10),
                opacity: 1.0
            )
            newParticles.append(p)
        }
        
        self.particles = newParticles
        
        // Animate dispersing and fading out
        withAnimation(.easeOut(duration: 0.8)) {
            for index in 0..<self.particles.count {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 80...180)
                self.particles[index].x = cos(angle) * distance
                self.particles[index].y = sin(angle) * distance
                self.particles[index].opacity = 0.0
            }
        }
        
        // Clear particles after animation finishes to release memory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.particles.removeAll()
        }
    }
    
    private func applyCoachRecommendation() {
        let advice = overloadAdvice
        guard advice.targetWeight > 0 else { return }
        
        if let uncompletedSet = workoutExercise.sets.first(where: { !$0.isCompleted }) {
            uncompletedSet.weight = advice.targetWeight
            uncompletedSet.reps = advice.targetReps
            try? modelContext.save()
        } else {
            let newSet = ExerciseSet(weight: advice.targetWeight, reps: advice.targetReps)
            modelContext.insert(newSet)
            workoutExercise.sets.append(newSet)
            try? modelContext.save()
        }
        HapticManager.shared.playSuccess()
    }
    
    private func addSet() {
        var weight = 0.0
        var reps = 0
        var cardioDistance = 0.0
        var cardioDurationSeconds = 0
        var cardioCalories = 0
        
        let isCardio = workoutExercise.exerciseRef?.targetMuscle == "Cardio"
        
        if let lastSet = workoutExercise.sets.last {
            if isCardio {
                cardioDistance = lastSet.cardioDistance
                cardioDurationSeconds = lastSet.cardioDurationSeconds
                cardioCalories = lastSet.cardioCalories
            } else {
                weight = lastSet.weight
                reps = lastSet.reps
            }
        } else {
            // First set
            if !isCardio {
                let advice = overloadAdvice
                if advice.targetWeight > 0 {
                    weight = advice.targetWeight
                    reps = advice.targetReps
                } else {
                    weight = 0.0
                    reps = 8 // default reps fallback
                }
            }
        }
        
        let newSet = ExerciseSet(
            weight: weight,
            reps: reps,
            cardioDistance: cardioDistance,
            cardioDurationSeconds: cardioDurationSeconds,
            cardioCalories: cardioCalories
        )
        modelContext.insert(newSet)
        workoutExercise.sets.append(newSet)
        try? modelContext.save()
        
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

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var opacity: Double
}

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    let setIndex: Int
    @Bindable var exerciseSet: ExerciseSet
    let isCardio: Bool
    let ghostMaxWeight: Double
    let tempoProfile: String
    var isEditMode: Bool = true
    var onComplete: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @Query private var userSettings: [UserSettings]
    
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    @State private var distanceString: String = ""
    @State private var durationString: String = ""
    @State private var caloriesString: String = ""
    @State private var rpCountdown: Int = 0
    @State private var isRPActive: Bool = false
    @State private var rpTimer: Timer?
    @State private var isShowingNotes: Bool = false
    @State private var isShowingPlateLoader: Bool = false
    @State private var animateBurst = false
    @State private var burstOffset: CGFloat = 0
    @State private var burstOpacity: Double = 0
    
    private var weightUnit: String {
        userSettings.first?.weightUnit ?? "lb"
    }
    
    private var calculatedPlates: [(plate: Double, count: Int)] {
        let weight = exerciseSet.weight
        let unit = weightUnit
        let allPlates = unit == "kg" ? [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25] : [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
        
        let activePlates: [Double]
        if let csv = userSettings.first?.availablePlatesCSV, !csv.isEmpty {
            let parsed = csv.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let intersected = parsed.filter { allPlates.contains($0) }
            activePlates = intersected.isEmpty ? allPlates : intersected
        } else {
            activePlates = allPlates
        }
        
        let barWeight = unit == "kg" ? 20.0 : 45.0
        var targetPerSide = (weight - barWeight) / 2.0
        if targetPerSide <= 0 { return [] }
        
        var result: [(plate: Double, count: Int)] = []
        for plate in activePlates.sorted(by: >) {
            if targetPerSide >= plate {
                let count = Int(targetPerSide / plate)
                result.append((plate, count))
                targetPerSide -= Double(count) * plate
            }
        }
        return result
    }
    
    private var setTypeLabel: String {
        switch exerciseSet.setType {
        case "warmup": return "W"
        case "drop": return "D"
        default: return "\(setIndex)"
        }
    }
    
    private var setTypeColor: Color {
        switch exerciseSet.setType {
        case "warmup": return Theme.warningOrange
        case "drop": return .purple
        default: return Theme.textSecondary
        }
    }
    
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
                    
                    // COLUMN 1: CHECKMARK & SET TYPE SELECTOR
                    VStack(spacing: 6) {
                        Button(action: {
                            if isEditMode {
                                exerciseSet.isCompleted.toggle()
                                if exerciseSet.isCompleted {
                                    HapticManager.shared.playSuccess()
                                    burstOffset = 0
                                    burstOpacity = 1.0
                                    animateBurst = true
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        burstOffset = 26
                                        burstOpacity = 0.0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        animateBurst = false
                                        burstOffset = 0
                                        burstOpacity = 0.0
                                    }
                                    onComplete?()
                                }
                            }
                        }) {
                            ZStack {
                                Image(systemName: exerciseSet.isCompleted ? "checkmark.square.fill" : "square")
                                    .foregroundColor(exerciseSet.isCompleted ? Theme.apexGreen : Theme.textSecondary)
                                    .font(.title3)
                                    .scaleEffect(animateBurst ? 1.4 : 1.0)
                                
                                if animateBurst {
                                    ForEach(0..<6) { i in
                                        let angle = Double(i) * .pi / 3
                                        Circle()
                                            .fill([Theme.accent, Theme.apexGreen, .purple, Theme.warningOrange].randomElement()!)
                                            .frame(width: 5, height: 5)
                                            .offset(x: burstOffset * cos(angle), y: burstOffset * sin(angle))
                                            .opacity(burstOpacity)
                                    }
                                    
                                    Circle()
                                        .stroke(Theme.apexGreen.opacity(0.8), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                        .scaleEffect(1.0 + (burstOffset / 20.0))
                                        .opacity(burstOpacity)
                                }
                            }
                        }
                        .disabled(!isEditMode)
                        
                        Menu {
                            Button("Working Set") {
                                exerciseSet.setType = "working"
                                HapticManager.shared.playSelection()
                            }
                            Button("Warm-up (W)") {
                                exerciseSet.setType = "warmup"
                                HapticManager.shared.playSelection()
                            }
                            Button("Drop Set (D)") {
                                exerciseSet.setType = "drop"
                                HapticManager.shared.playSelection()
                            }
                        } label: {
                            Text(setTypeLabel)
                                .font(Theme.Typography.technical(8, weight: .black))
                                .foregroundColor(setTypeColor)
                                .frame(width: 24, height: 16)
                                .background(setTypeColor.opacity(0.15))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(setTypeColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .disabled(!isEditMode)
                    }
                    .frame(width: 44, height: 48)
                    
                    // COLUMN 2: METRICS MATRIX
                    VStack(spacing: 6) {
                        // Top Row: Primary Metrics (Weight & Reps OR Cardio details)
                        HStack(spacing: 8) {
                            if isCardio {
                                // Distance Column
                                VStack(spacing: 4) {
                                    HStack(spacing: 0) {
                                        if isEditMode {
                                            Button(action: {
                                                let current = Double(distanceString) ?? 0.0
                                                let newVal = max(0, current - 0.1)
                                                distanceString = String(format: "%.2f", newVal)
                                                exerciseSet.cardioDistance = newVal
                                                HapticManager.shared.playSelection()
                                            }) {
                                                Image(systemName: "minus")
                                                    .font(.caption.bold())
                                                    .foregroundColor(Theme.textSecondary)
                                                    .frame(width: 20, height: 44)
                                            }
                                        }
                                        
                                        TextField("-", text: $distanceString)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                            .font(.title3.bold())
                                            .monospacedDigit()
                                            .foregroundColor(Theme.textPrimary)
                                            .frame(height: 44)
                                            .disabled(!isEditMode)
                                            .onChange(of: distanceString) { 
                                                exerciseSet.cardioDistance = Double(distanceString) ?? 0.0
                                            }
                                        
                                        if isEditMode {
                                            Button(action: {
                                                let current = Double(distanceString) ?? 0.0
                                                let newVal = current + 0.1
                                                distanceString = String(format: "%.2f", newVal)
                                                exerciseSet.cardioDistance = newVal
                                                HapticManager.shared.playSelection()
                                            }) {
                                                Image(systemName: "plus")
                                                    .font(.caption.bold())
                                                    .foregroundColor(Theme.textSecondary)
                                                    .frame(width: 20, height: 44)
                                            }
                                        }
                                    }
                                    .background(Theme.surface)
                                    .cornerRadius(8)
                                }
                                
                                // Duration Column (MM:SS)
                                HStack(spacing: 0) {
                                    TextField("00:00", text: $durationString)
                                        .keyboardType(.numbersAndPunctuation)
                                        .multilineTextAlignment(.center)
                                        .font(.title3.bold())
                                        .monospacedDigit()
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(height: 44)
                                        .disabled(!isEditMode)
                                        .onChange(of: durationString) { 
                                            let parts = durationString.components(separatedBy: ":")
                                            if parts.count == 2 {
                                                let mins = Int(parts[0]) ?? 0
                                                let secs = Int(parts[1]) ?? 0
                                                exerciseSet.cardioDurationSeconds = (mins * 60) + secs
                                            } else if let totalSecs = Int(durationString) {
                                                exerciseSet.cardioDurationSeconds = totalSecs
                                            }
                                        }
                                }
                                .background(Theme.surface)
                                .cornerRadius(8)
                                
                                // Calories Column
                                HStack(spacing: 0) {
                                    if isEditMode {
                                        Button(action: {
                                            let current = Int(caloriesString) ?? 0
                                            let newVal = max(0, current - 10)
                                            caloriesString = String(newVal)
                                            exerciseSet.cardioCalories = newVal
                                            HapticManager.shared.playSelection()
                                        }) {
                                            Image(systemName: "minus")
                                                .font(.caption.bold())
                                                .foregroundColor(Theme.textSecondary)
                                                .frame(width: 20, height: 44)
                                        }
                                    }
                                    
                                    TextField("-", text: $caloriesString)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .font(.title3.bold())
                                        .monospacedDigit()
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(height: 44)
                                        .disabled(!isEditMode)
                                        .onChange(of: caloriesString) { 
                                            exerciseSet.cardioCalories = Int(caloriesString) ?? 0 
                                        }
                                    
                                    if isEditMode {
                                        Button(action: {
                                            let current = Int(caloriesString) ?? 0
                                            let newVal = current + 10
                                            caloriesString = String(newVal)
                                            exerciseSet.cardioCalories = newVal
                                            HapticManager.shared.playSelection()
                                        }) {
                                            Image(systemName: "plus")
                                                .font(.caption.bold())
                                                .foregroundColor(Theme.textSecondary)
                                                .frame(width: 20, height: 44)
                                        }
                                    }
                                }
                                .background(Theme.surface)
                                .cornerRadius(8)
                            } else {
                                // Weight Column
                                VStack(spacing: 4) {
                                    HStack(spacing: 0) {
                                        if isEditMode {
                                            Button(action: {
                                                let current = Double(weightString) ?? 0.0
                                                let step = 2.5
                                                let newVal = max(0, current - step)
                                                weightString = String(format: "%g", newVal)
                                                exerciseSet.weight = newVal
                                                HapticManager.shared.playSelection()
                                            }) {
                                                Image(systemName: "minus")
                                                    .font(.caption.bold())
                                                    .foregroundColor(Theme.textSecondary)
                                                    .frame(width: 24, height: 44)
                                            }
                                        }
                                        
                                        TextField("-", text: $weightString)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                            .font(.title2.bold())
                                            .monospacedDigit()
                                            .foregroundColor((exerciseSet.weight > ghostMaxWeight && ghostMaxWeight > 0) ? Theme.warningOrange : Theme.textPrimary)
                                            .frame(height: 44)
                                            .disabled(!isEditMode)
                                            .onChange(of: weightString) { 
                                                let newWeight = Double(weightString) ?? 0.0
                                                if newWeight > ghostMaxWeight && exerciseSet.weight <= ghostMaxWeight && ghostMaxWeight > 0 {
                                                    HapticManager.shared.playPR()
                                                }
                                                exerciseSet.weight = newWeight 
                                            }
                                        
                                        if isEditMode {
                                            Button(action: {
                                                let current = Double(weightString) ?? 0.0
                                                let step = 2.5
                                                let newVal = current + step
                                                weightString = String(format: "%g", newVal)
                                                exerciseSet.weight = newVal
                                                if newVal > ghostMaxWeight && current <= ghostMaxWeight && ghostMaxWeight > 0 {
                                                    HapticManager.shared.playPR()
                                                } else {
                                                    HapticManager.shared.playSelection()
                                                }
                                            }) {
                                                Image(systemName: "plus")
                                                    .font(.caption.bold())
                                                    .foregroundColor(Theme.textSecondary)
                                                    .frame(width: 24, height: 44)
                                            }
                                        }
                                    }
                                    .background(Theme.surface)
                                    .cornerRadius(8)
                                    
                                    if exerciseSet.weight > 0 {
                                        let plates = calculatedPlates
                                        Button(action: {
                                            HapticManager.shared.playSelection()
                                            isShowingPlateLoader = true
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "info.circle")
                                                    .font(.system(size: 8))
                                                if !plates.isEmpty {
                                                    Text(plates.map { "\($0.plate)\(weightUnit == "kg" ? "k" : "")×\($0.count)" }.joined(separator: " "))
                                                } else {
                                                    let barWeight = weightUnit == "kg" ? 20.0 : 45.0
                                                    Text(exerciseSet.weight < barWeight ? "Under Bar" : "Bar Only")
                                                }
                                            }
                                            .font(Theme.Typography.technical(8, weight: .bold))
                                            .foregroundColor(plates.isEmpty ? Theme.textSecondary : Theme.accent)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(plates.isEmpty ? Theme.surface : Theme.accent.opacity(0.15))
                                            .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                        .sheet(isPresented: $isShowingPlateLoader) {
                                            BarbellPlateLoaderSheet(
                                                weight: exerciseSet.weight,
                                                unit: weightUnit,
                                                plates: plates,
                                                barbellName: userSettings.first?.barbellType ?? (weightUnit == "kg" ? "Olympic Bar (20 kg)" : "Olympic Bar (45 lb)"),
                                                barbellWeight: userSettings.first?.barbellWeight ?? (weightUnit == "kg" ? 20.0 : 45.0),
                                                onApplyWeight: { appliedWeight in
                                                    exerciseSet.weight = appliedWeight
                                                    try? modelContext.save()
                                                }
                                            )
                                        }
                                    }
                                }
                                
                                // Reps Column
                                HStack(spacing: 0) {
                                    if isEditMode {
                                        Button(action: {
                                            let current = Int(repsString) ?? 0
                                            let newVal = max(0, current - 1)
                                            repsString = String(newVal)
                                            exerciseSet.reps = newVal
                                            HapticManager.shared.playSelection()
                                        }) {
                                            Image(systemName: "minus")
                                                .font(.caption.bold())
                                                .foregroundColor(Theme.textSecondary)
                                                .frame(width: 24, height: 44)
                                        }
                                    }
                                    
                                    TextField("-", text: $repsString)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .font(.title2.bold())
                                        .monospacedDigit()
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(height: 44)
                                        .disabled(!isEditMode)
                                        .onChange(of: repsString) { exerciseSet.reps = Int(repsString) ?? 0 }
                                    
                                    if isEditMode {
                                        Button(action: {
                                            let current = Int(repsString) ?? 0
                                            let newVal = current + 1
                                            repsString = String(newVal)
                                            exerciseSet.reps = newVal
                                            HapticManager.shared.playSelection()
                                        }) {
                                            Image(systemName: "plus")
                                                .font(.caption.bold())
                                                .foregroundColor(Theme.textSecondary)
                                                .frame(width: 24, height: 44)
                                        }
                                    }
                                }
                                .background(Theme.surface)
                                .cornerRadius(8)
                            }
                        }
                        
                        if !isCardio {
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
                                Text("TUT: \(tutSeconds)s")
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
                    }
                    .frame(maxWidth: .infinity)
                    
                    // COLUMN 3: ACTIONS
                    HStack(spacing: 12) {
                        if !isCardio {
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
                        }
                        
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
                    .frame(width: isCardio ? 80 : 136, height: 44, alignment: .center)
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
            if isCardio {
                if exerciseSet.cardioDistance > 0 { distanceString = String(format: "%.2f", exerciseSet.cardioDistance) }
                if exerciseSet.cardioDurationSeconds > 0 {
                    let mins = exerciseSet.cardioDurationSeconds / 60
                    let secs = exerciseSet.cardioDurationSeconds % 60
                    durationString = String(format: "%02d:%02d", mins, secs)
                }
                if exerciseSet.cardioCalories > 0 { caloriesString = String(exerciseSet.cardioCalories) }
            } else {
                if exerciseSet.weight > 0 { weightString = String(format: "%.1f", exerciseSet.weight) }
                if exerciseSet.reps > 0 { repsString = String(exerciseSet.reps) }
            }
        }
        .onDisappear {
            rpTimer?.invalidate()
        }
        .onChange(of: exerciseSet.weight) {
            weightString = exerciseSet.weight > 0 ? String(format: "%.1f", exerciseSet.weight) : ""
        }
        .onChange(of: exerciseSet.reps) {
            repsString = exerciseSet.reps > 0 ? String(exerciseSet.reps) : ""
        }
        .onChange(of: exerciseSet.cardioDistance) {
            distanceString = exerciseSet.cardioDistance > 0 ? String(format: "%.2f", exerciseSet.cardioDistance) : ""
        }
        .onChange(of: exerciseSet.cardioDurationSeconds) {
            if exerciseSet.cardioDurationSeconds > 0 {
                let mins = exerciseSet.cardioDurationSeconds / 60
                let secs = exerciseSet.cardioDurationSeconds % 60
                durationString = String(format: "%02d:%02d", mins, secs)
            } else {
                durationString = ""
            }
        }
        .onChange(of: exerciseSet.cardioCalories) {
            caloriesString = exerciseSet.cardioCalories > 0 ? String(exerciseSet.cardioCalories) : ""
        }
    }
}



#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self, FastingLogEntry.self])
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
