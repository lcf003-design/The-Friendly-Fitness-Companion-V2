import SwiftUI
import SwiftData
import Charts

struct ProfileView: View {
    @Query private var settingsQuery: [UserSettings]
    @Query private var allSessions: [WorkoutSession]
    @Query(sort: \BiometricLog.timestamp) private var biometricLogs: [BiometricLog]
    @Environment(\.modelContext) private var modelContext
    
    // State for editing
    @State private var isEditing = false
    @State private var isShowingSettings = false
    @State private var draftName = ""
    @State private var draftWeight = ""
    @State private var draftBodyFat = ""
    @State private var draftHeight = ""
    @State private var draftAge = ""
    @State private var draftPhase = "Hypertrophy"
    @State private var isShowingFastingTimer = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    let phases = ["Hypertrophy", "Strength", "Cutting", "Recomp"]
    
    private var settings: UserSettings? {
        settingsQuery.first
    }
    
    private var totalWorkouts: Int {
        allSessions.count
    }
    
    private var totalVolume: Double {
        var total = 0.0
        for session in allSessions {
            for exercise in session.exercises {
                for set in exercise.sets {
                    total += set.weight * Double(set.reps)
                }
            }
        }
        return total
    }
    
    private var powerliftingTotal: Double {
        var maxBench = 0.0
        var maxSquat = 0.0
        var maxDeadlift = 0.0
        
        for session in allSessions {
            for exercise in session.exercises {
                let name = exercise.loggedName.isEmpty ? (exercise.exerciseRef?.name.lowercased() ?? "") : exercise.loggedName.lowercased()
                
                var maxForExercise = 0.0
                for set in exercise.sets {
                    let estimated1RM = set.weight * (1.0 + (Double(set.reps) / 30.0))
                    if estimated1RM > maxForExercise {
                        maxForExercise = estimated1RM
                    }
                }
                
                if name.contains("bench press") || name == "bench" {
                    maxBench = max(maxBench, maxForExercise)
                } else if name.contains("squat") {
                    maxSquat = max(maxSquat, maxForExercise)
                } else if name.contains("deadlift") {
                    maxDeadlift = max(maxDeadlift, maxForExercise)
                }
            }
        }
        
        return maxBench + maxSquat + maxDeadlift
    }
    
