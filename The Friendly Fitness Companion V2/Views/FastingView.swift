import SwiftUI
import SwiftData
import Combine
import Charts

struct FastingPhase: Identifiable, Equatable {
    let id: String
    let title: String
    let duration: String
    let icon: String
    let description: String
    let shortDescription: String
    let color: Color
    let gradientColors: [Color]
    let biologicalEffects: [String]
    
    init(id: String = UUID().uuidString, title: String, duration: String, icon: String, description: String, shortDescription: String, color: Color, gradientColors: [Color], biologicalEffects: [String]) {
        self.id = id
        self.title = title
        self.duration = duration
        self.icon = icon
        self.description = description
        self.shortDescription = shortDescription
        self.color = color
        self.gradientColors = gradientColors
        self.biologicalEffects = biologicalEffects
    }
}

struct FastingMilestone: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let condition: (Int, Double, Double) -> Bool // (count, totalHours, longestHours)
}


struct FastingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fasts: [FastingSession]
    @Query private var settings: [UserSettings]
    @Query(sort: \WaterLog.timestamp, order: .reverse) private var waterLogs: [WaterLog]
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var completedSessions: [WorkoutSession]
    
    @State private var isShowingHistory: Bool = false
    @State private var selectedPhase: FastingPhase?
    @State private var selectedProtocolHours: Int = 16
    @State private var justFinishedFasting: Bool = false
    @State private var isShowingHelp: Bool = false
    @State private var isShowingWeeklyPlanner: Bool = false
    @State private var fastToLogWellness: FastingSession? = nil
    @State private var isShowingFastingCheckIn: Bool = false
    
    @State private var simulatorHours: Double = 0.0
    @State private var isSimulating: Bool = false
    
    @State private var currentTime = Date()
    private let viewTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let milestones: [FastingMilestone] = [
        FastingMilestone(id: "first_step", name: "First Step", description: "Complete 1 fast", icon: "footprint.fill", category: "Sessions", condition: { count, _, _ in count >= 1 }),
        FastingMilestone(id: "consistent", name: "Consistent Faster", description: "Complete 5 fasts", icon: "calendar.badge.clock", category: "Sessions", condition: { count, _, _ in count >= 5 }),
        FastingMilestone(id: "champion", name: "Fasting Champion", description: "Complete 15 fasts", icon: "crown.fill", category: "Sessions", condition: { count, _, _ in count >= 15 }),
        FastingMilestone(id: "sugar_burner", name: "Sugar Burner Elite", description: "Accumulate 24 fasting hours", icon: "drop.fill", category: "Hours", condition: { _, hours, _ in hours >= 24 }),
        FastingMilestone(id: "half_century", name: "Half Century", description: "Accumulate 50 fasting hours", icon: "timer", category: "Hours", condition: { _, hours, _ in hours >= 50 }),
        FastingMilestone(id: "century", name: "Century Mark", description: "Accumulate 100 fasting hours", icon: "medal.fill", category: "Hours", condition: { _, hours, _ in hours >= 100 }),
        FastingMilestone(id: "autophagy_novice", name: "Autophagy Novice", description: "Fast 16+ hours in a single session", icon: "allergens.fill", category: "Single Session", condition: { _, _, longest in longest >= 16 }),
        FastingMilestone(id: "deep_cleanser", name: "Deep Cleanser", description: "Fast 20+ hours in a single session", icon: "sparkles", category: "Single Session", condition: { _, _, longest in longest >= 20 }),
        FastingMilestone(id: "warrior", name: "Warrior Fast", description: "Fast 24+ hours in a single session", icon: "shield.fill", category: "Single Session", condition: { _, _, longest in longest >= 24 }),
        FastingMilestone(id: "extended_grind", name: "Extended Grind", description: "Fast 36+ hours in a single session", icon: "bolt.shield.fill", category: "Single Session", condition: { _, _, longest in longest >= 36 })
    ]
    
    private var completedFastsCount: Int {
        fasts.filter { $0.isCompleted }.count
    }
    
    private var totalFastingHours: Double {
        let completed = fasts.filter { $0.isCompleted }
        let total = completed.reduce(0.0) { $0 + ($1.endTime?.timeIntervalSince($1.startTime) ?? 0) }
        return total / 3600.0
    }
    
    private var longestFastHours: Double {
        let completed = fasts.filter { $0.isCompleted }
        return completed.map { ($0.endTime?.timeIntervalSince($0.startTime) ?? 0) / 3600.0 }.max() ?? 0.0
    }

    var elapsedHours: Double {
        guard let active = activeFast else { return 0 }
        return currentTime.timeIntervalSince(active.startTime) / 3600.0
    }
    
    var currentSimulationHours: Double {
        if isSimulating {
            return simulatorHours
        } else {
            return elapsedHours
        }
    }
    
    var weeklySchedule: [Int] {
        let csv = settings.first?.weeklyFastingScheduleCSV ?? "16,16,16,16,16,16,16"
        let parts = csv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if parts.count == 7 {
            return parts
        } else {
            return [16, 16, 16, 16, 16, 16, 16]
        }
    }
    
    var todayWaterOz: Double {
        let calendar = Calendar.current
        let today = Date()
        let todayLogs = waterLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        return todayLogs.reduce(0.0) { $0 + $1.amountOz }
    }
    
    private func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func fastingPhaseInfoForHours(_ hours: Double) -> FastingPhase {
        if hours < 4 { return phases[0] }
        if hours < 12 { return phases[1] }
        if hours < 16 { return phases[2] }
        return phases[3]
    }
    
    private func progressForPhase(_ phaseId: String, elapsed: Double, target: Int) -> Double {
        switch phaseId {
        case "sugar":
            if elapsed <= 0 { return 0 }
            if elapsed >= 4 { return 1.0 }
            return elapsed / 4.0
        case "glycogen":
            if elapsed <= 4 { return 0 }
            if elapsed >= 12 { return 1.0 }
            return (elapsed - 4.0) / 8.0
        case "ketosis":
            if elapsed <= 12 { return 0 }
            if elapsed >= 16 { return 1.0 }
            return (elapsed - 12.0) / 4.0
        case "autophagy":
            if elapsed <= 16 { return 0 }
            let targetEnd = max(Double(target), 18.0)
            let duration = targetEnd - 16.0
            if elapsed >= targetEnd { return 1.0 }
            return (elapsed - 16.0) / duration
        default:
            return 0
        }
    }
    
    // Quick Protocols
    let quickProtocols = [
        ("12:12", 12),
        ("16:8", 16),
        ("18:6", 18),
        ("20:4", 20),
        ("OMAD", 23),
        ("Extended", 36)
    ]
    
    let phases = [
        FastingPhase(id: "sugar", title: "Sugar Burner", duration: "0 - 4 hrs", icon: "drop.fill", description: "Your body is sweeping up the remaining glucose in your bloodstream. The fat-burning gates are preparing to open.", shortDescription: "Insulin drops. Fat-burning gates prepare to open.", color: Theme.accent, gradientColors: [Color(red: 0.0, green: 0.15, blue: 0.4), Color.cyan], biologicalEffects: [
            "Insulin plummets, signaling fat cells to unlock.",
            "Blood sugar stabilizes, crushing mid-day cravings.",
            "The digestive factory finally clocks out for a break."
        ]),
        FastingPhase(id: "glycogen", title: "Glycogen Drain", duration: "4 - 12 hrs", icon: "bolt.fill", description: "Your liver is running on empty! As stored carbs vanish, your metabolism starts hunting for its next fuel source: your fat reserves.", shortDescription: "Liver runs empty. Metabolism hunts for fat.", color: Theme.warningOrange, gradientColors: [Color(red: 0.5, green: 0.1, blue: 0.0), Color.orange], biologicalEffects: [
            "Liver glycogen is aggressively depleted.",
            "The metabolic switch starts flipping to fat-burning mode.",
            "Hunger hormones peak and then completely surrender."
        ]),
        FastingPhase(id: "ketosis", title: "Ketosis Ignited", duration: "12 - 16 hrs", icon: "flame.fill", description: "Welcome to the fat-burning furnace. Your liver is now actively converting stubborn fat into high-octane ketone energy.", shortDescription: "Welcome to the fat-burning furnace.", color: .red, gradientColors: [Color(red: 0.4, green: 0.0, blue: 0.1), Color.red], biologicalEffects: [
            "Fat cells dump fatty acids directly into your bloodstream.",
            "Ketones flood your brain, unlocking laser-sharp focus.",
            "Stubborn fat is officially being used for fuel."
        ]),
        FastingPhase(id: "autophagy", title: "Deep Autophagy", duration: "16+ hrs", icon: "allergens.fill", description: "Cellular spring cleaning is in full effect. Your body is ruthlessly hunting down and recycling old, damaged cells to build a younger, stronger you.", shortDescription: "Cellular recycling engine roars to life.", color: .purple, gradientColors: [Color(red: 0.25, green: 0.0, blue: 0.4), Color.purple], biologicalEffects: [
            "The ultimate cellular recycling engine roars to life.",
            "Old proteins are destroyed and rebuilt from scratch.",
            "Anti-aging Human Growth Hormone (HGH) skyrockets."
        ])
    ]
    
    var activeFast: FastingSession? {
        fasts.first { !$0.isCompleted }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Weekly Schedule Preview Row
                        weeklySchedulePreviewRow
                            .padding(.top, 15)
                        
                        // Protocol Selector (Only show if not fasting)
                        if activeFast == nil {
                            protocolSelector
                        }
                        
                        // V2 Activity Ring Timer
                        V2TimerRing(
                            fast: activeFast,
                            targetHours: activeFast?.targetHours ?? selectedProtocolHours,
                            phases: phases,
                            onStartFast: {
                                HapticManager.shared.playSuccess()
                                startFast(hours: selectedProtocolHours)
                            },
                            onEndFast: {
                                endFast()
                            }
                        )
                            .frame(height: 320)
                            .padding(.top, activeFast == nil ? 10 : 40)
                        
                        if let active = activeFast {
                            VStack(spacing: 16) {
                                Button(action: {
                                    HapticManager.shared.playSelection()
                                    isShowingFastingCheckIn = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Log Fasting Check-In")
                                    }
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                                }
                                
                                if !active.logEntries.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Check-In Timeline")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                            .tracking(1.5)
                                            .padding(.horizontal)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(active.logEntries.sorted(by: { $0.timestamp < $1.timestamp })) { entry in
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        HStack {
                                                            Text(String(format: "Hour %.1f", entry.hoursIntoFast))
                                                                .font(Theme.Typography.technical(10, weight: .black))
                                                                .foregroundColor(Theme.accent)
                                                            Spacer()
                                                            Text(formatTimeShort(entry.timestamp))
                                                                .font(Theme.Typography.technical(9, weight: .bold))
                                                                .foregroundColor(Theme.textSecondary)
                                                        }
                                                        
                                                        HStack(spacing: 8) {
                                                            Label("\(entry.energyRating)", systemImage: "bolt.fill")
                                                            Label("\(entry.focusRating)", systemImage: "brain.head.profile")
                                                            Label("\(entry.hungerRating)", systemImage: "fork.knife")
                                                        }
                                                        .font(Theme.Typography.technical(9, weight: .bold))
                                                        .foregroundColor(Theme.textPrimary)
                                                        
                                                        if !entry.symptomsCSV.isEmpty {
                                                            Text(entry.symptomsCSV.replacingOccurrences(of: ",", with: " • "))
                                                                .font(.system(size: 10, weight: .semibold))
                                                                .foregroundColor(Theme.warningOrange)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    .padding()
                                                    .frame(width: 160)
                                                    .background(Theme.surface)
                                                    .cornerRadius(12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Theme.border, lineWidth: 1)
                                                    )
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Hydration Tracker
                        waterTrackerCard
                        
                        // Fasting Milestones
                        fastingMilestonesSection
                        
                        // Biological State Simulator
                        simulatorScrubberCard
                        
                        // Restored Fasting Cards (Vertical to prevent bugs)
                        infographicCardsView
                            .padding(.bottom, 40)
                    }
                }
                .onReceive(viewTimer) { input in
                    currentTime = input
                    if !isSimulating {
                        if let active = activeFast {
                            simulatorHours = currentTime.timeIntervalSince(active.startTime) / 3600.0
                        }
                    }
                }
                .onAppear {
                    if let active = activeFast {
                        simulatorHours = Date().timeIntervalSince(active.startTime) / 3600.0
                    } else {
                        simulatorHours = 0
                        updateDefaultHoursFromSchedule()
                    }
                }
            }
            .navigationTitle("Fasting Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button("Dismiss") {
                            isPresented = false
                        }
                        .foregroundColor(Theme.textSecondary)
                        
                        Button(action: {
                            isShowingHelp = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingHistory = true
                    }) {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $isShowingHistory) {
                FastingHistoryView()
            }
            .sheet(isPresented: $isShowingWeeklyPlanner, onDismiss: {
                updateDefaultHoursFromSchedule()
            }) {
                if let userSettings = settings.first {
                    FastingWeeklyPlannerSheet(settings: userSettings)
                }
            }
            .fullScreenCover(item: $selectedPhase) { phase in
                FastingPhaseDetailView(phase: phase)
            }
            .sheet(isPresented: $isShowingHelp) {
                FastingHelpView()
            }
            .sheet(item: $fastToLogWellness) { fast in
                FastingWellnessSheet(fast: fast)
            }
            .sheet(isPresented: $isShowingFastingCheckIn) {
                if let active = activeFast {
                    FastingCheckInSheet(activeFast: active)
                }
            }
        }
    }
    
    @ViewBuilder
    private var fastingMilestonesSection: some View {
        let count = completedFastsCount
        let hours = totalFastingHours
        let longest = longestFastHours
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Fasting Milestones & Achievements")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(milestones) { milestone in
                        let isUnlocked = milestone.condition(count, hours, longest)
                        
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isUnlocked ? Theme.accent.opacity(0.12) : Theme.border.opacity(0.3))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .stroke(isUnlocked ? Theme.accent : Theme.border, lineWidth: 1.5)
                                    )
                                    .shadow(color: isUnlocked ? Theme.accent.opacity(0.2) : .clear, radius: 4)
                                
                                Image(systemName: isUnlocked ? milestone.icon : "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(isUnlocked ? Theme.warningOrange : Theme.textSecondary.opacity(0.5))
                            }
                            
                            Text(milestone.name)
                                .font(Theme.Typography.technical(11, weight: .bold))
                                .foregroundColor(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                                .lineLimit(1)
                            
                            Text(milestone.description)
                                .font(Theme.Typography.technical(9))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(height: 24)
                                .lineLimit(2)
                        }
                        .padding()
                        .frame(width: 120, height: 130)
                        .background(Theme.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isUnlocked ? Theme.accent.opacity(0.3) : Theme.border, lineWidth: 1)
                        )
                        .opacity(isUnlocked ? 1.0 : 0.6)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var weeklySchedulePreviewRow: some View {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let schedule = weeklySchedule
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Fasting Schedule")
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.playSelection()
                    isShowingWeeklyPlanner = true
                }) {
                    Text("Edit Schedule")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { idx in
                    let isToday = (idx == todayIndex)
                    let targetHours = schedule[idx]
                    
                    VStack(spacing: 6) {
                        Text(days[idx])
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(isToday ? .white : Theme.textSecondary)
                        
                        Text(targetHours == 0 ? "Rest" : "\(targetHours)h")
                            .font(Theme.Typography.technical(13, weight: .black))
                            .foregroundColor(isToday ? .white : (targetHours == 0 ? Theme.warningOrange : Theme.textPrimary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isToday ? Theme.accent : Theme.surface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isToday ? Theme.accent : Theme.border, lineWidth: 1)
                    )
                    .shadow(color: isToday ? Theme.accent.opacity(0.2) : .clear, radius: 4)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var waterTrackerCard: some View {
        let currentIntake = todayWaterOz
        let goal = 100.0
        let progress = min(currentIntake / goal, 1.0)
        let cupCount = Int(currentIntake / 8.0)
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hydration Tracker")
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Stay hydrated during your fast")
                        .font(Theme.Typography.technical(11))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if currentIntake > 0 {
                    Button(action: resetWaterLogs) {
                        Text("Reset")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.dangerRed)
                    }
                }
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                Text(String(format: "%.0f", currentIntake))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(Theme.accent)
                
                Text("/ \(Int(goal)) oz")
                    .font(Theme.Typography.technical(16, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.bottom, 6)
                
                Spacer()
                
                Text("\(cupCount) \(cupCount == 1 ? "cup" : "cups")")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.midnightMatte)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.border.opacity(0.5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progress), height: 12)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 4)
                }
            }
            .frame(height: 12)
            
            // Quick Add Buttons
            HStack(spacing: 12) {
                Button(action: { logWater(amount: 8) }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("8 oz")
                            .font(Theme.Typography.technical(12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                
                Button(action: { logWater(amount: 16) }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("16 oz")
                            .font(Theme.Typography.technical(12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                
                Button(action: { logWater(amount: 24) }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("24 oz")
                            .font(Theme.Typography.technical(12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }
    
    private func logWater(amount: Double) {
        HapticManager.shared.playLightImpact()
        let log = WaterLog(amountOz: amount)
        modelContext.insert(log)
        try? modelContext.save()
    }
    
    private func resetWaterLogs() {
        HapticManager.shared.playSelection()
        let calendar = Calendar.current
        let today = Date()
        let todayLogs = waterLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        for log in todayLogs {
            modelContext.delete(log)
        }
        try? modelContext.save()
    }
    
    private func updateDefaultHoursFromSchedule() {
        guard activeFast == nil else { return }
        let schedule = weeklySchedule
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        if todayIndex >= 0 && todayIndex < 7 {
            let todaysTarget = schedule[todayIndex]
            if todaysTarget > 0 {
                selectedProtocolHours = todaysTarget
            }
        }
    }
    
    @ViewBuilder
    private var protocolSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Protocol")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickProtocols, id: \.0) { protocolItem in
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            withAnimation(.spring) {
                                selectedProtocolHours = protocolItem.1
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(protocolItem.0)
                                    .font(Theme.Typography.technical(16, weight: .bold))
                                    .foregroundColor(selectedProtocolHours == protocolItem.1 ? .white : Theme.textPrimary)
                                
                                Text("\(protocolItem.1)h")
                                    .font(Theme.Typography.technical(11, weight: .bold))
                                    .foregroundColor(selectedProtocolHours == protocolItem.1 ? .white.opacity(0.8) : Theme.textSecondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedProtocolHours == protocolItem.1 ? Theme.accent : Theme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedProtocolHours == protocolItem.1 ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
                            )
                            .shadow(color: selectedProtocolHours == protocolItem.1 ? Theme.accent.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var simulatorScrubberCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Biological State Simulator (Hour Scrub)")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if isSimulating {
                    Button(action: {
                        HapticManager.shared.playSelection()
                        isSimulating = false
                        if activeFast != nil {
                            simulatorHours = elapsedHours
                        } else {
                            simulatorHours = 0
                        }
                    }) {
                        Text("Reset")
                            .font(Theme.Typography.technical(11, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Text(String(format: "%.1f hrs", currentSimulationHours))
                    .font(Theme.Typography.technical(18, weight: .black))
                    .foregroundColor(isSimulating ? Theme.accent : Theme.textPrimary)
                    .frame(width: 85, alignment: .leading)
                
                Slider(
                    value: Binding(
                        get: { currentSimulationHours },
                        set: { newValue in
                            isSimulating = true
                            simulatorHours = newValue
                        }
                    ),
                    in: 0.0...36.0,
                    step: 0.5
                )
                .accentColor(isSimulating ? Theme.accent : Theme.border)
            }
            
            let phaseInfo = fastingPhaseInfoForHours(currentSimulationHours)
            Text("Preview State: \(phaseInfo.title)")
                .font(Theme.Typography.technical(11, weight: .bold))
                .foregroundColor(phaseInfo.color)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var infographicCardsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Physiological Phases")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
            
            // Standard vertical scrolling list of all phases (replaces horizontal snap)
            ForEach(phases) { phase in
                let activePhaseForSim = fastingPhaseInfoForHours(currentSimulationHours)
                let isActivePhase: Bool = (activeFast != nil || isSimulating) && (phase.id == activePhaseForSim.id)
                
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    selectedPhase = phase
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: phase.icon)
                                .font(.title2)
                                .foregroundColor(isActivePhase ? .white : phase.color)
                                .symbolEffect(.pulse, options: .repeating, isActive: isActivePhase)
                            Spacer()
                            HStack(spacing: 6) {
                                if isActivePhase {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .green, radius: 4)
                                    
                                    Text(isSimulating ? "Simulating" : "Active")
                                        .font(Theme.Typography.technical(11, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                } else {
                                    Text(phase.duration)
                                        .font(Theme.Typography.technical(11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        
                        Text(phase.title)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        Text(phase.description)
                            .font(.system(size: 13, weight: .medium))
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        if activeFast != nil || isSimulating {
                            let progress = progressForPhase(phase.id, elapsed: currentSimulationHours, target: activeFast?.targetHours ?? 16)
                            let percentStr = String(format: "%.0f%%", progress * 100)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Phase Progress")
                                        .font(Theme.Typography.technical(10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text(percentStr)
                                        .font(Theme.Typography.technical(11, weight: .black))
                                        .foregroundColor(.white)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.15))
                                            .frame(height: 6)
                                        
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(colors: phase.gradientColors, startPoint: .leading, endPoint: .trailing)
                                            )
                                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                                            .shadow(color: phase.color.opacity(0.8), radius: 3)
                                    }
                                }
                                .frame(height: 6)
                            }
                            .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(
                        ZStack {
                            Color.clear.background(.ultraThinMaterial)
                            AnimatedFluidBackground(colors: phase.gradientColors)
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: phase.icon)
                                        .font(.system(size: 140))
                                        .foregroundColor(isActivePhase ? .white.opacity(0.15) : .black.opacity(0.1))
                                        .rotationEffect(.degrees(15))
                                        .symbolEffect(.pulse, options: .repeating, isActive: isActivePhase)
                                        .offset(x: 30, y: 30)
                                }
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(isActivePhase ? 0.4 : 0.1), lineWidth: 1)
                    )
                    .shadow(color: isActivePhase ? phase.color.opacity(0.8) : .clear, radius: 30, x: 0, y: 0)
                }
                .buttonStyle(FastingCardPressStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
    }
    
    // MARK: - Core Logic
    private func startFast(hours: Int) {
        let newFast = FastingSession(targetHours: hours)
        modelContext.insert(newFast)
        try? modelContext.save()
    }
    
    private func endFast() {
        if let active = activeFast {
            active.endTime = Date()
            active.isCompleted = true
            try? modelContext.save()
            
            fastToLogWellness = active
        }
    }
}

// MARK: - V2 Components

struct V2TimerRing: View {
    let fast: FastingSession?
    let targetHours: Int
    let phases: [FastingPhase]
    let onStartFast: () -> Void
    let onEndFast: () -> Void
    
    @State private var currentTime = Date()
    @State private var showStopAlert = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    static func staticPhase(fast: FastingSession?, phases: [FastingPhase]) -> FastingPhase {
        guard let f = fast else { return phases[0] }
        let hours = Date().timeIntervalSince(f.startTime) / 3600.0
        if hours < 4 { return phases[0] }
        if hours < 12 { return phases[1] }
        if hours < 16 { return phases[2] }
        return phases[3]
    }
    
    var elapsedHours: Double {
        guard let fast = fast else { return 0 }
        return currentTime.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var progress: Double {
        guard fast != nil else { return 0 }
        return min(elapsedHours / Double(targetHours), 1.0)
    }
    
    var currentPhaseData: FastingPhase {
        if elapsedHours < 4 { return phases[0] }
        if elapsedHours < 12 { return phases[1] }
        if elapsedHours < 16 { return phases[2] }
        return phases[3]
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
    
    var body: some View {
        ZStack {
            // Background Track Ring
            Circle()
                .stroke(Theme.surface, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .frame(width: 280, height: 280)
            
            // Progress Ring
            if fast != nil {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: currentPhaseData.gradientColors + [currentPhaseData.gradientColors.first!]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: progress)
                    .shadow(color: currentPhaseData.color.opacity(0.4), radius: 10)
            }
            
            // Timer Content
            VStack(spacing: 8) {
                if let _ = fast {
                    Text(currentPhaseData.title)
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(currentPhaseData.color)
                        .tracking(1.5)
                    
                    Text(formatTime(elapsedHours * 3600))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                    
                    Text("Target: \(targetHours)h")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.bottom, 8)
                    
                    Text("Ready")
                        .font(Theme.Typography.technical(28, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("\(targetHours) Hour Target")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .frame(height: 300)
        .onTapGesture {
            if fast == nil {
                onStartFast()
            } else {
                showStopAlert = true
            }
        }
        .alert("End Fast Early?", isPresented: $showStopAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Fast", role: .destructive) {
                onEndFast()
            }
        } message: {
            Text("Are you sure you want to stop your fast?")
        }
        .onReceive(timer) { input in
            if fast != nil {
                currentTime = input
            }
        }
    }
}

struct V2CurrentPhaseCard: View {
    let fast: FastingSession?
    let phases: [FastingPhase]
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect() // Only updates every minute for phase checks
    
    var elapsedHours: Double {
        guard let fast = fast else { return 0 }
        return currentTime.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var currentPhaseData: FastingPhase {
        if elapsedHours < 4 { return phases[0] }
        if elapsedHours < 12 { return phases[1] }
        if elapsedHours < 16 { return phases[2] }
        return phases[3]
    }
    
    var body: some View {
        let phase = fast != nil ? currentPhaseData : phases[0]
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: phase.icon)
                    .font(.title)
                    .foregroundColor(phase.color)
                    .symbolEffect(.pulse, options: .repeating, isActive: fast != nil)
                
                Text(fast != nil ? "Current Phase" : "Starting Phase")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text(phase.duration)
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.midnightMatte)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
            
            Text(phase.title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            
            Text(phase.description)
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(6)
                .foregroundColor(Theme.textSecondary)
            
            Divider()
                .background(Theme.border)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Biological Effects")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Theme.textSecondary)
                
                ForEach(phase.biologicalEffects, id: \.self) { effect in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(phase.color)
                            .font(.system(size: 14))
                            .padding(.top, 2)
                        
                        Text(effect)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textPrimary.opacity(0.9))
                            .lineSpacing(4)
                    }
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                Theme.surface
                LinearGradient(colors: [phase.color.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.midnightMatte.opacity(0.1), radius: 10, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.5), value: phase.id)
        .onReceive(timer) { input in
            if fast != nil {
                currentTime = input
            }
        }
    }
}

struct FastingTrendChartView: View {
    let fasts: [FastingSession]
    let workouts: [WorkoutSession]
    
    @Query(sort: \WaterLog.timestamp, order: .forward) private var waterLogs: [WaterLog]
    @Query private var settings: [UserSettings]
    @State private var trendMode: TrendMode = .duration
    
    enum TrendMode: String, CaseIterable, Identifiable {
        case duration = "Duration"
        case hydration = "Hydration"
        case correlation = "Correlation"
        
        var id: String { rawValue }
        var displayLabel: String {
            switch self {
            case .duration: return "Fasting Duration (Last 7 Fasts)"
            case .hydration: return "Water Intake Trends (Last 7 Days)"
            case .correlation: return "Fasting & Training Correlation"
            }
        }
    }
    
    private var chartData: [(dateString: String, hours: Double, target: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        
        let completed = fasts.filter { $0.isCompleted }
        let sorted = completed.sorted(by: { $0.startTime < $1.startTime })
        let last7 = Array(sorted.suffix(7))
        
        return last7.map { fast in
            let dateStr = formatter.string(from: fast.startTime)
            let duration = (fast.endTime?.timeIntervalSince(fast.startTime) ?? 0) / 3600.0
            return (dateStr, duration, Double(fast.targetHours))
        }
    }
    
    private var waterChartData: [(dateString: String, amount: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        
        let calendar = Calendar.current
        var data: [(dateString: String, amount: Double)] = []
        let today = Date()
        
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dateStr = formatter.string(from: date)
            
            // Sum all water logs on this day
            let amountOnDay = waterLogs.filter { log in
                calendar.isDate(log.timestamp, inSameDayAs: date)
            }.reduce(0.0) { $0 + $1.amountOz }
            
            data.append((dateStr, amountOnDay))
        }
        return data
    }
    
    private var weightUnit: String {
        settings.first?.weightUnit ?? "lb"
    }
    
    private var fastedSessions: [WorkoutSession] {
        workouts.filter { session in
            fasts.contains { fast in
                if let end = fast.endTime {
                    return session.timestamp >= fast.startTime && session.timestamp <= end
                } else if !fast.isCompleted {
                    return session.timestamp >= fast.startTime && session.timestamp <= Date()
                }
                return false
            }
        }
    }
    
    private var fedSessions: [WorkoutSession] {
        workouts.filter { session in
            !fasts.contains { fast in
                if let end = fast.endTime {
                    return session.timestamp >= fast.startTime && session.timestamp <= end
                } else if !fast.isCompleted {
                    return session.timestamp >= fast.startTime && session.timestamp <= Date()
                }
                return false
            }
        }
    }
    
    private func avgRPE(for sessions: [WorkoutSession]) -> Double {
        guard !sessions.isEmpty else { return 0.0 }
        let sum = sessions.reduce(0.0) { $0 + Double($1.rpe) }
        return (sum / Double(sessions.count) * 10).rounded() / 10
    }
    
    private func avgVolume(for sessions: [WorkoutSession]) -> Double {
        guard !sessions.isEmpty else { return 0.0 }
        let sum = sessions.reduce(0.0) { $0 + totalVolume(for: $1) }
        return (sum / Double(sessions.count)).rounded()
    }
    
    private func totalVolume(for session: WorkoutSession) -> Double {
        session.exercises.reduce(0.0) { sum, ex in
            sum + ex.sets.filter { $0.isCompleted }.reduce(0.0) { setSum, set in
                setSum + (set.weight * Double(set.reps))
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Trend Type", selection: $trendMode) {
                ForEach(TrendMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            
            Text(trendMode.displayLabel)
                .font(Theme.Typography.technical(11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 4)
            
            if trendMode == .duration {
                if chartData.isEmpty {
                    emptyState(text: "Log fasting sessions to view trends.")
                } else {
                    durationChart
                }
            } else if trendMode == .hydration {
                if waterChartData.allSatisfy({ $0.amount == 0 }) {
                    emptyState(text: "Log water intake to view trends.")
                } else {
                    hydrationChart
                }
            } else {
                correlationView
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var correlationView: some View {
        let fasted = fastedSessions
        let fed = fedSessions
        
        let avgFastedRPE = avgRPE(for: fasted)
        let avgFedRPE = avgRPE(for: fed)
        
        let avgFastedVol = avgVolume(for: fasted)
        let avgFedVol = avgVolume(for: fed)
        
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Fasted Training Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundColor(Theme.accent)
                        Text("Fasted")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(fasted.count) Sessions")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Avg RPE: \(avgFastedRPE == 0 ? "N/A" : String(format: "%.1f", avgFastedRPE))")
                            .font(Theme.Typography.technical(11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Avg Vol: \(avgFastedVol == 0 ? "N/A" : String(format: "%.0f %@", avgFastedVol, weightUnit))")
                            .font(Theme.Typography.technical(11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                
                // Fed Training Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(Theme.warningOrange)
                        Text("Fed State")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(fed.count) Sessions")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Avg RPE: \(avgFedRPE == 0 ? "N/A" : String(format: "%.1f", avgFedRPE))")
                            .font(Theme.Typography.technical(11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Avg Vol: \(avgFedVol == 0 ? "N/A" : String(format: "%.0f %@", avgFedVol, weightUnit))")
                            .font(Theme.Typography.technical(11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
            }
            
            // Coach Insight Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Theme.apexGreen)
                    Text("AI Coach Correlation Insight")
                        .font(Theme.Typography.technical(11, weight: .black))
                        .foregroundColor(Theme.apexGreen)
                        .tracking(1.0)
                }
                
                let coachText: String = {
                    if fasted.isEmpty || fed.isEmpty {
                        return "Need more logged fasted and fed training sessions to compile correlation insights. Keep journaling your sessions!"
                    } else if avgFedVol > avgFastedVol {
                        let diff = avgFedVol - avgFastedVol
                        var text = "Your average training volume is \(String(format: "%.0f", diff)) \(weightUnit) higher in a fed state. "
                        if avgFastedRPE > avgFedRPE {
                            text += "Additionally, fasted workouts feel more fatiguing (RPE \(avgFastedRPE) vs \(avgFedRPE) fed). Recommendation: Schedule heavy strength sessions in your eating window, and light cardio/active recovery during fasts."
                        } else {
                            text += "Recommendation: Perform heavy compound lifts while fed, but you can continue using fasted windows for conditioning."
                        }
                        return text
                    } else if avgFastedVol > avgFedVol {
                        let diff = avgFastedVol - avgFedVol
                        return "Intriguing! Your fasted training volume is \(String(format: "%.0f", diff)) \(weightUnit) higher than fed. You may respond exceptionally well to the epinephrine/growth hormone surge associated with fasted states. Recommendation: Keep training fasted, but watch recovery metrics closely."
                    } else {
                        return "Fasted vs. Fed workout performance is currently equal. Keep training consistently and adjust scheduling based on your daily energy levels."
                    }
                }()
                
                Text(coachText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textPrimary.opacity(0.9))
                    .lineSpacing(4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
    }
    
    @ViewBuilder
    private func emptyState(text: String) -> some View {
        Text(text)
            .font(Theme.Typography.technical(12))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Theme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var durationChart: some View {
        Chart {
            ForEach(chartData.indices, id: \.self) { idx in
                let item = chartData[idx]
                
                BarMark(
                    x: .value("Date", item.dateString),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(item.hours >= item.target ? Theme.apexGreen : Theme.accent)
                .cornerRadius(4)
                
                RuleMark(
                    y: .value("Target", item.target)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Theme.warningOrange)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text("\(Int(val))h")
                            .font(Theme.Typography.technical(9))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Theme.border.opacity(0.1))
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let val = value.as(String.self) {
                        Text(val)
                            .font(Theme.Typography.technical(9))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 120)
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var hydrationChart: some View {
        Chart {
            ForEach(waterChartData.indices, id: \.self) { idx in
                let item = waterChartData[idx]
                
                BarMark(
                    x: .value("Date", item.dateString),
                    y: .value("Ounces", item.amount)
                )
                .foregroundStyle(item.amount >= 100 ? Theme.apexGreen : Theme.accent)
                .cornerRadius(4)
                
                RuleMark(
                    y: .value("Goal", 100.0)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Theme.warningOrange)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text("\(Int(val)) oz")
                            .font(Theme.Typography.technical(9))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Theme.border.opacity(0.1))
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let val = value.as(String.self) {
                        Text(val)
                            .font(Theme.Typography.technical(9))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 120)
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Fasting History
struct FastingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fasts: [FastingSession]
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var workouts: [WorkoutSession]
    
    @State private var isShowingManualLogger = false
    @State private var editingFast: FastingSession? = nil
    
    private var completedFasts: [FastingSession] {
        fasts.filter { $0.isCompleted }
    }
    
    private var totalFasts: Int {
        completedFasts.count
    }
    
    private var averageDuration: Double {
        guard !completedFasts.isEmpty else { return 0 }
        let total = completedFasts.reduce(0.0) { $0 + ($1.endTime?.timeIntervalSince($1.startTime) ?? 0) }
        return (total / Double(completedFasts.count)) / 3600.0
    }
    
    private var longestFast: TimeInterval {
        completedFasts.map { $0.endTime?.timeIntervalSince($0.startTime) ?? 0 }.max() ?? 0
    }
    
    private var currentStreak: Int {
        guard !completedFasts.isEmpty else { return 0 }
        var streak = 0
        let calendar = Calendar.current
        var checkDate = Date()
        
        for fast in completedFasts {
            if calendar.isDate(fast.startTime, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if calendar.isDate(fast.startTime, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: checkDate)!) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -2, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                if fasts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.border)
                        Text("No Fasting History")
                            .font(Theme.Typography.technical(20, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("Complete a fast to start building your streak.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            isShowingManualLogger = true
                        }) {
                            Text("Log Manual Fast")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Theme.accent)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            statisticsHeader
                                .padding(.top, 20)
                            
                            FastingTrendChartView(fasts: fasts, workouts: workouts)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Fasting Ledger")
                                    .font(Theme.Typography.technical(14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(fasts) { fast in
                                        FastingHistoryCard(fast: fast)
                                            .padding(.horizontal)
                                            .contextMenu {
                                                Button {
                                                    editingFast = fast
                                                } label: {
                                                    Label("Edit Session", systemImage: "pencil")
                                                }
                                                
                                                Button(role: .destructive) {
                                                    deleteFast(fast)
                                                } label: {
                                                    Label("Delete Session", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Fasting History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingManualLogger = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Theme.Typography.technical(16, weight: .bold))
                    .foregroundColor(Theme.accent)
                }
            }
            .sheet(isPresented: $isShowingManualLogger) {
                ManualFastingLogSheet()
            }
            .sheet(item: $editingFast) { fast in
                EditFastingLogSheet(fast: fast)
            }
        }
    }
    
    @ViewBuilder
    private var statisticsHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(title: "Total Fasts", value: "\(totalFasts)", icon: "checkmark.circle.fill", color: Theme.accent)
                StatCard(title: "Streak", value: "\(currentStreak) Days", icon: "flame.fill", color: Theme.warningOrange)
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                let avgStr = String(format: "%.1f", averageDuration)
                StatCard(title: "Avg Duration", value: "\(avgStr)h", icon: "chart.bar.fill", color: Theme.textPrimary)
                
                let longestStr = String(format: "%.1f", (longestFast / 3600.0))
                StatCard(title: "Longest Fast", value: "\(longestStr)h", icon: "crown.fill", color: Theme.dangerRed)
            }
            .padding(.horizontal)
        }
    }
    
    private func deleteFast(_ fast: FastingSession) {
        modelContext.delete(fast)
        try? modelContext.save()
        HapticManager.shared.playLightImpact()
    }
}

struct FastingHistoryCard: View {
    let fast: FastingSession
    @State private var isExpanded = false
    
    var actualDurationHours: Double {
        let end = fast.endTime ?? fast.startTime
        return end.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var didMeetTarget: Bool {
        actualDurationHours >= Double(fast.targetHours)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(didMeetTarget ? Theme.accent.opacity(0.12) : Theme.warningOrange.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: didMeetTarget ? "checkmark" : "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(didMeetTarget ? Theme.accent : Theme.warningOrange)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Started:")
                                .foregroundColor(Theme.textSecondary)
                            Text(fast.startTime.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        if let endTime = fast.endTime {
                            HStack(spacing: 4) {
                                Text("Broke:")
                                    .foregroundColor(Theme.textSecondary)
                                Text(endTime.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                    .font(Theme.Typography.technical(11, weight: .bold))
                    
                    HStack(spacing: 4) {
                        Text("Target: \(fast.targetHours)h")
                        Text("•")
                        Text(didMeetTarget ? "Achieved" : "Broken Early")
                            .foregroundColor(didMeetTarget ? Theme.accent : Theme.warningOrange)
                    }
                    .font(Theme.Typography.technical(11))
                    .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    let durationStr = String(format: "%.1f", actualDurationHours)
                    HStack(spacing: 8) {
                        Text("\(durationStr)h")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        if !fast.logEntries.isEmpty {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                    }
                }
            }
            
            if isExpanded && !fast.logEntries.isEmpty {
                Divider()
                    .background(Theme.border.opacity(0.3))
                    .padding(.vertical, 12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bio-Feedback Timeline")
                        .font(Theme.Typography.technical(10, weight: .black))
                        .foregroundColor(Theme.accent)
                        .tracking(1.5)
                        .padding(.bottom, 4)
                    
                    ForEach(fast.logEntries.sorted(by: { $0.timestamp < $1.timestamp })) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(format: "Hour %.1f Check-In", entry.hoursIntoFast))
                                    .font(Theme.Typography.technical(10, weight: .black))
                                    .foregroundColor(Theme.accent)
                                Spacer()
                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(Theme.Typography.technical(9, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            HStack(spacing: 12) {
                                Label {
                                    Text("\(entry.energyRating)")
                                } icon: {
                                    Image(systemName: "bolt.fill")
                                        .foregroundColor(Theme.warningOrange)
                                }
                                
                                Label {
                                    Text("\(entry.focusRating)")
                                } icon: {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(Theme.accent)
                                }
                                
                                Label {
                                    Text("\(entry.hungerRating)")
                                } icon: {
                                    Image(systemName: "fork.knife")
                                        .foregroundColor(Theme.apexGreen)
                                }
                            }
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            
                            if !entry.symptomsCSV.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.warningOrange)
                                        .padding(.top, 1.5)
                                    Text("Symptoms: " + entry.symptomsCSV.replacingOccurrences(of: ",", with: ", "))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Theme.warningOrange)
                                }
                            }
                            
                            if !entry.notes.isEmpty {
                                Text(entry.notes)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.midnightMatte.opacity(0.4))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(10)
                        .background(Theme.midnightMatte.opacity(0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !fast.logEntries.isEmpty {
                HapticManager.shared.playSelection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

struct AnimatedFluidBackground: View {
    let colors: [Color]
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: proxy.size.width * 1.5, height: proxy.size.width * 1.5)
                        .offset(x: isAnimating ? proxy.size.width * 0.2 : -proxy.size.width * 0.2,
                                y: isAnimating ? proxy.size.height * 0.2 : -proxy.size.height * 0.2)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .opacity(0.4 - Double(index) * 0.1)
                        .animation(
                            .linear(duration: Double(8 + index * 2)).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
            }
            .blur(radius: 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct FastingCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct FastingPhaseDetailView: View {
    let phase: FastingPhase
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: phase.icon)
                        .font(.system(size: 60))
                        .foregroundColor(phase.color)
                        .padding(.top, 40)
                    
                    Text(phase.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(phase.duration)
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(phase.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .lineSpacing(8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Biological Effects")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(4.0)
                        
                        ForEach(Array(phase.biologicalEffects.enumerated()), id: \.element) { index, effect in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(.black.opacity(0.4))
                                        .frame(width: 36, height: 36)
                                    
                                    Text(String(format: "%02d", index + 1))
                                        .font(Theme.Typography.technical(13, weight: .black))
                                        .foregroundColor(.white)
                                }
                                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                                
                                Text(effect)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.95))
                                    .lineSpacing(6)
                                    .padding(.top, 8)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.25)))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.15), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .background(
                ZStack {
                    AnimatedFluidBackground(colors: phase.gradientColors)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: phase.icon)
                                .font(.system(size: 350))
                                .foregroundColor(.black.opacity(0.15))
                                .rotationEffect(.degrees(15))
                                .offset(x: 100, y: 50)
                        }
                    }
                }
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(.black.opacity(0.3)))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ManualFastingLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date = Calendar.current.date(byAdding: .hour, value: -16, to: Date()) ?? Date()
    @State private var endTime: Date = Date()
    @State private var targetHours: Int = 16
    @State private var errorMessage: String? = nil
    
    // Wellness & ratings
    @State private var energyRating: Int = 3
    @State private var focusRating: Int = 3
    @State private var hungerRating: Int = 3
    @State private var wellnessNotes: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let error = errorMessage {
                            Text(error)
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.dangerRed)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.dangerRed.opacity(0.12))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.dangerRed, lineWidth: 1))
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fast Start Time")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fast End Time")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Duration")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                HStack {
                                    Text("\(targetHours) Hours")
                                        .font(Theme.Typography.technical(16, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Stepper("", value: $targetHours, in: 1...168)
                                        .labelsHidden()
                                }
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                            
                            // Wellness Survey
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Wellness Survey")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                StarRatingPicker(label: "Energy Level", rating: $energyRating, activeColor: Theme.warningOrange)
                                Divider().background(Theme.border)
                                StarRatingPicker(label: "Mental Focus", rating: $focusRating, activeColor: Theme.accent)
                                Divider().background(Theme.border)
                                StarRatingPicker(label: "Hunger Control", rating: $hungerRating, activeColor: Theme.apexGreen)
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wellness & Bio-feedback Notes")
                                    .font(Theme.Typography.technical(11, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextEditor(text: $wellnessNotes)
                                    .font(.body)
                                    .foregroundColor(Theme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .frame(minHeight: 100)
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(action: saveManualFast) {
                            Text("Save Fast to Ledger")
                                .font(Theme.Typography.technical(16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accent)
                                .cornerRadius(16)
                                .shadow(color: Theme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .padding()
                    }
                    .padding(.top, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Log Manual Fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func saveManualFast() {
        if endTime <= startTime {
            errorMessage = "Error: End time must be after start time"
            return
        }
        
        let newSession = FastingSession(
            targetHours: targetHours,
            energyRating: energyRating,
            focusRating: focusRating,
            hungerRating: hungerRating,
            wellnessNotes: wellnessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : wellnessNotes
        )
        newSession.startTime = startTime
        newSession.endTime = endTime
        newSession.isCompleted = true
        
        modelContext.insert(newSession)
        try? modelContext.save()
        
        HapticManager.shared.playSuccess()
        dismiss()
    }
}

struct EditFastingLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let fast: FastingSession
    
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var targetHours: Int
    @State private var errorMessage: String? = nil
    
    // Wellness & ratings
    @State private var energyRating: Int
    @State private var focusRating: Int
    @State private var hungerRating: Int
    @State private var wellnessNotes: String
    
    init(fast: FastingSession) {
        self.fast = fast
        _startTime = State(initialValue: fast.startTime)
        _endTime = State(initialValue: fast.endTime ?? Date())
        _targetHours = State(initialValue: fast.targetHours)
        _energyRating = State(initialValue: fast.energyRating ?? 3)
        _focusRating = State(initialValue: fast.focusRating ?? 3)
        _hungerRating = State(initialValue: fast.hungerRating ?? 3)
        _wellnessNotes = State(initialValue: fast.wellnessNotes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let error = errorMessage {
                            Text(error)
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.dangerRed)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.dangerRed.opacity(0.12))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.dangerRed, lineWidth: 1))
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fast Start Time")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fast End Time")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Duration")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                HStack {
                                    Text("\(targetHours) Hours")
                                        .font(Theme.Typography.technical(16, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Stepper("", value: $targetHours, in: 1...168)
                                        .labelsHidden()
                                }
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                            
                            // Wellness Survey
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Wellness Survey")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                StarRatingPicker(label: "Energy Level", rating: $energyRating, activeColor: Theme.warningOrange)
                                Divider().background(Theme.border)
                                StarRatingPicker(label: "Mental Focus", rating: $focusRating, activeColor: Theme.accent)
                                Divider().background(Theme.border)
                                StarRatingPicker(label: "Hunger Control", rating: $hungerRating, activeColor: Theme.apexGreen)
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wellness & Bio-feedback Notes")
                                    .font(Theme.Typography.technical(11, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextEditor(text: $wellnessNotes)
                                    .font(.body)
                                    .foregroundColor(Theme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .frame(minHeight: 100)
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(action: saveChanges) {
                            Text("Save Changes")
                                .font(Theme.Typography.technical(16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accent)
                                .cornerRadius(16)
                                .shadow(color: Theme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .padding()
                    }
                    .padding(.top, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit Fasting Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func saveChanges() {
        if endTime <= startTime {
            errorMessage = "Error: End time must be after start time"
            return
        }
        
        fast.startTime = startTime
        fast.endTime = endTime
        fast.targetHours = targetHours
        fast.energyRating = energyRating
        fast.focusRating = focusRating
        fast.hungerRating = hungerRating
        fast.wellnessNotes = wellnessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : wellnessNotes
        
        try? modelContext.save()
        
        HapticManager.shared.playSuccess()
        dismiss()
    }
}

struct FastingWeeklyPlannerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let settings: UserSettings
    
    @State private var mondayTarget: Int = 16
    @State private var tuesdayTarget: Int = 16
    @State private var wednesdayTarget: Int = 16
    @State private var thursdayTarget: Int = 16
    @State private var fridayTarget: Int = 16
    @State private var saturdayTarget: Int = 16
    @State private var sundayTarget: Int = 16
    
    init(settings: UserSettings) {
        self.settings = settings
        let csv = settings.weeklyFastingScheduleCSV
        let parts = csv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let schedule = parts.count == 7 ? parts : [16, 16, 16, 16, 16, 16, 16]
        
        _mondayTarget = State(initialValue: schedule[0])
        _tuesdayTarget = State(initialValue: schedule[1])
        _wednesdayTarget = State(initialValue: schedule[2])
        _thursdayTarget = State(initialValue: schedule[3])
        _fridayTarget = State(initialValue: schedule[4])
        _saturdayTarget = State(initialValue: schedule[5])
        _sundayTarget = State(initialValue: schedule[6])
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Customize your daily fasting hours target. A setting of 0 represents a Rest/Eating day.")
                            .font(Theme.Typography.technical(12))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            dayRow(dayName: "Monday", target: $mondayTarget)
                            dayRow(dayName: "Tuesday", target: $tuesdayTarget)
                            dayRow(dayName: "Wednesday", target: $wednesdayTarget)
                            dayRow(dayName: "Thursday", target: $thursdayTarget)
                            dayRow(dayName: "Friday", target: $fridayTarget)
                            dayRow(dayName: "Saturday", target: $saturdayTarget)
                            dayRow(dayName: "Sunday", target: $sundayTarget)
                        }
                        .padding(.horizontal)
                        
                        Button(action: saveSchedule) {
                            Text("Save Schedule")
                                .font(Theme.Typography.technical(16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accent)
                                .cornerRadius(16)
                                .shadow(color: Theme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .padding()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Weekly Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func dayRow(dayName: String, target: Binding<Int>) -> some View {
        HStack {
            Text(dayName)
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 110, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 12) {
                if target.wrappedValue == 0 {
                    Text("Rest")
                        .font(Theme.Typography.technical(14, weight: .black))
                        .foregroundColor(Theme.warningOrange)
                } else {
                    Text("\(target.wrappedValue)h")
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                
                Stepper("", value: target, in: 0...24)
                    .labelsHidden()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
    }
    
    private func saveSchedule() {
        let schedule = [
            mondayTarget,
            tuesdayTarget,
            wednesdayTarget,
            thursdayTarget,
            fridayTarget,
            saturdayTarget,
            sundayTarget
        ]
        let csv = schedule.map { String($0) }.joined(separator: ",")
        settings.weeklyFastingScheduleCSV = csv
        try? modelContext.save()
        
        HapticManager.shared.playSuccess()
        dismiss()
    }
}

struct FastingWellnessSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let fast: FastingSession
    
    @State private var energyRating: Int = 3
    @State private var focusRating: Int = 3
    @State private var hungerRating: Int = 3
    @State private var wellnessNotes: String = ""
    
    var elapsedHours: Double {
        let end = fast.endTime ?? Date()
        return end.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Summary Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fast Completed")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack {
                                Text(String(format: "%.1f hours", elapsedHours))
                                    .font(Theme.Typography.technical(22, weight: .black))
                                    .foregroundColor(Theme.accent)
                                Spacer()
                                Text("Goal: \(fast.targetHours)h")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Divider()
                                .background(Theme.border)
                                .padding(.vertical, 4)
                            
                            HStack {
                                Text("Started: \(fast.startTime.formatted(date: .abbreviated, time: .shortened))")
                                Spacer()
                                if let end = fast.endTime {
                                    Text("Ended: \(end.formatted(date: .abbreviated, time: .shortened))")
                                }
                            }
                            .font(Theme.Typography.technical(10))
                            .foregroundColor(Theme.textSecondary)
                        }
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                        
                        // Ratings
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Wellness Survey")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                StarRatingPicker(label: "Energy Level", rating: $energyRating, activeColor: Theme.warningOrange)
                                Divider().background(Theme.border)
                                StarRatingPicker(label: "Mental Focus", rating: $focusRating, activeColor: Theme.accent)
                                Divider().background(Theme.border)
                                StarRatingPicker(label: "Hunger Control", rating: $hungerRating, activeColor: Theme.apexGreen)
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wellness & Bio-feedback Notes")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            TextEditor(text: $wellnessNotes)
                                .font(.body)
                                .foregroundColor(Theme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .frame(minHeight: 120)
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                        }
                        
                        Button(action: saveWellnessData) {
                            Text("Save Wellness Record")
                                .font(Theme.Typography.technical(16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accent)
                                .cornerRadius(16)
                                .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Fasting Wellness Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
            .onAppear {
                energyRating = fast.energyRating ?? 3
                focusRating = fast.focusRating ?? 3
                hungerRating = fast.hungerRating ?? 3
                wellnessNotes = fast.wellnessNotes ?? ""
            }
        }
    }
    
    private func saveWellnessData() {
        fast.energyRating = energyRating
        fast.focusRating = focusRating
        fast.hungerRating = hungerRating
        fast.wellnessNotes = wellnessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : wellnessNotes
        
        try? modelContext.save()
        HapticManager.shared.playSuccess()
        dismiss()
    }
}

struct StarRatingPicker: View {
    let label: String
    @Binding var rating: Int
    let activeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Typography.technical(11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { num in
                    Button(action: {
                        HapticManager.shared.playSelection()
                        rating = num
                    }) {
                        Image(systemName: num <= rating ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundColor(num <= rating ? activeColor : Theme.textSecondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FastingCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let activeFast: FastingSession
    
    @State private var energyRating: Int = 3
    @State private var focusRating: Int = 3
    @State private var hungerRating: Int = 3
    @State private var selectedSymptoms: Set<String> = []
    @State private var notes: String = ""
    
    let symptomsOptions = ["Headache", "Fatigue", "Mental Clarity", "Hunger Pangs", "High Energy", "Irritability", "Cold Sensations", "Muscle Soreness"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("Log Fasting Check-In")
                                .font(Theme.Typography.technical(18, weight: .black))
                                .foregroundColor(Theme.textPrimary)
                            
                            let elapsed = Date().timeIntervalSince(activeFast.startTime) / 3600.0
                            Text(String(format: "Hour %.1f of %d Hour Fast", elapsed, activeFast.targetHours))
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bio-Feedback Ratings")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            VStack(spacing: 12) {
                                StarRatingPicker(label: "Energy Level", rating: $energyRating, activeColor: Theme.warningOrange)
                                Divider().background(Theme.border.opacity(0.3))
                                StarRatingPicker(label: "Mental Focus", rating: $focusRating, activeColor: Theme.accent)
                                Divider().background(Theme.border.opacity(0.3))
                                StarRatingPicker(label: "Hunger Control", rating: $hungerRating, activeColor: Theme.apexGreen)
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Symptoms & States")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                                ForEach(symptomsOptions, id: \.self) { symptom in
                                    let isSelected = selectedSymptoms.contains(symptom)
                                    Button(action: {
                                        HapticManager.shared.playSelection()
                                        if isSelected {
                                            selectedSymptoms.remove(symptom)
                                        } else {
                                            selectedSymptoms.insert(symptom)
                                        }
                                    }) {
                                        Text(symptom)
                                            .font(Theme.Typography.technical(11, weight: .bold))
                                            .foregroundColor(isSelected ? .white : Theme.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? Theme.accent : Theme.surface)
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Journal Notes")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            TextEditor(text: $notes)
                                .font(.body)
                                .foregroundColor(Theme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .frame(minHeight: 100)
                                .background(Theme.surface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.playSuccess()
                        let elapsed = Date().timeIntervalSince(activeFast.startTime) / 3600.0
                        let entry = FastingLogEntry(
                            timestamp: Date(),
                            hoursIntoFast: elapsed,
                            energyRating: energyRating,
                            focusRating: focusRating,
                            hungerRating: hungerRating,
                            symptomsCSV: selectedSymptoms.sorted().joined(separator: ","),
                            notes: notes
                        )
                        entry.fastingSession = activeFast
                        modelContext.insert(entry)
                        activeFast.logEntries.append(entry)
                        try? modelContext.save()
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

