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
    
    @State private var isTelemetryExpanded = true
    @State private var activeChartMetric = 0 // 0 = Tonnage, 1 = Strength Ceiling (1RM)
    
    struct ChronologicalProgressPoint: Identifiable {
        let id = UUID()
        let date: Date
        let tonnage: Double
        let max1RM: Double
    }
    
    private var chronologicalPoints: [ChronologicalProgressPoint] {
        var points: [ChronologicalProgressPoint] = []
        let sorted = allSessions.sorted { $0.timestamp < $1.timestamp }
        for session in sorted {
            var sessionTonnage = 0.0
            var sessionMax1RM = 0.0
            for wex in session.exercises {
                for set in wex.sets {
                    if set.isCompleted && set.weight > 0 && set.reps > 0 {
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
                let muscle = workoutEx.loggedTargetMuscle.isEmpty ? (workoutEx.exerciseRef?.targetMuscle ?? "UNKNOWN") : workoutEx.loggedTargetMuscle
                if muscle != "UNKNOWN" {
                    if map[muscle] == nil {
                        map[muscle] = daysAgo
                    }
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
                        Text("ROUTINES").tag(0)
                        Text("BODY PARTS").tag(1)
                        Text("RECORDS").tag(2)
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
                            Text("NO HISTORY FOUND")
                                .font(Theme.Typography.technical(16, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            Text("Log your first grind to start tracking progress.")
                                .font(Theme.Typography.technical(14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        // Telemetry Stats Engine
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TELEMETRY STATS ENGINE")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        isTelemetryExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(isTelemetryExpanded ? "COLLAPSE" : "EXPAND")
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
                            .padding(.horizontal)
                            
                            if isTelemetryExpanded && chronologicalPoints.count >= 2 {
                                VStack(spacing: 12) {
                                    Picker("Telemetry Metric", selection: $activeChartMetric) {
                                        Text("VOLUME PROGRESSION").tag(0)
                                        Text("STRENGTH CEILING (1RM)").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.horizontal)
                                    
                                    Chart {
                                        ForEach(chronologicalPoints) { point in
                                            let yValue = activeChartMetric == 0 ? point.tonnage : point.max1RM
                                            LineMark(
                                                x: .value("Date", point.date, unit: .day),
                                                y: .value(activeChartMetric == 0 ? "Volume" : "1RM", yValue)
                                            )
                                            .foregroundStyle(activeChartMetric == 0 ? Theme.accent : Theme.warningOrange)
                                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                            
                                            PointMark(
                                                x: .value("Date", point.date, unit: .day),
                                                y: .value(activeChartMetric == 0 ? "Volume" : "1RM", yValue)
                                            )
                                            .foregroundStyle(activeChartMetric == 0 ? Theme.accent : Theme.warningOrange)
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
                                                Text(name.uppercased())
                                                    .font(Theme.Typography.technical(16, weight: .black))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                if let lastDate = lastSession?.timestamp {
                                                    Text("LAST: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(Theme.Typography.technical(10))
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("\(workoutSessions.count) GRINDS")
                                                    .font(Theme.Typography.technical(12, weight: .bold))
                                                    .foregroundColor(Theme.accent)
                                                
                                                Text("AVG: \(avgIntensity) PTS")
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
                            let muscles = ["Abs", "Back", "Biceps", "Calves", "Chest", "Glutes", "Hamstrings", "Quads", "Shoulders", "Triceps"]
                            List {
                                ForEach(muscles, id: \.self) { muscle in
                                    Button(action: {
                                        selectedMuscle = muscle
                                        isShowingMuscleDetail = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(muscle.uppercased())
                                                    .font(Theme.Typography.technical(16, weight: .black))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                if let days = recoveryMap[muscle] {
                                                    Text("LAST TRAINED: \(days) \(days == 1 ? "DAY" : "DAYS") AGO")
                                                        .font(Theme.Typography.technical(10))
                                                        .foregroundColor(Theme.textSecondary)
                                                } else {
                                                    Text("LAST TRAINED: NEVER")
                                                        .font(Theme.Typography.technical(10))
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            let statusInfo = getStatusInfo(for: muscle)
                                            Text(statusInfo.status.uppercased())
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
                        } else {
                            PRRecordBookView(allSessions: allSessions)
                        }
                    }
                }
            }
            .navigationTitle(selectedSegment == 0 ? "Workout Progress" : (selectedSegment == 1 ? "Muscle Progress" : "PR Record Book"))
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
        }
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [WorkoutSession.self, UserSettings.self], inMemory: true)
}
