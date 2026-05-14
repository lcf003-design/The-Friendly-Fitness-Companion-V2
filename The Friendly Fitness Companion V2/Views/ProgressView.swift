import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \WorkoutSession.timestamp) private var allSessions: [WorkoutSession] // Oldest to newest for plotting
    @Query private var userSettings: [UserSettings]
    
    @State private var selectedExercise: Exercise?
    @State private var selectedDate: Date?
    @State private var isShowingCalculator = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if allExercises.isEmpty {
                        Text("No exercises in the database.")
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        // Exercise Picker
                        HStack {
                            Text("TARGET EXERCISE")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1)
                            Spacer()
                            Picker("Exercise", selection: $selectedExercise) {
                                ForEach(allExercises) { ex in
                                    Text(ex.name).tag(ex as Exercise?)
                                }
                            }
                            .tint(Theme.accent)
                        }
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onAppear {
                            if selectedExercise == nil {
                                selectedExercise = allExercises.first
                            }
                        }
                        
                        // Analytics Display
                        if let exercise = selectedExercise {
                            let dataPoints = generateChartData(for: exercise)
                            
                            if dataPoints.isEmpty {
                                VStack(spacing: 20) {
                                    Spacer()
                                    Image(systemName: "chart.xyaxis.line")
                                        .font(.system(size: 50))
                                        .foregroundColor(Theme.border)
                                    Text("No data logged for \(exercise.name) yet.")
                                        .font(Theme.Typography.technical(16))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                }
                            } else {
                                // Stats Summary
                                HStack(spacing: 16) {
                                    StatCard(
                                        title: "Current 1RM",
                                        value: "\(Int(dataPoints.last?.oneRepMax ?? 0))",
                                        icon: "rosette",
                                        color: Theme.warningOrange
                                    )
                                    StatCard(
                                        title: "Sessions",
                                        value: "\(dataPoints.count)",
                                        icon: "flame.fill",
                                        color: Theme.accent
                                    )
                                }
                                .padding(.horizontal)
                                
                                // Chart
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ESTIMATED 1RM TRAJECTORY")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                        .tracking(1)
                                        .padding(.horizontal)
                                    
                                    Chart(dataPoints) { point in
                                        LineMark(
                                            x: .value("Date", point.date),
                                            y: .value("1RM (\(userSettings.first?.weightUnit ?? "lb"))", point.oneRepMax)
                                        )
                                        .interpolationMethod(.monotone)
                                        .foregroundStyle(Theme.accent.gradient)
                                        
                                        PointMark(
                                            x: .value("Date", point.date),
                                            y: .value("1RM (\(userSettings.first?.weightUnit ?? "lb"))", point.oneRepMax)
                                        )
                                        .foregroundStyle(Theme.warningOrange)
                                        .symbolSize(60)
                                        
                                        AreaMark(
                                            x: .value("Date", point.date),
                                            yStart: .value("Base", 0),
                                            yEnd: .value("1RM (\(userSettings.first?.weightUnit ?? "lb"))", point.oneRepMax)
                                        )
                                        .interpolationMethod(.monotone)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Theme.accent.opacity(0.3), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        
                                        // Interactive Tooltip Overlay
                                        if let selectedDate = selectedDate,
                                           let closestPoint = findClosestDataPoint(to: selectedDate, in: dataPoints) {
                                            RuleMark(x: .value("Selected", closestPoint.date))
                                                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                                                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                                    VStack(spacing: 4) {
                                                        Text("\(Int(closestPoint.oneRepMax)) \(userSettings.first?.weightUnit ?? "lb")")
                                                            .font(Theme.Typography.technical(16, weight: .bold))
                                                            .foregroundColor(Theme.warningOrange)
                                                        Text(closestPoint.date.formatted(.dateTime.month().day()))
                                                            .font(.caption2)
                                                            .foregroundColor(Theme.textPrimary)
                                                    }
                                                    .padding(8)
                                                    .background(Theme.midnightMatte)
                                                    .cornerRadius(8)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Theme.border, lineWidth: 1)
                                                    )
                                                    .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 5)
                                                }
                                        }
                                    }
                                    .chartXSelection(value: $selectedDate)
                                    .chartScrollableAxes(.horizontal)
                                    .chartXVisibleDomain(length: 3600 * 24 * 14) // Force 14-day viewport
                                    .chartXScale(range: .plotDimension(padding: 40)) // Prevents edge tooltips from clipping
                                    .chartYScale(domain: .automatic(includesZero: false))
                                    .chartXAxis {
                                        AxisMarks(values: .automatic) { value in
                                            AxisGridLine().foregroundStyle(Theme.border.opacity(0.5))
                                            AxisValueLabel(format: .dateTime.month().day())
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { value in
                                            AxisGridLine().foregroundStyle(Theme.border.opacity(0.5))
                                            AxisValueLabel()
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    .frame(height: 300)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingCalculator = true
                    }) {
                        Image(systemName: "function")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $isShowingCalculator) {
                OneRepMaxCalculatorView()
            }
        }
    }
    
    // Helper to find nearest data point to the user's tap
    private func findClosestDataPoint(to date: Date, in points: [ChartDataPoint]) -> ChartDataPoint? {
        points.min(by: { abs($0.date.distance(to: date)) < abs($1.date.distance(to: date)) })
    }
    
    // Core Epley 1RM Calculation Logic
    private func generateChartData(for targetExercise: Exercise) -> [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        
        for session in allSessions {
            // Find if this session included the target exercise by tracking the frozen string
            let matchingWorkoutExercises = session.exercises.filter { wEx in
                let rawName = wEx.loggedName.isEmpty ? (wEx.exerciseRef?.name ?? "") : wEx.loggedName
                return rawName.localizedCaseInsensitiveCompare(targetExercise.name) == .orderedSame
            }
            
            var best1RMForSession = 0.0
            
            for wEx in matchingWorkoutExercises {
                for set in wEx.sets {
                    // Epley Formula: 1RM = Weight * (1 + (Reps / 30))
                    let repCount = Double(set.reps)
                    let weight = set.weight
                    let estimated1RM = weight * (1.0 + (repCount / 30.0))
                    
                    if estimated1RM > best1RMForSession {
                        best1RMForSession = estimated1RM
                    }
                }
            }
            
            if best1RMForSession > 0 {
                points.append(ChartDataPoint(date: session.timestamp, oneRepMax: best1RMForSession))
            }
        }
        
        return points
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let oneRepMax: Double
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let dummyEx = Exercise(name: "Bench Press", targetMuscle: "Chest")
    container.mainContext.insert(dummyEx)
    
    // Create dummy history
    let day1 = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
    let day2 = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    let day3 = Date()
    
    let s1 = WorkoutSession(name: "Grind", timestamp: day1, exercises: [])
    let wex1 = WorkoutExercise(exerciseRef: dummyEx, sets: [ExerciseSet(weight: 200, reps: 5)])
    s1.exercises.append(wex1)
    
    let s2 = WorkoutSession(name: "Grind", timestamp: day2, exercises: [])
    let wex2 = WorkoutExercise(exerciseRef: dummyEx, sets: [ExerciseSet(weight: 210, reps: 5)])
    s2.exercises.append(wex2)
    
    let s3 = WorkoutSession(name: "Grind", timestamp: day3, exercises: [])
    let wex3 = WorkoutExercise(exerciseRef: dummyEx, sets: [ExerciseSet(weight: 225, reps: 4)])
    s3.exercises.append(wex3)
    
    container.mainContext.insert(s1)
    container.mainContext.insert(s2)
    container.mainContext.insert(s3)
    
    return ProgressView()
        .modelContainer(container)
}
