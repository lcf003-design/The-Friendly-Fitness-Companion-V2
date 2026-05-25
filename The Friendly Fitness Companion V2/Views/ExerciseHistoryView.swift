import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    let exercise: Exercise
    
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    
    var unit: String {
        userSettings.first?.weightUnit.uppercased() ?? "LB"
    }
    
    // Filter out only the sessions that contain this specific exercise
    var performances: [(session: WorkoutSession, wEx: WorkoutExercise)] {
        var results: [(WorkoutSession, WorkoutExercise)] = []
        for session in allSessions {
            for ex in session.exercises {
                if ex.exerciseRef?.id == exercise.id || ex.loggedName == exercise.name {
                    results.append((session, ex))
                }
            }
        }
        return results
    }
    
    var allTimeMax: Double {
        let allSets = performances.flatMap { $0.wEx.sets }
        return allSets.map { $0.weight }.max() ?? 0.0
    }
    
    var estimated1RM: Double {
        let allSets = performances.flatMap { $0.wEx.sets }.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
        return allSets.map { $0.weight * (1.0 + (Double($0.reps) / 30.0)) }.max() ?? 0.0
    }
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // PR Banner
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("All-Time Max")
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Text(allTimeMax > 0 ? "\(allTimeMax, specifier: "%.1f")" : "---")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text(unit)
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Est 1-Rep Max")
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Text(estimated1RM > 0 ? "\(estimated1RM, specifier: "%.1f")" : "---")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(Theme.warningOrange)
                            Text(unit)
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.warningOrange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // History List
                if performances.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.border)
                        Text("No history recorded.")
                            .font(Theme.Typography.technical(16))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(performances, id: \.session.id) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.session.timestamp.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Text(item.session.name)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                ForEach(Array(item.wEx.sets.enumerated()), id: \.element.id) { setIndex, set in
                                    HStack {
                                        Text("Set \(setIndex + 1)")
                                            .font(Theme.Typography.technical(12))
                                            .foregroundColor(Theme.textSecondary)
                                            .frame(width: 45, alignment: .leading)
                                        
                                        Text("\(set.weight, specifier: "%.1f") \(unit)")
                                            .font(Theme.Typography.technical(14, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        Text("x \(set.reps)")
                                            .font(Theme.Typography.technical(14, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Spacer()
                                        
                                        if !set.isCompleted {
                                            Image(systemName: "xmark.circle")
                                                .foregroundColor(Theme.border)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Theme.apexGreen)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let exercise = Exercise(name: "Deadlift", targetMuscle: "Back")
    container.mainContext.insert(exercise)
    
    return NavigationStack {
        ExerciseHistoryView(exercise: exercise)
    }
    .modelContainer(container)
}
