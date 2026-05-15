import SwiftUI
import SwiftData
import Combine

struct FastingPhase: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let duration: String
    let icon: String
    let description: String
    let shortDescription: String
    let color: Color
    let gradientColors: [Color]
    let biologicalEffects: [String]
}

struct FastingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Query private var fasts: [FastingSession]
    @State private var selectedPhase: FastingPhase?
    @State private var isShowingHistory: Bool = false
    @State private var selectedProtocolHours: Int = 16
    
    // Cooldown State
    @State private var justFinishedFasting: Bool = false
    
    let fastingProtocols = [
        ("Circadian Rhythm", 13),
        ("16:8 (Leangains)", 16),
        ("18:6 Protocol", 18),
        ("20:4 (Warrior Diet)", 20),
        ("OMAD (One Meal a Day)", 23),
        ("Monk Fast", 36),
        ("Dopamine Reset", 48),
        ("Autophagy Max", 72)
    ]
    
    // Infographic Data
    let phases = [
        FastingPhase(title: "Sugar Burner", duration: "0 - 4 HRS", icon: "drop.fill", description: "Your body is sweeping up the remaining glucose in your bloodstream. The fat-burning gates are preparing to open.", shortDescription: "Insulin drops. Fat-burning gates prepare to open.", color: Theme.accent, gradientColors: [Color(red: 0.0, green: 0.15, blue: 0.4), Color.cyan], biologicalEffects: [
            "Insulin plummets, signaling fat cells to unlock.",
            "Blood sugar stabilizes, crushing mid-day cravings.",
            "The digestive factory finally clocks out for a break."
        ]),
        FastingPhase(title: "Glycogen Drain", duration: "4 - 12 HRS", icon: "bolt.fill", description: "Your liver is running on empty! As stored carbs vanish, your metabolism starts hunting for its next fuel source: your fat reserves.", shortDescription: "Liver runs empty. Metabolism hunts for fat.", color: Theme.warningOrange, gradientColors: [Color(red: 0.5, green: 0.1, blue: 0.0), Color.orange], biologicalEffects: [
            "Liver glycogen is aggressively depleted.",
            "The metabolic switch starts flipping to fat-burning mode.",
            "Hunger hormones peak and then completely surrender."
        ]),
        FastingPhase(title: "Ketosis Ignited", duration: "12 - 16 HRS", icon: "flame.fill", description: "Welcome to the fat-burning furnace. Your liver is now actively converting stubborn fat into high-octane ketone energy.", shortDescription: "Welcome to the fat-burning furnace.", color: .red, gradientColors: [Color(red: 0.4, green: 0.0, blue: 0.1), Color.red], biologicalEffects: [
            "Fat cells dump fatty acids directly into your bloodstream.",
            "Ketones flood your brain, unlocking laser-sharp focus.",
            "Stubborn fat is officially being used for fuel."
        ]),
        FastingPhase(title: "Deep Autophagy", duration: "16+ HRS", icon: "allergens.fill", description: "Cellular spring cleaning is in full effect. Your body is ruthlessly hunting down and recycling old, damaged cells to build a younger, stronger you.", shortDescription: "Cellular recycling engine roars to life.", color: .purple, gradientColors: [Color(red: 0.25, green: 0.0, blue: 0.4), Color.purple], biologicalEffects: [
            "The ultimate cellular recycling engine roars to life.",
            "Old proteins are destroyed and rebuilt from scratch.",
            "Anti-aging Human Growth Hormone (HGH) skyrockets."
        ])
    ]
    
    var activeFast: FastingSession? {
        fasts.first { !$0.isCompleted }
    }
    
    private func staticPhase(for fast: FastingSession?) -> FastingPhase {
        guard let f = fast else { return phases[0] }
        let hours = Date().timeIntervalSince(f.startTime) / 3600.0
        if hours < 4 { return phases[0] }
        if hours < 12 { return phases[1] }
        if hours < 16 { return phases[2] }
        return phases[3]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                // Auras handled in IsolatedTimerHUD
                
                VStack(spacing: 20) {
                    infographicCardsView
                        .frame(height: 220)
                    
                    timerHUDView
                        .frame(height: 350)
                    
                    controlsView
                        .padding(.bottom, 10)
                }
                .padding(.top, 20)
            }
            .navigationTitle("The Fasting Toolbox")
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
            .sheet(item: $selectedPhase) { phase in
                FastingPhaseDetailView(phase: phase)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingHistory) {
                FastingHistoryView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var infographicCardsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHYSIOLOGICAL PHASES")
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(phases, id: \.id) { phase in
                        let isActivePhase: Bool = (activeFast != nil) && (phase.id == staticPhase(for: activeFast).id)
                        
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
                                    
                                    Text(phase.shortDescription)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineSpacing(4)
                                        .foregroundColor(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                Spacer(minLength: 0) // Push everything to top
                            }
                            .padding()
                            .frame(width: 240, height: 200, alignment: .topLeading)
                            .background(
                                ZStack {
                                    Color.clear.background(.ultraThinMaterial) // Glassmorphism
                                    AnimatedFluidBackground(colors: phase.gradientColors)
                                    
                                    // Massive Watermark Icon
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
                            .scaleEffect(isActivePhase ? 1.05 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isActivePhase)
                        }
                        .buttonStyle(FastingCardPressStyle())
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                                .rotation3DEffect(
                                    .degrees(phase.value * -15),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.5
                                )
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
            }
            .frame(height: 220) // Fixed height prevents scaleEffect from bouncing the entire UI vertically
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // Removed legacy timerHUDView
    // MARK: - Timer HUD View (Isolated)
    @ViewBuilder
    private var timerHUDView: some View {
        IsolatedTimerHUD(
            fast: activeFast,
            targetHours: selectedProtocolHours,
            phases: phases,
            onStartFast: {
                HapticManager.shared.playSuccess()
                startFast(hours: selectedProtocolHours)
            },
            onEndFast: {
                endFast()
            }
        )
    }
    
    @ViewBuilder
    private var controlsView: some View {
        VStack(spacing: 20) {
                // Mechanical Vault Selector
                VStack(spacing: 12) {
                    Text("SET FASTING PROTOCOL")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(2)
                    
                    Menu {
                        Picker("Protocol", selection: $selectedProtocolHours) {
                            ForEach(fastingProtocols, id: \.1) { protocolName, hours in
                                Text("\(hours) HRS — \(protocolName)")
                                    .tag(hours)
                            }
                        }
                    } label: {
                        HStack {
                            let selectedName = fastingProtocols.first(where: { $0.1 == selectedProtocolHours })?.0 ?? ""
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(selectedProtocolHours) HOURS")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text(selectedName)
                                    .font(Theme.Typography.technical(14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedProtocolHours, initial: false) { oldValue, newValue in
                        HapticManager.shared.playSelection()
                    }
                }
            }
        .opacity(activeFast == nil ? 1.0 : 0.0)
        .disabled(activeFast != nil)
        .animation(.easeInOut, value: activeFast != nil)
    }
    
    private func startFast(hours: Int) {
        let fast = FastingSession(targetHours: hours)
        modelContext.insert(fast)
        try? modelContext.save()
    }
    
    private func endFast() {
        if let fast = activeFast {
            fast.isCompleted = true
            fast.endTime = Date()
            
            // Phase 8 Biometric Sync: Log Deep Autophagy Insights
            let durationHours = Date().timeIntervalSince(fast.startTime) / 3600.0
            if durationHours >= 16.0 {
                let note = "DEEP AUTOPHAGY REACHED: \(String(format: "%.1f", durationHours)) HRS. Training intensity parameters may be naturally adjusted for recovery."
                let bioLog = BiometricLog(notes: note)
                modelContext.insert(bioLog)
            }
            
            try? modelContext.save()
        }
    }
    
    private func formatTime(_ totalSeconds: Double) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    // Function moved to IsolatedTimerHUD
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return FastingView(isPresented: .constant(true))
        .modelContainer(container)
}

struct FastingPhaseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let phase: FastingPhase
    
    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: 30) {
                        // Hero Icon
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                            
                            Image(systemName: phase.icon)
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 10)
                        }
                        .padding(.top, 40)
                        
                        // Title & Duration
                        VStack(spacing: 8) {
                            Text(phase.title.uppercased())
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .tracking(2.0)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                            
                            Text(phase.duration)
                                .font(Theme.Typography.technical(14, weight: .bold).monospaced())
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        
                        // Description
                        Text(phase.description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .lineSpacing(8)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        
                        // Biological Effects
                        VStack(alignment: .leading, spacing: 16) {
                            Text("BIOLOGICAL EFFECTS")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(4.0)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            ForEach(Array(phase.biologicalEffects.enumerated()), id: \.element) { index, effect in
                                HStack(alignment: .top, spacing: 16) {
                                    // Premium Numbered Node
                                    ZStack {
                                        Circle()
                                            .fill(.black.opacity(0.4))
                                            .frame(width: 36, height: 36)
                                        
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 13, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Text(effect)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.95))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(6)
                                        .padding(.top, 8)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.black.opacity(0.25))
                                        .background(.ultraThinMaterial)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 40)
                }
            .background(
                ZStack {
                    // 1. Living Fluid Background
                    AnimatedFluidBackground(colors: phase.gradientColors)
                    
                    // 2. Massive Watermark Icon (Breathing)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: phase.icon)
                                .font(.system(size: 350))
                                .foregroundColor(.black.opacity(0.15))
                                .rotationEffect(.degrees(15))
                                .symbolEffect(.pulse, options: .repeating, isActive: true)
                                .offset(x: 100, y: 50)
                        }
                    }
                }
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
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

struct FastingCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AnimatedFluidBackground: View {
    let colors: [Color]
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            ZStack {
                Circle()
                    .fill(colors.last ?? .white)
                    .frame(width: 280, height: 280)
                    .blur(radius: 50)
                    .offset(x: isAnimating ? -40 : 40,
                            y: isAnimating ? -40 : 40)
                
                Circle()
                    .fill(colors.first ?? .white)
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: isAnimating ? 60 : -60,
                            y: isAnimating ? 60 : -60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct WaveShape: Shape {
    var progress: CGFloat
    var waveHeight: CGFloat
    var phase: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let fillY = rect.height * (1.0 - progress)
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: fillY))
        
        let frequency: CGFloat = 1.5
        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / rect.width
            let y = fillY + sin(relativeX * .pi * 2 * frequency + phase) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct LiquidSphereView: View {
    var progress: Double
    var colors: [Color]
    @StateObject private var motion = MotionManager.shared
    @State private var phase: CGFloat = 0.0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // The Liquid Wave
            WaveShape(progress: CGFloat(progress), waveHeight: 8, phase: phase)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                    )
                    // The liquid sloshes physically based on device roll
                .rotationEffect(.radians(-motion.roll * 0.8))
        }
        .clipShape(Circle())
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Fasting History
struct FastingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Sort completed fasts by most recent first
    @Query(filter: #Predicate<FastingSession> { $0.isCompleted }, sort: \FastingSession.startTime, order: .reverse)
    private var fasts: [FastingSession]
    
    // Derived Statistics
    private var totalFasts: Int {
        fasts.count
    }
    
    private var averageDuration: Double {
        guard !fasts.isEmpty else { return 0 }
        let totalDuration = fasts.reduce(0) { sum, fast in
            let end = fast.endTime ?? fast.startTime // Fallback if old data doesn't have endTime
            return sum + end.timeIntervalSince(fast.startTime)
        }
        return (totalDuration / Double(fasts.count)) / 3600.0
    }
    
    private var longestFast: Double {
        fasts.map { fast in
            let end = fast.endTime ?? fast.startTime
            return end.timeIntervalSince(fast.startTime)
        }.max() ?? 0.0
    }
    
    private var currentStreak: Int {
        guard !fasts.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        let currentDate = calendar.startOfDay(for: Date())
        
        // Find fasts for each day going backwards
        for i in 0..<365 { // Cap at a year to avoid infinite loops if data is weird
            let targetDate = calendar.date(byAdding: .day, value: -i, to: currentDate)!
            
            let hasFastOnDay = fasts.contains { fast in
                calendar.isDate(fast.startTime, inSameDayAs: targetDate) ||
                calendar.isDate(fast.endTime ?? fast.startTime, inSameDayAs: targetDate)
            }
            
            if hasFastOnDay {
                streak += 1
            } else {
                // If it's today and they haven't fasted yet, don't break the streak immediately
                if i == 0 { continue }
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
                            // Statistics Header
                            statisticsHeader
                                .padding(.top, 20)
                            
                            // History Ledger
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
                                            // Swipe to delete implemented via context menu since LazyVStack doesn't natively support swipe actions like List does without heavy wrappers
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
            // Top Row
            HStack(spacing: 16) {
                StatCard(title: "TOTAL FASTS", value: "\(totalFasts)", icon: "checkmark.circle.fill", color: Theme.accent)
                StatCard(title: "STREAK", value: "\(currentStreak) DAYS", icon: "flame.fill", color: Theme.warningOrange)
            }
            .padding(.horizontal)
            
            // Bottom Row
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
            // Status Icon
            ZStack {
                Circle()
                    .fill(didMeetTarget ? Theme.accent.opacity(0.2) : Theme.warningOrange.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: didMeetTarget ? "checkmark" : "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(didMeetTarget ? Theme.accent : Theme.warningOrange)
            }
            
            // Details
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
            
            // Actual Duration
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

// MARK: - Isolated Timer HUD Component
struct IsolatedTimerHUD: View {
    let fast: FastingSession?
    let targetHours: Int
    let phases: [FastingPhase]
    let onStartFast: () -> Void
    let onEndFast: () -> Void
    
    @State private var currentTime = Date()
    @State private var holdTimer: Timer?
    @State private var holdProgress: CGFloat = 0.0
    @State private var isHoldingBreak: Bool = false
    @State private var justFinishedFasting: Bool = false
    
    // Level Up State
    @State private var showLevelUp: Bool = false
    @State private var levelUpPhase: FastingPhase? = nil
    @State private var trackedPhaseTitle: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var elapsedHours: Double {
        guard let fast = fast else { return 0 }
        return currentTime.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var progress: Double {
        guard let fast = fast else { return 0 }
        return min(elapsedHours / Double(fast.targetHours), 1.0)
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
            // Autophagy Engine HUD - Dynamic Circular Progress Ring
            if fast != nil {
                Circle()
                    .stroke(Theme.border.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 250, height: 250)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(currentPhaseData.gradientColors.last ?? Theme.warningOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 250, height: 250)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: progress)
                    .shadow(color: currentPhaseData.gradientColors.last?.opacity(0.6) ?? Theme.warningOrange.opacity(0.6), radius: 8)
            }
            
            // Core Sphere
            ZStack {
                Circle()
                    .fill(Theme.midnightMatte)
                
                LiquidSphereView(progress: fast != nil ? progress : 0.0, colors: fast != nil ? currentPhaseData.gradientColors : [Theme.surface, Theme.border])
                    .opacity(0.85)
            }
            .frame(width: 220, height: 220)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.8), radius: 15, x: 0, y: 10)
            
            VStack(spacing: 8) {
                if let active = fast {
                    Text(currentPhaseData.title.uppercased())
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(currentPhaseData.color)
                        .tracking(2)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                    
                    Text(formatTime(elapsedHours * 3600))
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 6, x: 0, y: 2)
                        .monospacedDigit()
                    
                    Text("TARGET: \(active.targetHours) HRS")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                    if isHoldingBreak {
                        Text("HOLDING TO BREAK...")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.dangerRed)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)
                            .padding(.top, 4)
                    }
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.bottom, 4)
                    
                    Text("TAP TO START")
                        .font(Theme.Typography.technical(28, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("READY")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .overlay(
            Group {
                if fast != nil && holdProgress > 0 {
                    // Circular fill follows the Progress Ring
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(Theme.dangerRed, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .frame(width: 250, height: 250) // Match the 250 width of the outer ring
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: isHoldingBreak ? 2.0 : 0.2), value: holdProgress)
                        .shadow(color: Theme.dangerRed, radius: 10)
                }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if fast != nil {
                        if !isHoldingBreak {
                            isHoldingBreak = true
                            HapticManager.shared.playLightImpact()
                            withAnimation(.linear(duration: 2.0)) {
                                holdProgress = 1.0
                            }
                            holdTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                justFinishedFasting = true
                                onEndFast()
                                holdProgress = 0.0
                                isHoldingBreak = false
                            }
                        }
                    }
                }
                .onEnded { _ in
                    if justFinishedFasting {
                        justFinishedFasting = false
                        return
                    }
                    if fast == nil {
                        onStartFast()
                    } else {
                        if isHoldingBreak {
                            isHoldingBreak = false
                            holdTimer?.invalidate()
                            holdTimer = nil
                            withAnimation(.easeOut(duration: 0.2)) {
                                holdProgress = 0.0
                            }
                        }
                    }
                }
        )
        .onReceive(timer) { input in
            currentTime = input
        }
    }
}
