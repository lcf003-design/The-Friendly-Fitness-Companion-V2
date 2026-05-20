import SwiftUI
import SwiftData

struct MuscleDetailView: View {
    let muscleName: String
    let recoveryState: [String: Int]
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var recentSessions: [WorkoutSession]
    
    @Environment(\.dismiss) private var dismiss
    
    private var daysSinceTrained: Int? {
        recoveryState[muscleName]
    }
    
    private var recoveryStatus: String {
        guard let days = daysSinceTrained else { return "FULLY RECOVERED (UNTRAINED)" }
        if days < 2 { return "EXHAUSTED" }
        if days < 4 { return "RECOVERING" }
        return "FULLY RECOVERED"
    }
    
    private var statusColor: Color {
        guard let days = daysSinceTrained else { return Theme.apexGreen }
        if days < 2 { return Theme.dangerRed }
        if days < 4 { return Theme.warningOrange }
        return Theme.apexGreen
    }
    
    private var recentExercisesForMuscle: [(date: Date, name: String, volume: Double)] {
        var exercises: [(Date, String, Double)] = []
        for session in recentSessions {
            for wex in session.exercises {
                let m = wex.loggedTargetMuscle.isEmpty ? (wex.exerciseRef?.targetMuscle ?? "UNKNOWN") : wex.loggedTargetMuscle
                if m == muscleName {
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
                    VStack(alignment: .leading, spacing: 24) {
                        // Status Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CURRENT STATUS")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            
                            HStack {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 16, height: 16)
                                    .shadow(color: statusColor.opacity(0.6), radius: 8, x: 0, y: 0)
                                
                                Text(recoveryStatus)
                                    .font(Theme.Typography.technical(20, weight: .black))
                                    .foregroundColor(.white)
                            }
                            
                            if let days = daysSinceTrained {
                                Text("Last trained \(days) days ago.")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        
                        // Recent Exercises
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RECENT EXERCISES")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            
                            if recentExercisesForMuscle.isEmpty {
                                Text("No recent history for \(muscleName).")
                                    .foregroundColor(Theme.textSecondary)
                                    .padding()
                            } else {
                                ForEach(recentExercisesForMuscle.prefix(5), id: \.date) { ex in
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
                                        Text("\(Int(ex.volume)) lb")
                                            .font(Theme.Typography.technical(14, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(muscleName.uppercased())
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
}
