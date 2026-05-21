import SwiftUI
import SwiftData

struct ProgressView: View {
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    
    @State private var isShowingHelp = false
    @State private var selectedSegment = 0 // 0 = Routines, 1 = Body Parts
    @State private var selectedMuscle: String? = nil
    @State private var isShowingMuscleDetail = false
    
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
