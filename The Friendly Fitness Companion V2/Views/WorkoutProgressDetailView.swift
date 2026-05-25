import SwiftUI
import SwiftData
import Charts

struct WorkoutProgressDetailView: View {
    let workoutName: String
    @Query(sort: \WorkoutSession.timestamp, order: .forward) private var allSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMetric = 0 // 0 = Tonnage, 1 = Intensity Score
    @State private var selectedSessionForDrillDown: WorkoutSession? = nil
    
    private var unit: String {
        userSettings.first?.weightUnit.uppercased() ?? "LB"
    }
    
    // Sessions matching this workout name
    private var filteredSessions: [WorkoutSession] {
        allSessions.filter { $0.name.lowercased() == workoutName.lowercased() }
    }
    
    private var stats: WorkoutStats {
        let sessions = filteredSessions
        guard !sessions.isEmpty else { return WorkoutStats(totalWorkouts: 0, avgTonnage: 0, maxTonnage: 0, avgIntensity: 0, maxIntensity: 0) }
        
        let tonnages = sessions.map { calculateTonnage(for: $0) }
        let intensities = sessions.map { Double($0.totalIntensityScore) }
        
        return WorkoutStats(
            totalWorkouts: sessions.count,
            avgTonnage: tonnages.reduce(0, +) / Double(sessions.count),
            maxTonnage: tonnages.max() ?? 0.0,
            avgIntensity: Int(intensities.reduce(0, +) / Double(sessions.count)),
            maxIntensity: Int(intensities.max() ?? 0.0)
        )
    }
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Stats Matrix
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tactical Profile")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(2)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            statCard(title: "Total Workouts", value: "\(stats.totalWorkouts)", icon: "flame.fill", color: Theme.warningOrange)
                            statCard(title: "Avg Intensity", value: "\(stats.avgIntensity) Pts", icon: "bolt.fill", color: Theme.accent)
                            statCard(title: "Max Volume", value: String(format: "%.0f %@", stats.maxTonnage, unit), icon: "scalemass.fill", color: Theme.warningOrange)
                            statCard(title: "Avg Volume", value: String(format: "%.0f %@", stats.avgTonnage, unit), icon: "chart.bar.fill", color: Theme.apexGreen)
                        }
                        .padding(.horizontal)
                    }
                    
                    // 2. Trend Analyzer Chart
                    if filteredSessions.count >= 2 {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Trend Analysis")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
                                
                                Spacer()
                                
                                Picker("Metric", selection: $selectedMetric) {
                                    Text("Volume").tag(0)
                                    Text("Intensity").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 160)
                            }
                            .padding(.horizontal)
                            
                            VStack {
                                Chart {
                                    ForEach(filteredSessions) { session in
                                        let yValue = selectedMetric == 0 ? calculateTonnage(for: session) : Double(session.totalIntensityScore)
                                        
                                        LineMark(
                                            x: .value("Date", session.timestamp, unit: .day),
                                            y: .value(selectedMetric == 0 ? "Volume" : "Intensity", yValue)
                                        )
                                        .foregroundStyle(selectedMetric == 0 ? Theme.accent : Theme.warningOrange)
                                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                        
                                        PointMark(
                                            x: .value("Date", session.timestamp, unit: .day),
                                            y: .value(selectedMetric == 0 ? "Volume" : "Intensity", yValue)
                                        )
                                        .foregroundStyle(selectedMetric == 0 ? Theme.accent : Theme.warningOrange)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: filteredSessions.count > 5 ? filteredSessions.count / 3 : 1)) { _ in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.border.opacity(0.3))
                                        AxisTick().foregroundStyle(Theme.border)
                                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.border.opacity(0.3))
                                        AxisValueLabel()
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .frame(height: 200)
                                .padding()
                            }
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // 3. Historical Session Ledger
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Historical Ledger")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(2)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(filteredSessions.reversed()) { session in
                                Button(action: {
                                    selectedSessionForDrillDown = session
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                                                .font(.headline)
                                                .foregroundColor(Theme.textPrimary)
                                            Text("\(session.exercises.count) Exercises • RPE \(session.rpe)")
                                                .font(Theme.Typography.technical(11))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(String(format: "%.0f %@", calculateTonnage(for: session), unit))
                                                .font(Theme.Typography.technical(14, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                            Text("\(session.totalIntensityScore) Pts")
                                                .font(Theme.Typography.technical(10, weight: .black))
                                                .foregroundColor(Theme.warningOrange)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.leading, 4)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedSessionForDrillDown) { session in
            WorkoutLoggerView(session: session, isNewSession: false)
        }
    }
    
    // MARK: - Helper Subviews
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.technical(9, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(1)
                Text(value)
                    .font(Theme.Typography.technical(14, weight: .black))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func calculateTonnage(for session: WorkoutSession) -> Double {
        var total = 0.0
        for exercise in session.exercises {
            for set in exercise.sets {
                total += set.weight * Double(set.reps)
            }
        }
        return total
    }
    
    struct WorkoutStats {
        let totalWorkouts: Int
        let avgTonnage: Double
        let maxTonnage: Double
        let avgIntensity: Int
        let maxIntensity: Int
    }
}
