import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var recentSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    @State private var isShowingFastingToolbox = false
    @State private var isShowingHelp = false
    @State private var selectedMuscle: String? = nil
    @State private var isShowingMuscleDetail = false
    
    // HealthKit metrics states
    @State private var liveHRV: Double? = nil
    @State private var liveSleep: Double? = nil
    @State private var isHealthKitAuthorized = false
    
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
                let muscle = workoutEx.loggedTargetMuscle.isEmpty ? (workoutEx.exerciseRef?.targetMuscle ?? "UNKNOWN") : workoutEx.loggedTargetMuscle
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
                let muscle = wex.loggedTargetMuscle.isEmpty ? (wex.exerciseRef?.targetMuscle ?? "UNKNOWN") : wex.loggedTargetMuscle
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
        let muscles = ["Abs", "Back", "Biceps", "Calves", "Chest", "Glutes", "Hamstrings", "Quads", "Shoulders", "Triceps"]
        let recMap = recoveryMap
        var totalPoints = 0
        
        for muscle in muscles {
            if let days = recMap[muscle] {
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
                        
                        // Recovery Energy Bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("SYSTEM RECOVERY LEVEL")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                Spacer()
                                Text("\(activeRecoveryScore)%")
                                    .font(Theme.Typography.technical(12, weight: .black))
                                    .foregroundColor(activeRecoveryScore > 75 ? Theme.apexGreen : (activeRecoveryScore > 45 ? Theme.warningOrange : Theme.dangerRed))
                            }
                            
                            // Visual bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Theme.surface)
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(activeRecoveryScore > 75 ? Theme.apexGreen : (activeRecoveryScore > 45 ? Theme.warningOrange : Theme.dangerRed))
                                        .frame(width: geo.size.width * CGFloat(Double(activeRecoveryScore) / 100.0), height: 8)
                                        .shadow(color: (activeRecoveryScore > 75 ? Theme.apexGreen : (activeRecoveryScore > 45 ? Theme.warningOrange : Theme.dangerRed)).opacity(0.5), radius: 3, x: 0, y: 0)
                                }
                            }
                            .frame(height: 8)
                            
                            // HealthKit / Manual override controls
                            VStack(spacing: 12) {
                                Divider().background(Theme.border.opacity(0.2))
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("HEALTHKIT TELEMETRY")
                                            .font(Theme.Typography.technical(9, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "heart.text.square.fill")
                                                    .foregroundColor(Theme.dangerRed)
                                                Text(liveHRV != nil ? "\(Int(liveHRV!)) ms" : "NO DATA")
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "bed.double.fill")
                                                    .foregroundColor(Theme.accent)
                                                Text(liveSleep != nil ? String(format: "%.1f hrs", liveSleep!) : "NO DATA")
                                            }
                                        }
                                        .font(Theme.Typography.technical(11, weight: .bold))
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle(isOn: isOverriddenBinding) {
                                        Text("OVERRIDE")
                                            .font(Theme.Typography.technical(10, weight: .black))
                                            .foregroundColor(isOverriddenBinding.wrappedValue ? Theme.accent : Theme.textSecondary)
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                                    .labelsHidden()
                                }
                                
                                if isOverriddenBinding.wrappedValue {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("MANUAL READINESS OVERRIDE:")
                                                .font(Theme.Typography.technical(9, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                            Spacer()
                                            Text("\(Int(manualScoreBinding.wrappedValue * 100))%")
                                                .font(Theme.Typography.technical(11, weight: .black))
                                                .foregroundColor(Theme.accent)
                                        }
                                        
                                        Slider(value: manualScoreBinding, in: 0.0...1.0, step: 0.05)
                                            .accentColor(Theme.accent)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Theme.surface.opacity(0.5))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // AI Coach Insights Panel
                        AICoachWidgetView(insight: coachInsight)
                            .padding(.horizontal)
                        
                        // Weekly Split Matrix
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WEEKLY SPLIT MATRIX")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            HStack(spacing: 8) {
                                ForEach(workoutsForWeekdays(), id: \.date) { day in
                                    VStack(spacing: 6) {
                                        Text(day.dayName)
                                            .font(Theme.Typography.technical(10, weight: .bold))
                                            .foregroundColor(day.hasWorkedOut ? .black : Theme.textSecondary)
                                        
                                        Circle()
                                            .fill(day.hasWorkedOut ? Theme.accent : Color.clear)
                                            .frame(width: 6, height: 6)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(day.hasWorkedOut ? Theme.accent : Theme.surface)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(day.hasWorkedOut ? Theme.accent : Theme.border.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Anatomical Heatmap
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RECOVERY HEATMAP")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            AnatomicalBodyMap(muscleRecoveryState: recoveryMap) { muscle in
                                selectedMuscle = muscle
                                isShowingMuscleDetail = true
                            }
                            .frame(height: 350)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Volume Analytics Chart Removed
                        
                        // Intensity Trends Graph
                        if weeklySessionsSorted.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("INTENSITY TREND")
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
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
                            Text("RECENT GRIND")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            if recentSessions.isEmpty {
                                Text("No workouts logged yet. Time to bleed.")
                                    .font(Theme.Typography.technical(16))
                                    .foregroundColor(Theme.textSecondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            } else {
                                ForEach(recentSessions.prefix(3)) { session in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(session.name)
                                                .font(.headline)
                                                .foregroundColor(Theme.textPrimary)
                                            Text(session.timestamp.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Text("\(session.totalIntensityScore) pts")
                                            .font(.subheadline.bold())
                                            .foregroundColor(Theme.accent)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .onAppear {
                    loadHealthKitTelemetry()
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
                
                Text("COACH CO-PILOT")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(2.0)
                
                Spacer()
                
                Text(insight.focusMuscle.uppercased() + " DAY")
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
                Text(title.uppercased())
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
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return DashboardView()
        .modelContainer(container)
}
