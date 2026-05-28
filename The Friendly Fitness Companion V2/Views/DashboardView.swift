import SwiftUI
import SwiftData
import Charts
import Combine

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var recentSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fastingSessions: [FastingSession]
    
    @State private var isShowingFastingToolbox = false
    @State private var isShowingHelp = false
    @State private var selectedMuscle: String? = nil
    @State private var isShowingMuscleDetail = false
    @State private var liveFastingElapsed: TimeInterval = 0
    private let fastingTimerPublisher = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // HealthKit metrics states
    @State private var liveHRV: Double? = nil
    @State private var liveSleep: Double? = nil
    @State private var isHealthKitAuthorized = false
    @State private var heatmapMode: AnatomicalBodyMap.HeatmapMode = .recovery
    
    // Custom bindings for manual overrides
    private var manualScoreBinding: Binding<Double> {
        Binding(
            get: {
                userSettings.first?.manualRecoveryScore ?? 0.8
            },
            set: { newValue in
                if let settings = userSettings.first {
                    settings.manualRecoveryScore = newValue
                }
            }
        )
    }
    
    private var isOverriddenBinding: Binding<Bool> {
        Binding(
            get: {
                userSettings.first?.isRecoveryOverridden ?? false
            },
            set: { newValue in
                if let settings = userSettings.first {
                    settings.isRecoveryOverridden = newValue
                }
            }
        )
    }
    
    // Calculates the number of days since a specific muscle group was trained
    private var recoveryMap: [String: Int] {
        var map: [String: Int] = [:]
        let now = Date()
        
        for session in recentSessions {
            let daysAgo = Calendar.current.dateComponents([.day], from: session.timestamp, to: now).day ?? 0
            
            for workoutEx in session.exercises {
                let muscle = workoutEx.normalizedTargetMuscle
                if muscle != "UNKNOWN" {
                    // Only keep the most recent (smallest daysAgo) because sessions are sorted descending
                    if map[muscle] == nil {
                        map[muscle] = daysAgo
                    }
                }
            }
        }
        return map
    }
    
    // Calculates total sets completed per muscle group over the last 7 days
    private var activationMap: [String: Int] {
        var map: [String: Int] = [:]
        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        for session in recentSessions where session.timestamp >= oneWeekAgo {
            for workoutEx in session.exercises {
                let muscle = workoutEx.normalizedTargetMuscle
                if muscle != "UNKNOWN" {
                    let completedSets = workoutEx.sets.filter { $0.isCompleted }.count
                    map[muscle, default: 0] += completedSets
                }
            }
        }
        return map
    }
    
    // Calculate total fitness score for the last 7 days
    private var weeklyFitnessScore: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeekSessions = recentSessions.filter { $0.timestamp >= oneWeekAgo }
        return thisWeekSessions.reduce(0) { $0 + $1.totalIntensityScore }
    }
    
    // Calculate total workouts this week
    private var thisWeekWorkoutCount: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recentSessions.filter { $0.timestamp >= oneWeekAgo }.count
    }
    
    // Calculates total weight moved per muscle group over the last 7 days
    private var volumeMap: [(muscle: String, volume: Double)] {
        var map: [String: Double] = [:]
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        for session in recentSessions where session.timestamp >= oneWeekAgo {
            for wex in session.exercises {
                let muscle = wex.normalizedTargetMuscle
                if muscle != "UNKNOWN" {
                    let volume = wex.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                    map[muscle, default: 0.0] += volume
                }
            }
        }
        return map.map { (muscle: $0.key, volume: $0.value) }.sorted { $0.volume > $1.volume }
    }
    
    // Chronological sessions for line graph
    private var weeklySessionsSorted: [WorkoutSession] {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recentSessions.filter { $0.timestamp >= oneWeekAgo }.sorted { $0.timestamp < $1.timestamp }
    }
    
    // Check if workouts were logged on specific days of the current week
    private func workoutsForWeekdays() -> [(dayName: String, date: Date, hasWorkedOut: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        
        // Find start of the current week (Monday)
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }
        
        var days: [(dayName: String, date: Date, hasWorkedOut: Bool)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // "Mon", "Tue"
        
        for i in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let dayName = formatter.string(from: dayDate).uppercased()
                let sessionsOnDay = recentSessions.filter { calendar.isDate($0.timestamp, inSameDayAs: dayDate) }
                days.append((
                    dayName: String(dayName.first ?? " "),
                    date: dayDate,
                    hasWorkedOut: !sessionsOnDay.isEmpty
                ))
            }
        }
        return days
    }
    
    private var overallRecoveryScore: Int {
        let muscles = MuscleGroup.all
        let recMap = recoveryMap
        var totalPoints = 0
        let sorenessMap = userSettings.first?.muscleSorenessMap ?? [:]
        
        for muscle in muscles {
            if let soreness = sorenessMap[muscle] {
                switch soreness {
                case 0:
                    totalPoints += 100 // Fresh
                case 1:
                    totalPoints += 50  // Sore
                case 2:
                    totalPoints += 15  // Extremely Sore (Sore+)
                default:
                    totalPoints += 100
                }
            } else if let days = recMap[muscle] {
                if days < 2 {
                    totalPoints += 30 // Exhausted
                } else if days < 4 {
                    totalPoints += 70 // Recovering
                } else {
                    totalPoints += 100 // Recovered
                }
            } else {
                totalPoints += 100 // Untrained = fully rested
            }
        }
        return totalPoints / muscles.count
    }
    
    private var activeRecoveryScore: Int {
        if let settings = userSettings.first, settings.isRecoveryOverridden {
            return Int(settings.manualRecoveryScore * 100)
        }
        
        let baseScore = Double(overallRecoveryScore)
        var adjustedScore = baseScore
        
        if let hrv = liveHRV {
            let hrvFactor = (hrv - 50.0) / 100.0
            adjustedScore += hrvFactor * 25.0
        }
        
        if let sleep = liveSleep {
            let sleepFactor = (sleep - 8.0) / 8.0
            adjustedScore += sleepFactor * 20.0
        }
        
        return max(0, min(100, Int(adjustedScore)))
    }
    
    private var coachInsight: CoachInsight {
        let defaultSettings = UserSettings()
        let settings = userSettings.first ?? defaultSettings
        let score = Double(activeRecoveryScore) / 100.0
        return AICoachService.shared.generateInsight(
            sessions: recentSessions,
            settings: settings,
            recoveryScore: score
        )
    }
    
    private func loadHealthKitTelemetry() {
        guard HealthKitManager.shared.isAvailable else { return }
        
        HealthKitManager.shared.requestAuthorization { success, _ in
            guard success else { return }
            isHealthKitAuthorized = true
            
            HealthKitManager.shared.fetchLatestHRV { hrv, _ in
                if let hrv = hrv {
                    self.liveHRV = hrv
                }
            }
            
            HealthKitManager.shared.fetchLatestSleepHours { sleep, _ in
                if let sleep = sleep {
                    self.liveSleep = sleep
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Stats
                        HStack(spacing: 20) {
                            StatCard(title: "Weekly Score", value: "\(weeklyFitnessScore)", icon: "flame.fill", color: Theme.warningOrange)
                            StatCard(title: "Workouts", value: "\(thisWeekWorkoutCount)", icon: "bolt.fill", color: Theme.accent)
                        }
                        .padding(.horizontal)
                        
                        // Active Fasting Tracker
                        if let fast = activeFast {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(Theme.accent)
                                    Text("Active Fasting")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                        .tracking(1.5)
                                    
                                    Spacer()
                                    
                                    let hours = liveFastingElapsed / 3600.0
                                    let phaseInfo = fastingPhaseInfo(for: hours)
                                    
                                    Text(phaseInfo.title)
                                        .font(Theme.Typography.technical(10, weight: .bold))
                                        .foregroundColor(phaseInfo.color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(phaseInfo.color.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(formatFastingDuration(liveFastingElapsed))
                                        .font(Theme.Typography.technical(32, weight: .black))
                                        .monospacedDigit()
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("/ \(fast.targetHours)H Target")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                // Quick progress bar (Capsule design)
                                let progress = min(liveFastingElapsed / (Double(fast.targetHours) * 3600.0), 1.0)
                                let hours = liveFastingElapsed / 3600.0
                                let phaseInfo = fastingPhaseInfo(for: hours)
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Theme.border)
                                            .frame(height: 6)
                                        
                                        Capsule()
                                            .fill(phaseInfo.color)
                                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                
                                HStack {
                                    Button(action: {
                                        HapticManager.shared.playSelection()
                                        isShowingFastingToolbox = true
                                    }) {
                                        Text("Open Tracker")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.accent.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        HapticManager.shared.playHeavyImpact()
                                        fast.isCompleted = true
                                        fast.endTime = Date()
                                        try? modelContext.save()
                                    }) {
                                        Text("End Fast")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.dangerRed)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.dangerRed.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(Theme.textSecondary)
                                    Text("Fasting Status")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                        .tracking(1.5)
                                    Spacer()
                                    
                                    let completedThisWeek = fastingSessions.filter {
                                        let calendar = Calendar.current
                                        let today = Date()
                                        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
                                        return $0.isCompleted && $0.startTime >= oneWeekAgo
                                    }.count
                                    
                                    Text("\(completedThisWeek) fasts this week")
                                        .font(Theme.Typography.technical(10, weight: .bold))
                                        .foregroundColor(Theme.accent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Theme.accent.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                
                                Text("No active fast. Establish a tracking interval to initiate lipid oxidation.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                
                                HStack(spacing: 8) {
                                    ForEach([12, 16, 18, 20], id: \.self) { targetHours in
                                        Button(action: {
                                            HapticManager.shared.playSuccess()
                                            let newFast = FastingSession(targetHours: targetHours)
                                            modelContext.insert(newFast)
                                            try? modelContext.save()
                                        }) {
                                            Text("\(targetHours)H")
                                                .font(Theme.Typography.technical(12, weight: .bold))
                                                .foregroundColor(Theme.textPrimary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(Theme.midnightMatte)
                                                .cornerRadius(10)
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                                        }
                                    }
                                    
                                    Button(action: {
                                        HapticManager.shared.playSelection()
                                        isShowingFastingToolbox = true
                                    }) {
                                        Image(systemName: "ellipsis")
                                            .font(.subheadline.bold())
                                            .foregroundColor(Theme.accent)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Theme.midnightMatte)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Recovery Readiness Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recovery Readiness")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                Spacer()
                                Text("\(activeRecoveryScore)%")
                                    .font(Theme.Typography.technical(14, weight: .black))
                                    .foregroundColor(activeRecoveryScore > 75 ? Theme.apexGreen : (activeRecoveryScore > 45 ? Theme.warningOrange : Theme.dangerRed))
                            }
                            
                            // Visual bar (Capsule style)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Theme.border)
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(activeRecoveryScore > 75 ? Theme.apexGreen : (activeRecoveryScore > 45 ? Theme.warningOrange : Theme.dangerRed))
                                        .frame(width: geo.size.width * CGFloat(Double(activeRecoveryScore) / 100.0), height: 8)
                                        .shadow(color: (activeRecoveryScore > 75 ? Theme.apexGreen : (activeRecoveryScore > 45 ? Theme.warningOrange : Theme.dangerRed)).opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                            .frame(height: 8)
                            
                            // HealthKit / Manual override controls
                            VStack(spacing: 12) {
                                Divider().background(Theme.border)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Health Data")
                                            .font(Theme.Typography.technical(10, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "heart.fill")
                                                    .foregroundColor(Theme.dangerRed)
                                                Text(liveHRV != nil ? "\(Int(liveHRV!)) ms" : "No Data")
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "bed.double.fill")
                                                    .foregroundColor(Theme.accent)
                                                Text(liveSleep != nil ? String(format: "%.1f hrs", liveSleep!) : "No Data")
                                            }
                                        }
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle(isOn: isOverriddenBinding) {
                                        Text("Override")
                                            .font(Theme.Typography.technical(11, weight: .bold))
                                            .foregroundColor(isOverriddenBinding.wrappedValue ? Theme.accent : Theme.textSecondary)
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                                }
                                
                                if isOverriddenBinding.wrappedValue {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Manual Override")
                                                .font(Theme.Typography.technical(11, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                            Spacer()
                                            Text("\(Int(manualScoreBinding.wrappedValue * 100))%")
                                                .font(Theme.Typography.technical(12, weight: .black))
                                                .foregroundColor(Theme.accent)
                                        }
                                        
                                        Slider(value: manualScoreBinding, in: 0.0...1.0, step: 0.05)
                                            .accentColor(Theme.accent)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // AI Coach Insights Panel
                        AICoachWidgetView(insight: coachInsight)
                            .padding(.horizontal)
                        
                        // Weekly Activity Split
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Weekly Activity")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                                .padding(.horizontal)
                            
                            HStack(spacing: 8) {
                                ForEach(workoutsForWeekdays(), id: \.date) { day in
                                    VStack(spacing: 8) {
                                        Text(day.dayName)
                                            .font(Theme.Typography.technical(11, weight: .bold))
                                            .foregroundColor(day.hasWorkedOut ? .white : Theme.textSecondary)
                                        
                                        Circle()
                                            .fill(day.hasWorkedOut ? .white : Color.clear)
                                            .frame(width: 4, height: 4)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(day.hasWorkedOut ? Theme.accent : Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(day.hasWorkedOut ? Theme.accent : Theme.border, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Anatomical Heatmap
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(heatmapMode == .recovery ? "Recovery Heatmap" : "Activation Heatmap")
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                
                                Spacer()
                                
                                Picker("Heatmap Mode", selection: $heatmapMode) {
                                    Text("Recovery").tag(AnatomicalBodyMap.HeatmapMode.recovery)
                                    Text("Activation").tag(AnatomicalBodyMap.HeatmapMode.activation)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            }
                            .padding(.horizontal)
                            
                            AnatomicalBodyMap(
                                mode: heatmapMode,
                                muscleState: heatmapMode == .recovery ? recoveryMap : activationMap
                            ) { muscle in
                                selectedMuscle = muscle
                                isShowingMuscleDetail = true
                            }
                            .frame(height: 350)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                            
                            // Map Legends
                            HStack(spacing: 12) {
                                if heatmapMode == .recovery {
                                    legendItem(color: Theme.dangerRed, text: "Exhausted (<2d)")
                                    legendItem(color: Theme.warningOrange, text: "Recovering (<4d)")
                                    legendItem(color: Theme.apexGreen, text: "Recovered (4d+)")
                                } else {
                                    legendItem(color: Theme.border.opacity(0.8), text: "Under-stim (<4 sets)")
                                    legendItem(color: Theme.warningOrange, text: "Optimal (4-9 sets)")
                                    legendItem(color: Theme.apexGreen, text: "Fully-stim (10+ sets)")
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        }
                        
                        // Intensity Trends Graph
                        if weeklySessionsSorted.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Intensity Trend")
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                    .padding(.horizontal)
                                
                                Chart {
                                    ForEach(weeklySessionsSorted) { session in
                                        LineMark(
                                            x: .value("Date", session.timestamp, unit: .day),
                                            y: .value("Intensity", session.totalIntensityScore)
                                        )
                                        .foregroundStyle(Theme.warningOrange)
                                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                        
                                        PointMark(
                                            x: .value("Date", session.timestamp, unit: .day),
                                            y: .value("Intensity", session.totalIntensityScore)
                                        )
                                        .foregroundStyle(Theme.warningOrange)
                                    }
                                }
                                .frame(height: 200)
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                                .padding(.horizontal)
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day)) { _ in
                                        AxisGridLine().foregroundStyle(Theme.border.opacity(0.3))
                                        AxisValueLabel(format: .dateTime.weekday()).foregroundStyle(Theme.textSecondary).font(Theme.Typography.technical(10))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisGridLine().foregroundStyle(Theme.border.opacity(0.3))
                                        AxisValueLabel().foregroundStyle(Theme.textSecondary).font(Theme.Typography.technical(10))
                                    }
                                }
                            }
                        }
                        
                        // Recent Activity List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Activity")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                                .padding(.horizontal)
                            
                            if recentSessions.isEmpty {
                                Text("No workouts logged yet. Start tracking your fitness journey.")
                                    .font(Theme.Typography.technical(14))
                                    .foregroundColor(Theme.textSecondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                            } else {
                                ForEach(recentSessions.prefix(3)) { session in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(session.name)
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(Theme.textPrimary)
                                            Text(session.timestamp.formatted(date: .abbreviated, time: .omitted))
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Text("\(session.totalIntensityScore) pts")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Theme.accent)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .onAppear {
                    loadHealthKitTelemetry()
                    if let activeFast = activeFast {
                        liveFastingElapsed = Date().timeIntervalSince(activeFast.startTime)
                    }
                }
                .onReceive(fastingTimerPublisher) { _ in
                    if let activeFast = activeFast {
                        liveFastingElapsed = Date().timeIntervalSince(activeFast.startTime)
                    }
                }
            }
            .navigationTitle("Dashboard")
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
                    Menu {
                        Button(action: {
                            isShowingFastingToolbox = true
                        }) {
                            Label("Fasting Calculator", systemImage: "clock.fill")
                        }
                        
                        Button(action: {
                            // Placeholder for future tools
                        }) {
                            Label("More Tools Coming Soon...", systemImage: "hammer.fill")
                        }
                    } label: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingFastingToolbox) {
                FastingView(isPresented: $isShowingFastingToolbox)
            }
            .sheet(isPresented: $isShowingHelp) {
                DashboardHelpView()
            }
            .sheet(isPresented: $isShowingMuscleDetail) {
                if let muscle = selectedMuscle {
                    MuscleDetailView(muscleName: muscle, recoveryState: recoveryMap)
                }
            }
        }
    }
    
    private var activeFast: FastingSession? {
        fastingSessions.first(where: { !$0.isCompleted })
    }
    
    private func fastingPhaseInfo(for hours: Double) -> (title: String, color: Color) {
        if hours < 4 { return ("Sugar Burner", Theme.accent) }
        if hours < 12 { return ("Glycogen Drain", Theme.warningOrange) }
        if hours < 16 { return ("Ketosis Ignited", Theme.dangerRed) }
        return ("Deep Autophagy", .purple)
    }
    
    private func formatFastingDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        return String(format: "%02dH %02dM", hrs, mins)
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(Theme.Typography.technical(10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

struct AICoachWidgetView: View {
    let insight: CoachInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(insight.capacityScore >= 80 ? Theme.apexGreen : (insight.capacityScore >= 50 ? Theme.warningOrange : Theme.dangerRed))
                    .frame(width: 8, height: 8)
                    .shadow(color: (insight.capacityScore >= 80 ? Theme.apexGreen : (insight.capacityScore >= 50 ? Theme.warningOrange : Theme.dangerRed)), radius: 4)
                
                Text("Coach Recommendation")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(2.0)
                
                Spacer()
                
                Text("\(insight.focusMuscle) Day")
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.15))
                    .cornerRadius(4)
            }
            
            Text(insight.coachMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineSpacing(4)
            
            Divider().background(Theme.border.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S TARGET DIRECTIVES")
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(1.0)
                
                ForEach(insight.trainingDirectives, id: \.self) { directive in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.headline)
                            .foregroundColor(Theme.accent)
                        Text(directive)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Divider().background(Theme.border.opacity(0.3))
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "bolt.shield.fill")
                    .foregroundColor(Theme.warningOrange)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRESSIVE OVERLOAD INSTRUCTION")
                        .font(Theme.Typography.technical(9, weight: .bold))
                        .foregroundColor(Theme.warningOrange)
                        .tracking(1.0)
                    
                    Text(insight.progressiveOverloadTip)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self, FastingLogEntry.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return DashboardView()
        .modelContainer(container)
}
