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
