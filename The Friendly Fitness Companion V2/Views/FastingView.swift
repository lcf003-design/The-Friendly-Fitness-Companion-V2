import SwiftUI
import SwiftData
import Combine

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

struct FastingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fasts: [FastingSession]
    
    @State private var isShowingHistory: Bool = false
    @State private var selectedPhase: FastingPhase?
    @State private var selectedProtocolHours: Int = 16
    @State private var justFinishedFasting: Bool = false
    
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
        FastingPhase(id: "sugar", title: "Sugar Burner", duration: "0 - 4 HRS", icon: "drop.fill", description: "Your body is sweeping up the remaining glucose in your bloodstream. The fat-burning gates are preparing to open.", shortDescription: "Insulin drops. Fat-burning gates prepare to open.", color: Theme.accent, gradientColors: [Color(red: 0.0, green: 0.15, blue: 0.4), Color.cyan], biologicalEffects: [
            "Insulin plummets, signaling fat cells to unlock.",
            "Blood sugar stabilizes, crushing mid-day cravings.",
            "The digestive factory finally clocks out for a break."
        ]),
        FastingPhase(id: "glycogen", title: "Glycogen Drain", duration: "4 - 12 HRS", icon: "bolt.fill", description: "Your liver is running on empty! As stored carbs vanish, your metabolism starts hunting for its next fuel source: your fat reserves.", shortDescription: "Liver runs empty. Metabolism hunts for fat.", color: Theme.warningOrange, gradientColors: [Color(red: 0.5, green: 0.1, blue: 0.0), Color.orange], biologicalEffects: [
            "Liver glycogen is aggressively depleted.",
            "The metabolic switch starts flipping to fat-burning mode.",
            "Hunger hormones peak and then completely surrender."
        ]),
        FastingPhase(id: "ketosis", title: "Ketosis Ignited", duration: "12 - 16 HRS", icon: "flame.fill", description: "Welcome to the fat-burning furnace. Your liver is now actively converting stubborn fat into high-octane ketone energy.", shortDescription: "Welcome to the fat-burning furnace.", color: .red, gradientColors: [Color(red: 0.4, green: 0.0, blue: 0.1), Color.red], biologicalEffects: [
            "Fat cells dump fatty acids directly into your bloodstream.",
            "Ketones flood your brain, unlocking laser-sharp focus.",
            "Stubborn fat is officially being used for fuel."
        ]),
        FastingPhase(id: "autophagy", title: "Deep Autophagy", duration: "16+ HRS", icon: "allergens.fill", description: "Cellular spring cleaning is in full effect. Your body is ruthlessly hunting down and recycling old, damaged cells to build a younger, stronger you.", shortDescription: "Cellular recycling engine roars to life.", color: .purple, gradientColors: [Color(red: 0.25, green: 0.0, blue: 0.4), Color.purple], biologicalEffects: [
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
                        // Protocol Selector (Only show if not fasting)
                        if activeFast == nil {
                            protocolSelector
                                .padding(.top, 10)
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
                        
                        // Restored Fasting Cards (Vertical to prevent bugs)
                        infographicCardsView
                            .padding(.bottom, 40)
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
                    Button("Dismiss") {
                        isPresented = false
                    }
                    .foregroundColor(Theme.textSecondary)
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
            .fullScreenCover(item: $selectedPhase) { phase in
                FastingPhaseDetailView(phase: phase)
            }
        }
    }
    
    @ViewBuilder
    private var protocolSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHOOSE PROTOCOL")
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
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
                                
                                Text("\(protocolItem.1)H")
                                    .font(Theme.Typography.technical(10, weight: .bold))
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
                            .shadow(color: selectedProtocolHours == protocolItem.1 ? Theme.accent.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var infographicCardsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PHYSIOLOGICAL PHASES")
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
                .padding(.horizontal)
            
            // Standard vertical scrolling list of all phases (replaces horizontal snap)
            ForEach(phases) { phase in
                let isActivePhase: Bool = (activeFast != nil) && (phase.id == V2TimerRing.staticPhase(fast: activeFast, phases: phases).id)
                
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
                                    
                                    Text("ACTIVE")
                                        .font(Theme.Typography.technical(10, weight: .bold).monospaced())
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                } else {
                                    Text(phase.duration)
                                        .font(Theme.Typography.technical(10, weight: .bold).monospaced())
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        
                        Text(phase.title.uppercased())
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        Text(phase.description)
                            .font(.system(size: 13, weight: .medium))
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
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
                    .shadow(color: currentPhaseData.color.opacity(0.5), radius: 15)
            }
            
            // Timer Content
            VStack(spacing: 8) {
                if let _ = fast {
                    Text(currentPhaseData.title.uppercased())
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(currentPhaseData.color)
                        .tracking(2)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                    
                    Text(formatTime(elapsedHours * 3600))
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                    
                    Text("TARGET: \(targetHours)H")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.bottom, 8)
                    
                    Text("READY")
                        .font(Theme.Typography.technical(28, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("\(targetHours) HOUR TARGET")
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
                
                Text(fast != nil ? "CURRENT PHASE" : "STARTING PHASE")
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(2)
                
                Spacer()
                
                Text(phase.duration)
                    .font(Theme.Typography.technical(12, weight: .bold).monospaced())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.surface)
                    .cornerRadius(8)
            }
            
            Text(phase.title.uppercased())
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            
            Text(phase.description)
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(6)
                .foregroundColor(.white.opacity(0.85))
            
            Divider()
                .background(Theme.border)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("BIOLOGICAL EFFECTS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(2)
                
                ForEach(phase.biologicalEffects, id: \.self) { effect in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(phase.color)
                            .font(.system(size: 14))
                            .padding(.top, 2)
                        
                        Text(effect)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(4)
                    }
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                Theme.surface
                LinearGradient(colors: [phase.color.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.5), value: phase.id)
        .onReceive(timer) { input in
            if fast != nil {
                currentTime = input
            }
        }
    }
}

// MARK: - Fasting History
struct FastingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fasts: [FastingSession]
    
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
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            statisticsHeader
                                .padding(.top, 20)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("FASTING LEDGER")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(fasts) { fast in
                                        FastingHistoryCard(fast: fast)
                                            .padding(.horizontal)
                                            .contextMenu {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Theme.Typography.technical(16, weight: .bold))
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
    
    @ViewBuilder
    private var statisticsHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(title: "TOTAL FASTS", value: "\(totalFasts)", icon: "checkmark.circle.fill", color: Theme.accent)
                StatCard(title: "STREAK", value: "\(currentStreak) DAYS", icon: "flame.fill", color: Theme.warningOrange)
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                let avgStr = String(format: "%.1f", averageDuration)
                StatCard(title: "AVG DURATION", value: "\(avgStr)H", icon: "chart.bar.fill", color: Theme.textPrimary)
                
                let longestStr = String(format: "%.1f", (longestFast / 3600.0))
                StatCard(title: "LONGEST FAST", value: "\(longestStr)H", icon: "crown.fill", color: Theme.dangerRed)
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
    
    var actualDurationHours: Double {
        let end = fast.endTime ?? fast.startTime
        return end.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var didMeetTarget: Bool {
        actualDurationHours >= Double(fast.targetHours)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(didMeetTarget ? Theme.accent.opacity(0.2) : Theme.warningOrange.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: didMeetTarget ? "checkmark" : "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(didMeetTarget ? Theme.accent : Theme.warningOrange)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("STARTED:")
                            .foregroundColor(Theme.textSecondary)
                        Text(fast.startTime.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    if let endTime = fast.endTime {
                        HStack(spacing: 4) {
                            Text("BROKE:")
                                .foregroundColor(Theme.textSecondary)
                            Text(endTime.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .font(Theme.Typography.technical(12, weight: .bold))
                
                HStack(spacing: 4) {
                    Text("TARGET: \(fast.targetHours)H")
                    Text("•")
                    Text(didMeetTarget ? "ACHIEVED" : "BROKEN EARLY")
                        .foregroundColor(didMeetTarget ? Theme.accent : Theme.warningOrange)
                }
                .font(Theme.Typography.technical(12))
                .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let durationStr = String(format: "%.1f", actualDurationHours)
                Text("\(durationStr)H")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
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
                    
                    Text(phase.title.uppercased())
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(phase.duration)
                        .font(Theme.Typography.technical(14, weight: .bold).monospaced())
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(phase.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .lineSpacing(8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("BIOLOGICAL EFFECTS")
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
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
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