    // Compute a deterministic ID based on the user's name
    private var memberID: String {
        let name = settings?.userName ?? "A"
        let hash = abs(name.hashValue)
        let prefix = String(hash).prefix(6)
        return String(prefix.padding(toLength: 6, withPad: "0", startingAt: 0))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // 1. Interactive Membership Card
                        if isEditing {
                            VStack {
                                Text("Edit Athlete Name")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                TextField("Enter Name", text: $draftName)
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.vertical, 16)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        } else {
                            MembershipCardView(name: settings?.userName ?? "Athlete", memberID: memberID)
                                .padding(.horizontal)
                                .padding(.top, 20)
                        }
                        
                        // 2. Trophy Cabinet
                        VStack(alignment: .leading, spacing: 16) {
                            Text("LIFETIME ACHIEVEMENTS")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    Spacer().frame(width: 4)
                                    
                                    TrophyCard(
                                        title: "LIFETIME SESSIONS",
                                        value: "\(totalWorkouts)",
                                        icon: "flame.fill",
                                        color: Theme.warningOrange
                                    )
                                    
                                    TrophyCard(
                                        title: "TOTAL TONNAGE",
                                        value: totalVolume > 1000 ? String(format: "%.1fk", totalVolume / 1000) : String(format: "%.0f", totalVolume),
                                        icon: "scalemass.fill",
                                        color: Theme.accent
                                    )
                                    
                                    TrophyCard(
                                        title: "POWER TOTAL (EST)",
                                        value: String(format: "%.0f", powerliftingTotal),
                                        icon: "bolt.shield.fill",
                                        color: Theme.apexGreen
                                    )
                                    
                                    Spacer().frame(width: 4)
                                }
                            }
                        }
                        
                        // 3. Scouting Report Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SCOUTING REPORT")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                BiometricCard(title: "BODY WEIGHT", value: String(format: "%.1f", settings?.bodyWeight ?? 0), unit: settings?.weightUnit ?? "lb", isEditing: isEditing, text: $draftWeight, keyboardType: .decimalPad)
                                
                                BiometricCard(title: "BODY FAT", value: String(format: "%.1f", settings?.bodyFatPercentage ?? 0), unit: "%", isEditing: isEditing, text: $draftBodyFat, keyboardType: .decimalPad)
                                
                                BiometricCard(title: "HEIGHT", value: "\(settings?.heightInches ?? 0)", unit: "in", isEditing: isEditing, text: $draftHeight, keyboardType: .numberPad)
                                
                                BiometricCard(title: "TRAINING AGE", value: "\(settings?.trainingAgeYears ?? 0)", unit: "yrs", isEditing: isEditing, text: $draftAge, keyboardType: .numberPad)
                            }
                            .padding(.horizontal)
                            
                            // Current Phase
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENT FOCUS")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
                                    .padding(.top, 10)
                                
                                if isEditing {
                                    Picker("Phase", selection: $draftPhase) {
                                        ForEach(phases, id: \.self) { phase in
                                            Text(phase).tag(phase)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .background(Theme.surface)
                                    .cornerRadius(8)
                                } else {
                                    HStack {
                                        Image(systemName: phaseIcon(for: settings?.currentPhase ?? "Hypertrophy"))
                                            .foregroundColor(Theme.accent)
                                        Text(settings?.currentPhase ?? "Hypertrophy")
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 4. Biometric Trajectory Chart
                        BiometricTrajectoryChart(logs: biometricLogs)
                            .padding(.horizontal)
                        
                        // Edit/Save Button
                        Button(action: {
                            if isEditing {
                                saveProfile()
                            } else {
                                startEditing()
                            }
                        }) {
                            Text(isEditing ? "SAVE PROFILE" : "EDIT PROFILE")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(isEditing ? .black : Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isEditing ? Theme.accent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.accent, lineWidth: isEditing ? 0 : 2)
                                )
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Command Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                if let currentSettings = settings {
                    SettingsView(settings: currentSettings)
                }
            }
            .fullScreenCover(isPresented: $isShowingFastingTimer) {
                FastingView(isPresented: $isShowingFastingTimer)
            }
        }
    }
    
    private func phaseIcon(for phase: String) -> String {
        switch phase {
        case "Hypertrophy": return "figure.strengthtraining.traditional"
        case "Strength": return "dumbbell.fill"
        case "Cutting": return "flame.fill"
        case "Recomp": return "arrow.triangle.2.circlepath"
        default: return "star.fill"
        }
    }
    
    private func startEditing() {
        draftName = settings?.userName ?? ""
        draftWeight = String(settings?.bodyWeight ?? 0)
        draftBodyFat = String(settings?.bodyFatPercentage ?? 0)
        draftHeight = String(settings?.heightInches ?? 0)
        draftAge = String(settings?.trainingAgeYears ?? 0)
        draftPhase = settings?.currentPhase ?? "Hypertrophy"
        withAnimation {
            isEditing = true
        }
    }
    
    private func saveProfile() {
        if let currentSettings = settings {
            currentSettings.userName = draftName
            if let weight = Double(draftWeight) { currentSettings.bodyWeight = weight }
            if let fat = Double(draftBodyFat) { currentSettings.bodyFatPercentage = fat }
            if let height = Int(draftHeight) { currentSettings.heightInches = height }
            if let age = Int(draftAge) { currentSettings.trainingAgeYears = age }
            currentSettings.currentPhase = draftPhase
            
            // Auto-Logging Integration
            let log = BiometricLog(weight: Double(draftWeight), bodyFat: Double(draftBodyFat), notes: "Profile Edit")
            modelContext.insert(log)
        }
        try? modelContext.save()
        withAnimation {
            isEditing = false
        }
    }
}

// MARK: - Subcomponents

