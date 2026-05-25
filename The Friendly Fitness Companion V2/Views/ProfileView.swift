import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct ProfileView: View {
    @Query private var settingsQuery: [UserSettings]
    @Query private var allSessions: [WorkoutSession]
    @Query(sort: \BiometricLog.timestamp) private var biometricLogs: [BiometricLog]
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fasts: [FastingSession]
    @Environment(\.modelContext) private var modelContext
    
    // State for editing
    @State private var isEditing = false
    @State private var isShowingSettings = false
    @State private var draftName = ""
    @State private var draftWeight = ""
    @State private var draftPhase = "Hypertrophy"
    @State private var draftAge = ""
    @State private var draftHeight = ""
    @State private var draftActivityLevel = "Moderate"
    @State private var isShowingFastingTimer = false
    @State private var isShowingHelp = false
    
    // Recovery Map State
    @State private var isRecoveryMapExpanded = false
    @State private var selectedHeatmapMuscle: String? = nil
    @State private var isShowingMuscleDetail = false
    
    private var fastingStreakGridData: [FastingDayStatus] {
        let calendar = Calendar.current
        var data: [FastingDayStatus] = []
        let today = Date()
        
        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            let fastsOnDay = fasts.filter { fast in
                calendar.isDate(fast.startTime, inSameDayAs: date)
            }
            
            let status: FastingDayStatus.Status
            if fastsOnDay.isEmpty {
                status = .none
            } else {
                let metTarget = fastsOnDay.contains { fast in
                    let end = fast.endTime ?? fast.startTime
                    let elapsed = end.timeIntervalSince(fast.startTime) / 3600.0
                    return fast.isCompleted && elapsed >= Double(fast.targetHours)
                }
                status = metTarget ? .achieved : .broken
            }
            
            data.append(FastingDayStatus(date: date, status: status))
        }
        return data
    }
    
    // Physique Vault State
    @Query(sort: \PhysiquePhoto.timestamp, order: .forward) private var physiquePhotos: [PhysiquePhoto]
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingVaultView = false
    @State private var isProcessingPhoto = false
    @State private var isShowingCamera = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    let phases = ["Hypertrophy", "Strength", "Cutting", "Recomp"]
    
    private var settings: UserSettings? {
        settingsQuery.first
    }
    
    private var totalWorkouts: Int {
        allSessions.count
    }
    
    private var recoveryMap: [String: Int] {
        var map: [String: Int] = [:]
        let now = Date()
        let sortedSessions = allSessions.sorted { $0.timestamp > $1.timestamp }
        for session in sortedSessions {
            let daysAgo = Calendar.current.dateComponents([.day], from: session.timestamp, to: now).day ?? 0
            for workoutEx in session.exercises {
                let muscle = workoutEx.normalizedTargetMuscle
                if muscle != "UNKNOWN" {
                    if map[muscle] == nil {
                        map[muscle] = daysAgo
                    }
                }
            }
        }
        return map
    }
    
    struct WeeklyVolumePoint: Identifiable {
        let id = UUID()
        let weekLabel: String
        let muscleGroup: String
        let setsCount: Int
    }
    
    private var weeklyVolumeData: [WeeklyVolumePoint] {
        var data: [WeeklyVolumePoint] = []
        let now = Date()
        let calendar = Calendar.current
        
        let weekLabels = ["3 Wks Ago", "2 Wks Ago", "1 Wk Ago", "This Week"]
        
        for i in 0..<4 {
            let startDays = -(4 - i) * 7
            let endDays = -(3 - i) * 7
            
            guard let startDate = calendar.date(byAdding: .day, value: startDays, to: now),
                  let endDate = calendar.date(byAdding: .day, value: endDays, to: now) else { continue }
            
            let weekSessions = allSessions.filter { session in
                session.timestamp >= startDate && session.timestamp < endDate
            }
            
            var muscleSets: [String: Int] = [:]
            for session in weekSessions {
                for workoutEx in session.exercises {
                    let muscle = workoutEx.normalizedTargetMuscle
                    if muscle != "UNKNOWN" {
                        let completedCount = workoutEx.sets.filter { $0.isCompleted }.count
                        muscleSets[muscle, default: 0] += completedCount
                    }
                }
            }
            
            let label = weekLabels[i]
            for muscle in MuscleGroup.all {
                let count = muscleSets[muscle] ?? 0
                if count > 0 {
                    data.append(WeeklyVolumePoint(weekLabel: label, muscleGroup: muscle, setsCount: count))
                }
            }
        }
        return data
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
                        // 1. Interactive Membership Card
                        if isEditing {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Athlete Name")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                    TextField("Enter Name", text: $draftName)
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                        .padding()
                                        .background(Theme.surface)
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                }
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Weight (\(settings?.weightUnit ?? "lb"))")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                        TextField("Weight", text: $draftWeight)
                                            .keyboardType(.decimalPad)
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                            .padding()
                                            .background(Theme.surface)
                                            .cornerRadius(16)
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Height (in)")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                        TextField("Height", text: $draftHeight)
                                            .keyboardType(.numberPad)
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                            .padding()
                                            .background(Theme.surface)
                                            .cornerRadius(16)
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Age (years)")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                        TextField("Age", text: $draftAge)
                                            .keyboardType(.numberPad)
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                            .padding()
                                            .background(Theme.surface)
                                            .cornerRadius(16)
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Activity Level")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                        Picker("Activity", selection: $draftActivityLevel) {
                                            Text("Sedentary").tag("Sedentary")
                                            Text("Light").tag("Light")
                                            Text("Moderate").tag("Moderate")
                                            Text("Active").tag("Active")
                                            Text("Extreme").tag("Extreme")
                                        }
                                        .pickerStyle(.menu)
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Theme.surface)
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                        .tint(Theme.accent)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        } else {
                            MembershipCardView(name: settings?.userName ?? "Athlete", memberID: memberID)
                                .padding(.horizontal)
                                .padding(.top, 20)
                            
                            FastingStreakGridView(gridData: fastingStreakGridData)
                        }
                        
                        // 2. Trophy Cabinet
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Lifetime Achievements")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    Spacer().frame(width: 4)
                                    
                                    TrophyCard(
                                        title: "Lifetime Sessions",
                                        value: "\(totalWorkouts)",
                                        icon: "flame.fill",
                                        color: Theme.warningOrange
                                    )
                                    
                                    TrophyCard(
                                        title: "Total Tonnage",
                                        value: totalVolume > 1000 ? String(format: "%.1fk", totalVolume / 1000) : String(format: "%.0f", totalVolume),
                                        icon: "scalemass.fill",
                                        color: Theme.accent
                                    )
                                    
                                    TrophyCard(
                                        title: "Power Total (Est)",
                                        value: String(format: "%.0f", powerliftingTotal),
                                        icon: "bolt.shield.fill",
                                        color: Theme.apexGreen
                                    )
                                    
                                    Spacer().frame(width: 4)
                                }
                            }
                        }
                        
                        if let userSettings = settings {
                            let currentWeight = isEditing ? (Double(draftWeight) ?? userSettings.bodyWeight) : userSettings.bodyWeight
                            let currentAge = isEditing ? (Int(draftAge) ?? userSettings.userAgeYears) : userSettings.userAgeYears
                            let currentHeight = isEditing ? (Int(draftHeight) ?? userSettings.heightInches) : userSettings.heightInches
                            let currentActivity = isEditing ? draftActivityLevel : userSettings.activityLevel
                            let currentPhase = isEditing ? draftPhase : userSettings.currentPhase
                            
                            let calcs = MetabolicCalculations(
                                weight: currentWeight,
                                unit: userSettings.weightUnit,
                                bodyFat: userSettings.bodyFatPercentage,
                                phase: currentPhase,
                                age: currentAge,
                                activityLevel: currentActivity,
                                heightInches: currentHeight
                            )
                            
                            MacroProjectionView(
                                calculations: calcs,
                                phase: currentPhase,
                                age: currentAge,
                                height: currentHeight,
                                activityLevel: currentActivity,
                                weightUnit: userSettings.weightUnit
                            )
                        }
                        
                        // 3. Physique Vault & Focus
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Physique Vault")
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                Spacer()
                                Menu {
                                    Button(action: {
                                        HapticManager.shared.playSelection()
                                        isShowingCamera = true
                                    }) {
                                        Label("Camera (Alignment Guide)", systemImage: "camera.fill")
                                    }
                                    
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                        Label("Import from Library", systemImage: "photo.on.rectangle")
                                    }
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.title2)
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .padding(.horizontal)
                            
                            if isProcessingPhoto {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            } else if physiquePhotos.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.largeTitle)
                                        .foregroundColor(Theme.textSecondary)
                                    Text("No photos logged yet")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                                .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        Spacer().frame(width: 4)
                                        ForEach(physiquePhotos) { photo in
                                            Button(action: {
                                                isShowingVaultView = true
                                            }) {
                                                if let data = photo.imageData, let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 140)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
                                                        )
                                                } else {
                                                    Rectangle()
                                                        .fill(Theme.surface)
                                                        .frame(width: 100, height: 140)
                                                        .cornerRadius(12)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
                                                        )
                                                }
                                            }
                                        }
                                        Spacer().frame(width: 4)
                                    }
                                }
                            }
                            
                            // Current Focus
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Training Focus")
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.5)
                                    .padding(.top, 10)
                                
                                if isEditing {
                                    Picker("Phase", selection: $draftPhase) {
                                        ForEach(phases, id: \.self) { phase in
                                            Text(phase).tag(phase)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                } else {
                                    HStack {
                                        Image(systemName: phaseIcon(for: settings?.currentPhase ?? "Hypertrophy"))
                                            .foregroundColor(Theme.accent)
                                        Text(settings?.currentPhase ?? "Hypertrophy")
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Interactive Recovery Heatmap Section
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    HapticManager.shared.playSelection()
                                    isRecoveryMapExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Recovery Heatmap")
                                            .font(Theme.Typography.technical(14, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                            .tracking(1.5)
                                        Text(isRecoveryMapExpanded ? "Tap to collapse" : "Tap to expand body recovery map")
                                            .font(Theme.Typography.technical(10, weight: .semibold))
                                            .foregroundColor(Theme.accent)
                                    }
                                    Spacer()
                                    Image(systemName: isRecoveryMapExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                        .foregroundColor(Theme.accent)
                                        .font(.title3)
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            
                            if isRecoveryMapExpanded {
                                VStack(spacing: 12) {
                                    AnatomicalBodyMap(
                                        mode: .recovery,
                                        muscleState: recoveryMap
                                    ) { muscle in
                                        selectedHeatmapMuscle = muscle
                                        isShowingMuscleDetail = true
                                    }
                                    .frame(height: 350)
                                    .padding()
                                    
                                    // Map Legend
                                    HStack(spacing: 12) {
                                        legendItem(color: Theme.dangerRed, text: "Exhausted (<2d)")
                                        legendItem(color: Theme.warningOrange, text: "Recovering (<4d)")
                                        legendItem(color: Theme.apexGreen, text: "Recovered (4d+)")
                                    }
                                    .padding(.bottom, 12)
                                }
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // 4. Biometric Trajectory Chart
                        BiometricTrajectoryChart(logs: biometricLogs, sessions: allSessions, weightUnit: settings?.weightUnit ?? "lb")
                            .padding(.horizontal)
                        
                        // Weekly Set Volume Analytics Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Weekly Set Volume (Last 4 Weeks)")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            if weeklyVolumeData.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(Theme.textSecondary)
                                    Text("No set volume data logged")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                            } else {
                                Chart {
                                    ForEach(weeklyVolumeData) { point in
                                        BarMark(
                                            x: .value("Week", point.weekLabel),
                                            y: .value("Sets", point.setsCount)
                                        )
                                        .foregroundStyle(by: .value("Muscle", point.muscleGroup))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                            .foregroundStyle(Theme.border.opacity(0.1))
                                        AxisValueLabel {
                                            if let val = value.as(Int.self) {
                                                Text("\(val) sets")
                                                    .font(Theme.Typography.technical(8))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 200)
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Edit/Save Button
                        Button(action: {
                            if isEditing {
                                saveProfile()
                            } else {
                                startEditing()
                            }
                        }) {
                            Text(isEditing ? "Save Profile" : "Edit Profile")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(isEditing ? .white : Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isEditing ? Theme.accent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.accent, lineWidth: isEditing ? 0 : 2)
                                )
                                .cornerRadius(16)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
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
            .sheet(isPresented: $isShowingHelp) {
                ProfileHelpView()
            }
            .fullScreenCover(isPresented: $isShowingFastingTimer) {
                FastingView(isPresented: $isShowingFastingTimer)
            }
            .fullScreenCover(isPresented: $isShowingVaultView) {
                PhysiqueVaultView(isPresented: $isShowingVaultView)
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraCaptureView(
                    previousPhoto: physiquePhotos.last,
                    currentWeight: settings?.bodyWeight ?? 0.0,
                    currentPhase: settings?.currentPhase ?? "N/A"
                )
            }
            .sheet(isPresented: $isShowingMuscleDetail) {
                if let muscle = selectedHeatmapMuscle {
                    MuscleDetailView(muscleName: muscle, recoveryState: recoveryMap)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let newItem = newItem {
                        isProcessingPhoto = true
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            let photo = PhysiquePhoto(
                                timestamp: Date(),
                                imageData: data,
                                weightAtTime: settings?.bodyWeight ?? 0.0,
                                phaseAtTime: settings?.currentPhase ?? "Hypertrophy"
                            )
                            modelContext.insert(photo)
                            try? modelContext.save()
                        }
                        selectedPhotoItem = nil
                        isProcessingPhoto = false
                    }
                }
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
        draftPhase = settings?.currentPhase ?? "Hypertrophy"
        draftAge = String(settings?.userAgeYears ?? 25)
        draftHeight = String(settings?.heightInches ?? 0)
        draftActivityLevel = settings?.activityLevel ?? "Moderate"
        withAnimation {
            isEditing = true
        }
    }
    
    private func saveProfile() {
        if let currentSettings = settings {
            currentSettings.userName = draftName
            if let weight = Double(draftWeight) { currentSettings.bodyWeight = weight }
            currentSettings.currentPhase = draftPhase
            if let age = Int(draftAge) { currentSettings.userAgeYears = age }
            if let height = Int(draftHeight) { currentSettings.heightInches = height }
            currentSettings.activityLevel = draftActivityLevel
            
            // Auto-Logging Integration
            let log = BiometricLog(weight: Double(draftWeight), notes: "Profile Edit")
            modelContext.insert(log)
        }
        try? modelContext.save()
        withAnimation {
            isEditing = false
        }
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(Theme.Typography.technical(10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
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
            // Sleek dark modern titanium background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.09, blue: 0.13), Color(red: 0.18, green: 0.20, blue: 0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.accent.opacity(isDragging ? 0.4 : 0.15), radius: isDragging ? 20 : 10, x: 0, y: isDragging ? 10 : 5)
            
            // Border glow
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.8), Color.white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            
            // Content
            VStack(alignment: .leading) {
                HStack {
                    Text("ATHLETIC MEMBERSHIP")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2.0)
                    
                    Spacer()
                    
                    Image(systemName: "aqi.high")
                        .font(.title3)
                        .foregroundColor(Theme.accent)
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.isEmpty ? "Athlete" : name)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Text("ID: FF-\(memberID)")
                            .font(Theme.Typography.technical(11, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Chip / NFC indicator
                    Image(systemName: "wave.3.right")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.35))
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
                        .fill(color.opacity(0.12))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundColor(Theme.textPrimary)
                
                Text(title)
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
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
                .font(Theme.Typography.technical(12, weight: .bold))
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
                        .foregroundColor(Theme.textPrimary)
                    Text(unit)
                        .font(.caption.bold())
                        .foregroundColor(Theme.accent)
                }
            }
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

// MARK: - Biometric Trajectory Chart
struct BiometricTrajectoryChart: View {
    let logs: [BiometricLog]
    let sessions: [WorkoutSession]
    let weightUnit: String
    
    @State private var selectedDate: Date? = nil
    @State private var isShowingBiometricLogger = false
    @State private var selectedMetric: TrajectoryMetric = .bodyweight
    
    enum TrajectoryMetric: String, CaseIterable, Identifiable {
        case bodyweight = "Weight"
        case bench = "Bench"
        case squat = "Squat"
        case deadlift = "Deadlift"
        
        var id: String { rawValue }
        
        var displayLabel: String {
            switch self {
            case .bodyweight: return "Bodyweight History"
            case .bench: return "Bench Press 1RM Trend"
            case .squat: return "Squat 1RM Trend"
            case .deadlift: return "Deadlift 1RM Trend"
            }
        }
    }
    
    var trajectoryPoints: [TrajectoryPoint] {
        switch selectedMetric {
        case .bodyweight:
            return logs.compactMap { log -> TrajectoryPoint? in
                guard let w = log.weight else { return nil }
                return TrajectoryPoint(date: log.timestamp, value: w)
            }.sorted { $0.date < $1.date }
        case .bench, .squat, .deadlift:
            var points: [TrajectoryPoint] = []
            for session in sessions {
                var max1RM = 0.0
                for exercise in session.exercises {
                    let name = exercise.loggedName.isEmpty ? (exercise.exerciseRef?.name ?? "") : exercise.loggedName
                    let lowerName = name.lowercased()
                    
                    let isMatch: Bool
                    switch selectedMetric {
                    case .bench:
                        isMatch = lowerName.contains("bench press") || lowerName == "bench"
                    case .squat:
                        isMatch = lowerName.contains("squat")
                    case .deadlift:
                        isMatch = lowerName.contains("deadlift")
                    case .bodyweight:
                        isMatch = false
                    }
                    
                    if isMatch {
                        for set in exercise.sets {
                            let estimated1RM = set.weight * (1.0 + (Double(set.reps) / 30.0))
                            if estimated1RM > max1RM {
                                max1RM = estimated1RM
                            }
                        }
                    }
                }
                if max1RM > 0 {
                    points.append(TrajectoryPoint(date: session.timestamp, value: max1RM))
                }
            }
            return points.sorted { $0.date < $1.date }
        }
    }
    
    struct TrajectoryPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Metric", selection: $selectedMetric) {
                ForEach(TrajectoryMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)
            
            HStack {
                Text(selectedMetric.displayLabel)
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(1.5)
                
                Spacer()
                
                if selectedMetric == .bodyweight {
                    Button(action: {
                        HapticManager.shared.playSelection()
                        isShowingBiometricLogger = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Log Weight")
                                .font(Theme.Typography.technical(11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent)
                        .cornerRadius(8)
                    }
                }
            }
            
            if trajectoryPoints.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundColor(Theme.textSecondary)
                    Text("No historical data logged")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Theme.surface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.border, lineWidth: 1)
                )
            } else {
                Chart {
                    ForEach(trajectoryPoints) { pt in
                        if trajectoryPoints.count == 1 {
                            PointMark(
                                x: .value("Date", pt.date),
                                y: .value("Value", pt.value)
                            )
                            .foregroundStyle(Theme.warningOrange)
                            
                            RuleMark(
                                y: .value("Value", pt.value)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(Theme.warningOrange.opacity(0.5))
                        } else {
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Value", pt.value)
                            )
                            .foregroundStyle(Theme.warningOrange)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Date", pt.date),
                                y: .value("Value", pt.value)
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
                    
                    if let selectedDate = selectedDate, let pt = trajectoryPoints.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                        RuleMark(
                            x: .value("Date", pt.date)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .foregroundStyle(Theme.textSecondary)
                        .annotation(position: .top, spacing: 0) {
                            VStack(spacing: 4) {
                                Text(pt.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Text("\(String(format: "%.1f", pt.value)) \(weightUnit)")
                                    .font(Theme.Typography.technical(14, weight: .black))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(8)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
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
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let x = value.location.x - geo[plotFrame].origin.x
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
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $isShowingBiometricLogger) {
            QuickBiometricLoggerView()
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, BiometricLog.self, PhysiquePhoto.self, FastingSession.self], inMemory: true)
}

struct FastingStreakGridView: View {
    let gridData: [FastingDayStatus]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FASTING CONSISTENCY (LAST 30 DAYS)")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(2)
                Spacer()
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                        Text("Met")
                            .font(Theme.Typography.technical(8, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.warningOrange)
                            .frame(width: 8, height: 8)
                        Text("Miss")
                            .font(Theme.Typography.technical(8, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(gridData) { item in
                    let color: Color = {
                        switch item.status {
                        case .none: return Theme.surface.opacity(0.5)
                        case .achieved: return Theme.accent
                        case .broken: return Theme.warningOrange
                        }
                    }()
                    
                    let tooltipMsg = "\(item.date.formatted(date: .abbreviated, time: .omitted)): \(item.status == .none ? "No fast" : item.status == .achieved ? "Target Met" : "Broke Early")"
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.border.opacity(item.status == .none ? 0.3 : 0.8), lineWidth: 1)
                        )
                        .help(tooltipMsg)
                }
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal)
        }
    }
}

struct FastingDayStatus: Identifiable {
    let id = UUID()
    let date: Date
    let status: Status
    
    enum Status {
        case none
        case achieved
        case broken
    }
}

struct MetabolicCalculations {
    let tdee: Int
    let targetCalories: Int
    let proteinGrams: Int
    let carbGrams: Int
    let fatGrams: Int
    
    init(weight: Double, unit: String, bodyFat: Double, phase: String, age: Int = 25, activityLevel: String = "Moderate", heightInches: Int = 0) {
        let weightKg = (unit.lowercased() == "lb") ? (weight / 2.2) : weight
        let weightLbs = (unit.lowercased() == "lb") ? weight : (weight * 2.2)
        
        let bf = (bodyFat > 0 && bodyFat < 100) ? bodyFat : 15.0
        let lbmKg = weightKg * (1.0 - (bf / 100.0))
        
        let bmr: Double
        if bodyFat > 0 && bodyFat < 100 {
            // Katch-McArdle adjusted for metabolic deceleration with age
            let baseBmr = 370.0 + (21.6 * lbmKg)
            let ageAdjustment = max(0.8, 1.0 - Double(max(0, age - 25)) * 0.001)
            bmr = baseBmr * ageAdjustment
        } else {
            // Mifflin-St Jeor (unisex baseline with default s=5)
            let heightCm = heightInches > 0 ? Double(heightInches) * 2.54 : 175.0
            bmr = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * Double(age)) + 5.0
        }
        
        let activityMultiplier: Double
        switch activityLevel {
        case "Sedentary": activityMultiplier = 1.2
        case "Light": activityMultiplier = 1.375
        case "Moderate": activityMultiplier = 1.55
        case "Active": activityMultiplier = 1.725
        case "Extreme": activityMultiplier = 1.9
        default: activityMultiplier = 1.55
        }
        
        let calculatedTdee = bmr * activityMultiplier
        self.tdee = Int(calculatedTdee)
        
        switch phase {
        case "Cutting":
            self.targetCalories = Int(calculatedTdee - 500)
        case "Hypertrophy":
            self.targetCalories = Int(calculatedTdee + 300)
        case "Strength":
            self.targetCalories = Int(calculatedTdee + 200)
        case "Recomp":
            self.targetCalories = Int(calculatedTdee)
        default:
            self.targetCalories = Int(calculatedTdee)
        }
        
        let proteinPerLb: Double
        switch phase {
        case "Cutting": proteinPerLb = 1.2
        case "Hypertrophy": proteinPerLb = 1.0
        case "Strength": proteinPerLb = 0.9
        case "Recomp": proteinPerLb = 1.1
        default: proteinPerLb = 1.0
        }
        let p = max(50.0, weightLbs * proteinPerLb)
        self.proteinGrams = Int(p)
        
        let fatPerLb: Double
        switch phase {
        case "Cutting", "Recomp": fatPerLb = 0.25
        case "Hypertrophy", "Strength": fatPerLb = 0.3
        default: fatPerLb = 0.3
        }
        let f = max(20.0, weightLbs * fatPerLb)
        self.fatGrams = Int(f)
        
        let proteinCal = p * 4.0
        let fatCal = f * 9.0
        let remainingCal = Double(self.targetCalories) - (proteinCal + fatCal)
        let c = max(30.0, remainingCal / 4.0)
        self.carbGrams = Int(c)
    }
}

struct SpecBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typography.technical(9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(Theme.Typography.technical(11, weight: .black))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct MacroProjectionView: View {
    let calculations: MetabolicCalculations
    let phase: String
    let age: Int
    let height: Int
    let activityLevel: String
    let weightUnit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metabolic Projection")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(1.5)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
                // Specs Row
                HStack(spacing: 12) {
                    SpecBadge(label: "Age", value: "\(age) yrs")
                    SpecBadge(label: "Height", value: height > 0 ? "\(height) in" : "N/A")
                    SpecBadge(label: "Activity", value: activityLevel)
                }
                .padding(.bottom, 4)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated TDEE")
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(calculations.tdee)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("kcal")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Target")
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.accent)
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(calculations.targetCalories)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(Theme.accent)
                            Text("kcal")
                                .font(.caption.bold())
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider().background(Theme.border)
                
                VStack(spacing: 12) {
                    MacroBar(
                        name: "Protein",
                        grams: calculations.proteinGrams,
                        calories: calculations.proteinGrams * 4,
                        color: Theme.accent,
                        percentage: Double(calculations.proteinGrams * 4) / Double(max(1, calculations.targetCalories))
                    )
                    
                    MacroBar(
                        name: "Carbohydrates",
                        grams: calculations.carbGrams,
                        calories: calculations.carbGrams * 4,
                        color: .purple,
                        percentage: Double(calculations.carbGrams * 4) / Double(max(1, calculations.targetCalories))
                    )
                    
                    MacroBar(
                        name: "Dietary Fat",
                        grams: calculations.fatGrams,
                        calories: calculations.fatGrams * 9,
                        color: Theme.warningOrange,
                        percentage: Double(calculations.fatGrams * 9) / Double(max(1, calculations.targetCalories))
                    )
                }
            }
            .padding(20)
            .background(Theme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

struct MacroBar: View {
    let name: String
    let grams: Int
    let calories: Int
    let color: Color
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(Theme.Typography.technical(11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(grams)g")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(color)
                Text("•")
                    .font(Theme.Typography.technical(11))
                    .foregroundColor(Theme.textSecondary)
                Text("\(calories) kcal")
                    .font(Theme.Typography.technical(11))
                    .foregroundColor(Theme.textSecondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.border)
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(1.0, percentage)), height: 6)
                        .shadow(color: color.opacity(0.3), radius: 3)
                }
            }
            .frame(height: 6)
        }
    }
}
