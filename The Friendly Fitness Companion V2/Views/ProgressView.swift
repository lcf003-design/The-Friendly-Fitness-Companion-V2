import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    
    @State private var isShowingHelp = false
    @State private var selectedSegment = 0 // 0 = Routines, 1 = Body Parts
    @State private var selectedMuscle: String? = nil
    @State private var isShowingMuscleDetail = false
    @State private var isShowingBiometricLogger = false
    
    @State private var isTelemetryExpanded = true
    @State private var activeChartMetric = 0 // 0 = Tonnage, 1 = Strength Ceiling (1RM)
    
    private var chronologicalPoints: [ChronologicalProgressPoint] {
        var points: [ChronologicalProgressPoint] = []
        let sorted = allSessions.sorted { $0.timestamp < $1.timestamp }
        for session in sorted {
            var sessionTonnage = 0.0
            var sessionMax1RM = 0.0
            for wex in session.exercises {
                for set in wex.sets {
                    if set.isCompleted && set.weight > 0 && set.reps > 0 && set.setType != "warmup" {
                        sessionTonnage += set.weight * Double(set.reps)
                        let repsClamped = min(10, set.reps)
                        let oneRepMax = repsClamped == 1 ? set.weight : (set.weight / (1.0278 - 0.0278 * Double(repsClamped)))
                        if oneRepMax > sessionMax1RM {
                            sessionMax1RM = oneRepMax
                        }
                    }
                }
            }
            if sessionTonnage > 0 {
                points.append(ChronologicalProgressPoint(date: session.timestamp, tonnage: sessionTonnage, max1RM: sessionMax1RM))
            }
        }
        return points
    }
    
    private var uniqueWorkoutNames: [String] {
        let names = allSessions.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        var unique: [String] = []
        for name in names {
            if !name.isEmpty && !unique.contains(name) {
                unique.append(name)
            }
        }
        return unique.sorted()
    }
    
    private func sessions(for name: String) -> [WorkoutSession] {
        allSessions.filter { $0.name.lowercased() == name.lowercased() }
    }
    
    // Calculates the number of days since a specific muscle group was trained
    private var recoveryMap: [String: Int] {
        var map: [String: Int] = [:]
        let now = Date()
        
        for session in allSessions {
            let daysAgo = Calendar.current.dateComponents([.day], from: session.timestamp, to: now).day ?? 0
            
            for workoutEx in session.exercises {
                let muscle = workoutEx.normalizedTargetMuscle
                if muscle != "UNKNOWN" {
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
        
        for session in allSessions where session.timestamp >= oneWeekAgo {
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
    
    private func getStatusInfo(for muscle: String) -> (status: String, color: Color) {
        guard let days = recoveryMap[muscle] else {
            return ("Untrained", Theme.textSecondary)
        }
        if days < 2 {
            return ("Exhausted", Theme.dangerRed)
        } else if days < 4 {
            return ("Recovering", Theme.warningOrange)
        } else {
            return ("Recovered", Theme.apexGreen)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Tracking Mode", selection: $selectedSegment) {
                        Text("Routines").tag(0)
                        Text("Body Parts").tag(1)
                        Text("Records").tag(2)
                        Text("Cardio").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    
                    if allSessions.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.textSecondary)
                            Text("No History Found")
                                .font(Theme.Typography.technical(16, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            Text("Log your first workout to start tracking progress.")
                                .font(Theme.Typography.technical(14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        // Telemetry Stats Engine
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Telemetry Dashboard")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Button(action: {
                                        HapticManager.shared.playSelection()
                                        isShowingBiometricLogger = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("Log Weight")
                                                .font(Theme.Typography.technical(8, weight: .black))
                                        }
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.accent)
                                        .cornerRadius(4)
                                    }
                                    
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            isTelemetryExpanded.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(isTelemetryExpanded ? "Collapse" : "Expand")
                                                .font(Theme.Typography.technical(8, weight: .black))
                                            Image(systemName: isTelemetryExpanded ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 8))
                                        }
                                        .foregroundColor(Theme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.accent.opacity(0.1))
                                        .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            if isTelemetryExpanded && chronologicalPoints.count >= 2 {
                                VStack(spacing: 12) {
                                    Picker("Telemetry Metric", selection: $activeChartMetric) {
                                        Text("Volume Progression").tag(0)
                                        Text("Strength Ceiling (1RM)").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.horizontal)
                                    
                                    TelemetryChartView(chronologicalPoints: chronologicalPoints, activeChartMetric: activeChartMetric)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if selectedSegment == 0 {
                            List {
                                ForEach(uniqueWorkoutNames, id: \.self) { name in
                                    let workoutSessions = sessions(for: name)
                                    let lastSession = workoutSessions.first // allSessions is sorted order: .reverse
                                    let avgIntensity = workoutSessions.map { $0.totalIntensityScore }.reduce(0, +) / workoutSessions.count
                                    
                                    NavigationLink(destination: WorkoutProgressDetailView(workoutName: name)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(name)
                                                    .font(Theme.Typography.technical(16, weight: .black))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                if let lastDate = lastSession?.timestamp {
                                                    Text("Last: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(Theme.Typography.technical(10))
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("\(workoutSessions.count) Workouts")
                                                    .font(Theme.Typography.technical(12, weight: .bold))
                                                    .foregroundColor(Theme.accent)
                                                
                                                Text("Avg: \(avgIntensity) pts")
                                                    .font(Theme.Typography.technical(10, weight: .bold))
                                                    .foregroundColor(Theme.warningOrange)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .listRowBackground(Theme.surface)
                                }
                            }
                            .scrollContentBackground(.hidden)
                        } else if selectedSegment == 1 {
                            let muscles = MuscleGroup.all
                            List {
                                ForEach(muscles, id: \.self) { muscle in
                                    Button(action: {
                                        selectedMuscle = muscle
                                        isShowingMuscleDetail = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(muscle)
                                                    .font(Theme.Typography.technical(16, weight: .black))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                let days = recoveryMap[muscle]
                                                let daysString = days != nil ? "\(days!) \(days! == 1 ? "day" : "days") ago" : "Never"
                                                let sets = activationMap[muscle, default: 0]
                                                Text("Last: \(daysString) • Weekly: \(sets) \(sets == 1 ? "set" : "sets")")
                                                    .font(Theme.Typography.technical(10))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            let statusInfo = getStatusInfo(for: muscle)
                                            Text(statusInfo.status)
                                                .font(Theme.Typography.technical(10, weight: .bold))
                                                .foregroundColor(statusInfo.color)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(statusInfo.color.opacity(0.15))
                                                .cornerRadius(4)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(statusInfo.color.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .listRowBackground(Theme.surface)
                                }
                            }
                            .scrollContentBackground(.hidden)
                        } else if selectedSegment == 2 {
                            PRRecordBookView(allSessions: allSessions)
                        } else {
                            CardioProgressView(allSessions: allSessions, userSettings: userSettings.first)
                        }
                    }
                }
            }
            .navigationTitle(selectedSegment == 0 ? "Workout Progress" : (selectedSegment == 1 ? "Muscle Progress" : (selectedSegment == 2 ? "PR Record Book" : "Cardio Progress")))
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
            }
            .sheet(isPresented: $isShowingHelp) {
                ProgressHelpView()
            }
            .sheet(isPresented: $isShowingMuscleDetail) {
                if let muscle = selectedMuscle {
                    MuscleDetailView(muscleName: muscle, recoveryState: recoveryMap)
                }
            }
            .sheet(isPresented: $isShowingBiometricLogger) {
                QuickBiometricLoggerView()
            }
        }
    }
}

struct ChronologicalProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let tonnage: Double
    let max1RM: Double
}

struct TelemetryChartView: View {
    let chronologicalPoints: [ChronologicalProgressPoint]
    let activeChartMetric: Int
    
    var body: some View {
        if activeChartMetric == 0 {
            Chart {
                ForEach(chronologicalPoints) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Volume", point.tonnage)
                    )
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Volume", point.tonnage)
                    )
                    .foregroundStyle(Theme.accent)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: chronologicalPoints.count > 5 ? chronologicalPoints.count / 3 : 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.border.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Theme.textSecondary)
                        .font(Theme.Typography.technical(8))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.border.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                        .font(Theme.Typography.technical(8))
                }
            }
            .frame(height: 140)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal)
        } else {
            Chart {
                ForEach(chronologicalPoints) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("1RM", point.max1RM)
                    )
                    .foregroundStyle(Theme.warningOrange)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("1RM", point.max1RM)
                    )
                    .foregroundStyle(Theme.warningOrange)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: chronologicalPoints.count > 5 ? chronologicalPoints.count / 3 : 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.border.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Theme.textSecondary)
                        .font(Theme.Typography.technical(8))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.border.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                        .font(Theme.Typography.technical(8))
                }
            }
            .frame(height: 140)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [WorkoutSession.self, UserSettings.self], inMemory: true)
}