struct MembershipCardView: View {
    let name: String
    let memberID: String
    
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Theme.surface, Theme.midnightMatte],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.accent.opacity(isDragging ? 0.4 : 0.1), radius: isDragging ? 20 : 10, x: 0, y: isDragging ? 10 : 5)
            
            // Border glow
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.8), Theme.border.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            
            // Content
            VStack(alignment: .leading) {
                HStack {
                    Text("ORIGIN ATHLETE")
                        .font(Theme.Typography.technical(12, weight: .black))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(3)
                    
                    Spacer()
                    
                    Image(systemName: "aqi.high")
                        .font(.title3)
                        .foregroundColor(Theme.accent)
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.isEmpty ? "ATHLETE" : name.uppercased())
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Text("ID: FF-\(memberID)")
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Chip / NFC indicator
                    Image(systemName: "wave.3.right")
                        .font(.title2)
                        .foregroundColor(Theme.border.opacity(0.6))
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(24)
            
            // Dynamic Glare effect based on drag
            GeometryReader { geo in
                LinearGradient(
                    colors: [.white.opacity(0.0), .white.opacity(isDragging ? 0.15 : 0.05), .white.opacity(0.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: isDragging ? offset.width : -geo.size.width/2, y: isDragging ? offset.height : -geo.size.height/2)
                .mask(RoundedRectangle(cornerRadius: 24))
            }
        }
        .frame(height: 200)
        .rotation3DEffect(
            .degrees(isDragging ? Double(-offset.height / 15) : 0),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
        .rotation3DEffect(
            .degrees(isDragging ? Double(offset.width / 15) : 0),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                        isDragging = true
                        offset = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                        isDragging = false
                        offset = .zero
                    }
                }
        )
    }
}

struct TrophyCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .padding(12)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(title)
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct BiometricCard: View {
    let title: String
    let value: String
    let unit: String
    let isEditing: Bool
    @Binding var text: String
    let keyboardType: UIKeyboardType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Typography.technical(10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            
            if isEditing {
                HStack(spacing: 4) {
                    TextField(value, text: $text)
                        .keyboardType(keyboardType)
                        .font(.title2.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(unit)
                        .font(.caption.bold())
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Biometric Trajectory Chart
struct BiometricTrajectoryChart: View {
    let logs: [BiometricLog]
    
    @State private var selectedDate: Date? = nil
    
    var validWeightLogs: [BiometricLog] {
        logs.filter { $0.weight != nil }.sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPERATIONAL TRAJECTORY")
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
            
            if validWeightLogs.isEmpty {
                VStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundColor(Theme.textSecondary)
                    Text("NO HISTORICAL DATA")
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border.opacity(0.3), lineWidth: 1)
                )
            } else {
                Chart {
                    ForEach(validWeightLogs) { log in
                        if let weight = log.weight {
                            if validWeightLogs.count == 1 {
                                PointMark(
                                    x: .value("Date", log.timestamp),
                                    y: .value("Weight", weight)
                                )
                                .foregroundStyle(Theme.warningOrange)
                                
                                RuleMark(
                                    y: .value("Weight", weight)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(Theme.warningOrange.opacity(0.5))
                            } else {
                                LineMark(
                                    x: .value("Date", log.timestamp),
                                    y: .value("Weight", weight)
                                )
                                .foregroundStyle(Theme.warningOrange)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                
                                AreaMark(
                                    x: .value("Date", log.timestamp),
                                    y: .value("Weight", weight)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.warningOrange.opacity(0.3), Theme.warningOrange.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                    }
                    
                    if let selectedDate = selectedDate, let log = validWeightLogs.min(by: { abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate)) }), let weight = log.weight {
                        RuleMark(
                            x: .value("Date", log.timestamp)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .foregroundStyle(Theme.textSecondary)
                        .annotation(position: .top, spacing: 0) {
                            VStack(spacing: 4) {
                                Text(log.timestamp.formatted(date: .abbreviated, time: .omitted))
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Text("\(String(format: "%.1f", weight))")
                                    .font(Theme.Typography.technical(14, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Theme.midnightMatte.opacity(0.8))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Theme.border.opacity(0.1))
                        AxisValueLabel() {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.month().day()))
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Theme.border.opacity(0.1))
                        AxisValueLabel() {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(Int(doubleValue))")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            selectedDate = date
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedDate = nil
                                    }
                            )
                    }
                }
                .frame(height: 250)
                .padding()
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, BiometricLog.self], inMemory: true)
}
