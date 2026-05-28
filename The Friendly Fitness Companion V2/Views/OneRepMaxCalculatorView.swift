import SwiftUI
import SwiftData

struct OneRepMaxCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var userSettings: [UserSettings]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var sessions: [WorkoutSession]
    
    @State private var selectedExercise: Exercise? = nil
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    
    @State private var selectedPlateWeight: Double? = nil
    @State private var isShowingPlateCalculator = false
    
    private var allTimePRSet: ExerciseSet? {
        guard let selected = selectedExercise else { return nil }
        var bestSet: ExerciseSet? = nil
        var best1RM = 0.0
        
        for session in sessions {
            for wex in session.exercises {
                if wex.exerciseRef?.id == selected.id {
                    for set in wex.sets {
                        if set.isCompleted && set.weight > 0 && set.reps > 0 {
                            let est = set.weight * (1.0 + (Double(set.reps) / 30.0))
                            if est > best1RM {
                                best1RM = est
                                bestSet = set
                            }
                        }
                    }
                }
            }
        }
        return bestSet
    }
    
    private var mostRecentSet: ExerciseSet? {
        guard let selected = selectedExercise else { return nil }
        for session in sessions {
            for wex in session.exercises {
                if wex.exerciseRef?.id == selected.id {
                    if let lastSet = wex.sets.last(where: { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }) {
                        return lastSet
                    }
                }
            }
        }
        return nil
    }
    
    private var estimated1RM: Double {
        let weight = Double(weightString) ?? 0.0
        let reps = Double(repsString) ?? 0.0
        guard weight > 0 && reps > 0 else { return 0.0 }
        
        // Epley Formula
        return weight * (1.0 + (reps / 30.0))
    }
    
    private let percentages: [Double] = [1.0, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.60]
    
    private func calculatePlates(for weight: Double) -> [(plate: Double, count: Int)] {
        let unit = userSettings.first?.weightUnit ?? "lb"
        let allPlates = unit == "kg" ? [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25] : [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
        
        let activePlates: [Double]
        if let csv = userSettings.first?.availablePlatesCSV, !csv.isEmpty {
            let parsed = csv.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let intersected = parsed.filter { allPlates.contains($0) }
            activePlates = intersected.isEmpty ? allPlates : intersected
        } else {
            activePlates = allPlates
        }
        
        let barWeight = unit == "kg" ? 20.0 : 45.0
        var targetPerSide = (weight - barWeight) / 2.0
        if targetPerSide <= 0 { return [] }
        
        var result: [(plate: Double, count: Int)] = []
        for plate in activePlates.sorted(by: >) {
            if targetPerSide >= plate {
                let count = Int(targetPerSide / plate)
                result.append((plate, count))
                targetPerSide -= Double(count) * plate
            }
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Exercise Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Exercise (Optional)")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1)
                            
                            Picker("Exercise", selection: $selectedExercise) {
                                Text("None").tag(nil as Exercise?)
                                ForEach(exercises) { ex in
                                    Text(ex.name).tag(ex as Exercise?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.accent)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // History Cards
                        if selectedExercise != nil {
                            HStack(spacing: 16) {
                                // All-Time PR Card
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(Theme.warningOrange)
                                        Text("All-Time PR")
                                            .font(Theme.Typography.technical(10, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    if let pr = allTimePRSet {
                                        Text("\(Int(pr.weight)) \(userSettings.first?.weightUnit ?? "lb") × \(pr.reps)")
                                            .font(Theme.Typography.technical(16, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Button(action: {
                                            HapticManager.shared.playSuccess()
                                            weightString = String(format: "%.1f", pr.weight)
                                            repsString = "\(pr.reps)"
                                        }) {
                                            Text("Auto-Fill")
                                                .font(Theme.Typography.technical(10, weight: .black))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Theme.warningOrange)
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Text("No PR logged")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.bottom, 6)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                                )
                                
                                // Most Recent Set Card
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(Theme.accent)
                                        Text("Recent Lift")
                                            .font(Theme.Typography.technical(10, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    if let recent = mostRecentSet {
                                        Text("\(Int(recent.weight)) \(userSettings.first?.weightUnit ?? "lb") × \(recent.reps)")
                                            .font(Theme.Typography.technical(16, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Button(action: {
                                            HapticManager.shared.playSuccess()
                                            weightString = String(format: "%.1f", recent.weight)
                                            repsString = "\(recent.reps)"
                                        }) {
                                            Text("Auto-Fill")
                                                .font(Theme.Typography.technical(10, weight: .black))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Theme.accent)
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Text("No recent lifts")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.bottom, 6)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Inputs
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lifted Weight")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("0", text: $weightString)
                                    .keyboardType(.decimalPad)
                                    .font(.title.bold())
                                    .foregroundColor(Theme.warningOrange)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reps Achieved")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("0", text: $repsString)
                                    .keyboardType(.numberPad)
                                    .font(.title.bold())
                                    .foregroundColor(Theme.accent)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 1RM Hero Display
                        VStack(spacing: 8) {
                            Text("Estimated 1RM")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(Int(estimated1RM))")
                                    .font(Theme.Typography.technical(60, weight: .black))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text(userSettings.first?.weightUnit ?? "lb")
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // Percentage Breakdown Table
                        if estimated1RM > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Load Percentages")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ForEach(percentages, id: \.self) { pct in
                                        let targetWeight = Double(Int(estimated1RM * pct))
                                        HStack(spacing: 12) {
                                            Text("\(Int(pct * 100))%")
                                                .font(Theme.Typography.technical(16, weight: .bold))
                                                .foregroundColor(pct == 1.0 ? Theme.warningOrange : Theme.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text("\(Int(targetWeight)) \(userSettings.first?.weightUnit ?? "lb")")
                                                .font(.headline)
                                                .foregroundColor(pct == 1.0 ? Theme.warningOrange : Theme.textSecondary)
                                            
                                            Button(action: {
                                                HapticManager.shared.playSelection()
                                                selectedPlateWeight = targetWeight
                                                isShowingPlateCalculator = true
                                            }) {
                                                Image(systemName: "info.circle")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.accent)
                                                    .frame(width: 24, height: 24)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 14)
                                        .background(Theme.surface)
                                        .overlay(
                                            Divider().background(Theme.border.opacity(0.3)),
                                            alignment: .bottom
                                        )
                                    }
                                }
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("1RM Calculator")
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
            .sheet(isPresented: $isShowingPlateCalculator) {
                if let targetWeight = selectedPlateWeight {
                    let unit = userSettings.first?.weightUnit ?? "lb"
                    BarbellPlateLoaderSheet(
                        weight: targetWeight,
                        unit: unit,
                        plates: calculatePlates(for: targetWeight),
                        barbellName: userSettings.first?.barbellType ?? (unit == "kg" ? "Olympic Bar (20 kg)" : "Olympic Bar (45 lb)"),
                        barbellWeight: userSettings.first?.barbellWeight ?? (unit == "kg" ? 20.0 : 45.0)
                    )
                }
            }
        }
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self, FastingLogEntry.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try? ModelContainer(for: schema, configurations: [config])
    
    guard let safeContainer = container else {
        return AnyView(Text("Preview failed to load container"))
    }
    
    return AnyView(OneRepMaxCalculatorView()
        .modelContainer(safeContainer))
}