struct CardioProgressView: View {
    let allSessions: [WorkoutSession]
    let userSettings: UserSettings?
    
    private var distUnit: String {
        userSettings?.weightUnit == "kg" ? "km" : "mi"
    }
    
    private var completedCardioSets: [(sessionName: String, date: Date, exerciseName: String, set: ExerciseSet)] {
        var result: [(sessionName: String, date: Date, exerciseName: String, set: ExerciseSet)] = []
        for session in allSessions {
            for wex in session.exercises {
                if wex.exerciseRef?.targetMuscle == "Cardio" || wex.loggedName.lowercased().contains("cardio") {
                    for set in wex.sets {
                        if set.isCompleted {
                            let exName = wex.loggedName.isEmpty ? (wex.exerciseRef?.name ?? "Cardio Exercise") : wex.loggedName
                            result.append((sessionName: session.name, date: session.timestamp, exerciseName: exName, set: set))
                        }
                    }
                }
            }
        }
        return result.sorted { $0.date > $1.date }
    }
    
    private var lifetimeDistance: Double {
        completedCardioSets.reduce(0.0) { $0 + $1.set.cardioDistance }
    }
    
    private var lifetimeMinutes: Double {
        let totalSecs = completedCardioSets.reduce(0) { $0 + $1.set.cardioDurationSeconds }
        return Double(totalSecs) / 60.0
    }
    
