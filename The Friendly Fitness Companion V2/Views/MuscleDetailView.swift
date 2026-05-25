import SwiftUI
import SwiftData
import Charts

struct MuscleDetailView: View {
    let muscleName: String
    let recoveryState: [String: Int]
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var recentSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    
    @Environment(\.dismiss) private var dismiss
    
    private var unit: String {
        userSettings.first?.weightUnit.uppercased() ?? "LB"
    }
    
    private var daysSinceTrained: Int? {
        recoveryState[muscleName]
    }
    
    private var recoveryPercentage: Double {
        guard let days = daysSinceTrained else { return 1.0 }
        if days <= 0 { return 0.1 }
        if days == 1 { return 0.3 }
        if days == 2 { return 0.6 }
        if days == 3 { return 0.8 }
        return 1.0
    }
    
    private var recoveryStatus: String {
        guard let days = daysSinceTrained else { return "Fully Recovered (Untrained)" }
        if days < 2 { return "Exhausted" }
        if days < 4 { return "Recovering" }
        return "Fully Recovered"
    }
    
    private var statusColor: Color {
        guard let days = daysSinceTrained else { return Theme.apexGreen }
        if days < 2 { return Theme.dangerRed }
        if days < 4 { return Theme.warningOrange }
        return Theme.apexGreen
    }
    
    // Muscle-specific metrics
    private var lifetimeVolume: Double {
        var total = 0.0
        for session in recentSessions {
            for wex in session.exercises {
                let m = wex.normalizedTargetMuscle
                if m.lowercased() == muscleName.lowercased() {
                    total += wex.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                }
            }
        }
        return total
    }
    
    private var frequency30Days: Int {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var count = 0
        for session in recentSessions {
            if session.timestamp >= thirtyDaysAgo {
                let hasMuscle = session.exercises.contains { wex in
                    let m = wex.normalizedTargetMuscle
                    return m.lowercased() == muscleName.lowercased()
                }
                if hasMuscle {
                    count += 1
                }
            }
        }
        return count
    }
    
    private var allTimeBest1RM: Double {
        var best = 0.0
        for session in recentSessions {
            for wex in session.exercises {
                let m = wex.normalizedTargetMuscle
                if m.lowercased() == muscleName.lowercased() {
                    for set in wex.sets {
                        if set.isCompleted && set.weight > 0 && set.reps > 0 {
                            let est = set.weight * (1.0 + (Double(set.reps) / 30.0))
                            if est > best {
                                best = est
                            }
                        }
                    }
                }
            }
        }
        return best
    }
    
    struct MuscleVolumePoint: Identifiable {
        let id = UUID()
        let date: Date
        let volume: Double
    }
    
    private var volumeTrendData: [MuscleVolumePoint] {
        var points: [MuscleVolumePoint] = []
        for session in recentSessions.reversed() { // old to new
            var sessionVolume = 0.0
            for wex in session.exercises {
                let m = wex.normalizedTargetMuscle
                if m.lowercased() == muscleName.lowercased() {
                    sessionVolume += wex.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                }
            }
            if sessionVolume > 0 {
                points.append(MuscleVolumePoint(date: session.timestamp, volume: sessionVolume))
            }
        }
        return points
    }
    
    private var recentExercisesForMuscle: [(date: Date, name: String, volume: Double)] {
        var exercises: [(Date, String, Double)] = []
        for session in recentSessions {
            for wex in session.exercises {
                let m = wex.normalizedTargetMuscle
                if m.lowercased() == muscleName.lowercased() {
                    let volume = wex.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                    exercises.append((session.timestamp, wex.loggedName.isEmpty ? (wex.exerciseRef?.name ?? "Unknown Exercise") : wex.loggedName, volume))
                }
            }
        }
        return exercises
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        
                        // 1. Recovery Wheel & Status
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Theme.border, lineWidth: 10)
                                    .frame(width: 130, height: 130)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(recoveryPercentage))
                                    .stroke(
                                        statusColor,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 130, height: 130)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: statusColor.opacity(0.4), radius: 6)
                                
                                VStack(spacing: 4) {
                                    Text("\(Int(recoveryPercentage * 100))%")
                                        .font(Theme.Typography.technical(28, weight: .black))
                                        .foregroundColor(.white)
                                    Text("Rested")
                                        .font(Theme.Typography.technical(9, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                        .tracking(1)
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(recoveryStatus)
                                    .font(Theme.Typography.technical(16, weight: .black))
                                    .foregroundColor(statusColor)
                                    .tracking(1.5)
                                
                                if let days = daysSinceTrained {
                                    Text("Last trained \(days) days ago")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                } else {
                                    Text("No historical sessions logged")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // 2. Performance Matrix Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Muscle Statistics")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                statCard(title: "30-Day Frequency", value: "\(frequency30Days) workouts", icon: "calendar", color: Theme.accent)
                                statCard(title: "Lifetime Tonnage", value: String(format: "%.0f %@", lifetimeVolume, unit.lowercased()), icon: "scalemass.fill", color: Theme.warningOrange)
                                statCard(title: "Best Estimated 1RM", value: allTimeBest1RM > 0 ? String(format: "%.1f %@", allTimeBest1RM, unit.lowercased()) : "---", icon: "crown.fill", color: Theme.apexGreen)
                                statCard(title: "Recovery Time", value: daysSinceTrained != nil ? "\(daysSinceTrained!) days" : "Fresh", icon: "timer", color: Theme.textSecondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. Tonnage Progression Chart
                        if volumeTrendData.count >= 2 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Volume Progression")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
                                    .padding(.horizontal)
                                
                                Chart {
                                    ForEach(volumeTrendData) { point in
                                        LineMark(
                                            x: .value("Date", point.date, unit: .day),
                                            y: .value("Volume", point.volume)
                                        )
                                        .foregroundStyle(Theme.accent)
                                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                        
                                        PointMark(
                                            x: .value("Date", point.date, unit: .day),
                                            y: .value("Volume", point.volume)
                                        )
                                        .foregroundStyle(Theme.accent)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: volumeTrendData.count > 5 ? volumeTrendData.count / 3 : 1)) { _ in
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
                                .frame(height: 180)
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // 4. Recent Exercises Ledger
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Exercises Ledger")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            if recentExercisesForMuscle.isEmpty {
                                Text("No recent history logged.")
                                    .font(Theme.Typography.technical(14))
                                    .foregroundColor(Theme.textSecondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(recentExercisesForMuscle.prefix(6), id: \.date) { ex in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(ex.name)
                                                    .font(.headline)
                                                    .foregroundColor(Theme.textPrimary)
                                                Text(ex.date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                            Spacer()
                                            Text("\(Int(ex.volume)) \(unit.lowercased())")
                                                .font(Theme.Typography.technical(14, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                        }
                                        .padding()
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(muscleName.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
    
    // MARK: - Helper Subview
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.technical(8, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(0.5)
                Text(value)
                    .font(Theme.Typography.technical(12, weight: .black))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
        )
    }
}