    private var lifetimeCalories: Int {
        completedCardioSets.reduce(0) { $0 + $1.set.cardioCalories }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Stats Grid
            HStack(spacing: 12) {
                // Distance Card
                VStack(spacing: 6) {
                    Text(String(format: "%.2f", lifetimeDistance))
                        .font(Theme.Typography.technical(22, weight: .black))
                        .foregroundColor(Theme.accent)
                    
                    Text("Total \(distUnit)")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                
                // Time Card
                VStack(spacing: 6) {
                    Text(String(format: "%.1f", lifetimeMinutes))
                        .font(Theme.Typography.technical(22, weight: .black))
                        .foregroundColor(Theme.warningOrange)
                    
                    Text("Total Mins")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                
                // Calories Card
                VStack(spacing: 6) {
                    Text("\(lifetimeCalories)")
                        .font(Theme.Typography.technical(22, weight: .black))
                        .foregroundColor(.purple)
                    
                    Text("Kcal Burned")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .padding(.horizontal)
            
            // Ledger Title
            Text("Chronological Cardio Ledger")
                .font(Theme.Typography.technical(11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
            
            if completedCardioSets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.largeTitle)
                        .foregroundColor(Theme.border)
                    Text("No Cardio Completed Yet")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(0..<completedCardioSets.count, id: \.self) { idx in
                        let item = completedCardioSets[idx]
                        let mins = item.set.cardioDurationSeconds / 60
                        let secs = item.set.cardioDurationSeconds % 60
                        let timeString = String(format: "%02d:%02d", mins, secs)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.exerciseName)
                                    .font(Theme.Typography.technical(14, weight: .black))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("\(item.sessionName) • \(item.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(item.set.cardioDistance, specifier: "%.2f") \(distUnit)")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                
                                Text("\(timeString) | \(item.set.cardioCalories) kcal")
                                    .font(Theme.Typography.technical(10))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Theme.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
