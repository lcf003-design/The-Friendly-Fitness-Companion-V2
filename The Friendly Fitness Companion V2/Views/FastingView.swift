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
    
    @State private var currentTime = Date()
    @State private var selectedProtocolHours: Int = 16
    @State private var selectedPhase: FastingPhase?
    
    // Level Up Gamification State
    @State private var showLevelUp: Bool = false
    @State private var levelUpPhase: FastingPhase? = nil
    @State private var trackedPhaseTitle: String = ""
    
    // Hold to Break Fast mechanics
    @State private var holdTimer: Timer?
    @State private var holdProgress: CGFloat = 0.0
    @State private var isHoldingBreak: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
    
    var elapsedHours: Double {
        guard let fast = activeFast else { return 0 }
        return currentTime.timeIntervalSince(fast.startTime) / 3600.0
    }
    
    var progress: Double {
        guard let fast = activeFast else { return 0 }
        return min(elapsedHours / Double(fast.targetHours), 1.0)
    }
    
    var currentPhaseData: FastingPhase {
        if elapsedHours < 4 { return phases[0] }
        if elapsedHours < 12 { return phases[1] }
        if elapsedHours < 16 { return phases[2] }
        return phases[3]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                // Ambient Background Auras
                if activeFast != nil {
                    ZStack {
                        Circle()
                            .fill(currentPhaseData.gradientColors[0].opacity(0.4))
                            .frame(width: 400, height: 400)
                            .blur(radius: 120)
                            .offset(x: -100, y: -200)
                        
                        Circle()
                            .fill(currentPhaseData.gradientColors[1].opacity(0.3))
                            .frame(width: 300, height: 300)
                            .blur(radius: 100)
                            .offset(x: 150, y: 100)
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 2.0), value: currentPhaseData.id)
                }
                
                ScrollView {
                    VStack(spacing: 30) {
                        infographicCardsView
                            .padding(.top, 20)
                        
                        timerHUDView
                            .padding(.vertical, 20)
                        
                        controlsView
                    }
                }
            }
            .onAppear {
                trackedPhaseTitle = currentPhaseData.title
            }
            .onChange(of: currentPhaseData.title) { oldValue, newValue in
                // Only trigger if we are actively fasting, the title actually changed, and we have an initial tracked title
                if activeFast != nil && !trackedPhaseTitle.isEmpty && trackedPhaseTitle != newValue {
                    triggerLevelUp(newPhase: currentPhaseData)
                }
                trackedPhaseTitle = newValue
            }
            .overlay(
                Group {
                    if showLevelUp, let phase = levelUpPhase {
                        ZStack {
                            // Full screen color flash
                            phase.color.opacity(0.9)
                                .ignoresSafeArea()
                                .background(.ultraThinMaterial)
                            
                            VStack(spacing: 24) {
                                Image(systemName: phase.icon)
                                    .font(.system(size: 80))
                                    .foregroundColor(.white)
                                    .shadow(color: .white.opacity(0.8), radius: 30, x: 0, y: 0)
                                    .scaleEffect(showLevelUp ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: showLevelUp)
                                
                                VStack(spacing: 8) {
                                    Text("PHASE UNLOCKED")
                                        .font(Theme.Typography.technical(16, weight: .black))
                                        .foregroundColor(.white.opacity(0.8))
                                        .tracking(4)
                                    
                                    Text(phase.title.uppercased())
                                        .font(.system(size: 36, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                                }
                                .offset(y: showLevelUp ? 0 : 20)
                                .opacity(showLevelUp ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.2), value: showLevelUp)
                            }
                        }
                        .transition(.opacity)
                        .zIndex(100)
                    }
                }
            )
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
            }
            .sheet(item: $selectedPhase) { phase in
                FastingPhaseDetailView(phase: phase)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(timer) { time in
                if activeFast != nil {
                    currentTime = time
                }
            }
            .onAppear {
                currentTime = Date()
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
                        let isActivePhase: Bool = (activeFast != nil) && (phase.id == currentPhaseData.id)
                        
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            selectedPhase = phase
                        }) {
                            ZStack(alignment: .topLeading) {
                                // 1. Living Fluid Background
                                AnimatedFluidBackground(colors: phase.gradientColors)
                                
                                // 2. Massive Watermark Icon (Breathing)
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
                                
                                // 3. Content with Glassmorphism
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
                                }
                                .padding()
                            }
                            .frame(width: 260, height: 160)
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
                .padding(.vertical, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    private var timerHUDView: some View {
        ZStack {
            // Recessed dial track
            Circle()
                .stroke(Theme.border.opacity(0.2), lineWidth: 20)
                .frame(width: 280, height: 280)
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5) // Inner shadow effect
            
            // Angular Gradient Progress
            let colors = activeFast != nil ? currentPhaseData.gradientColors : [Theme.textSecondary, Theme.border]
            
            // CoreMotion Liquid Sphere
            ZStack {
                Circle()
                    .fill(.black.opacity(0.5)) // Deep recess background
                
                LiquidSphereView(progress: activeFast != nil ? progress : 0.0, colors: colors)
                    .opacity(0.85)
            }
            .frame(width: 260, height: 260)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.8), radius: 15, x: 0, y: 10)
            
            // Glass Rim
            Circle()
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.4), .clear, .black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 4
                )
                .frame(width: 260, height: 260)
            
            VStack(spacing: 8) {
                if let fast = activeFast {
                    Image(systemName: currentPhaseData.icon)
                        .font(.system(size: 32))
                        .foregroundColor(currentPhaseData.color)
                        .symbolEffect(.pulse, options: .repeating, isActive: true)
                        .shadow(color: currentPhaseData.color.opacity(0.6), radius: 10)
                        .padding(.bottom, 4)
                    
                    Text(formatTime(elapsedHours * 3600))
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 6, x: 0, y: 2)
                    
                    Text("TARGET: \(fast.targetHours) HRS")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.bottom, 4)
                    
                    Text("READY")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("SELECT PROTOCOL")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var controlsView: some View {
        if activeFast != nil {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.dangerRed.opacity(0.5), lineWidth: 1)
                    )
                
                // Fill progress
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.dangerRed)
                        .frame(width: geo.size.width * holdProgress)
                        .animation(.linear(duration: isHoldingBreak ? 2.0 : 0.2), value: holdProgress)
                }
                
                // Text Overlay
                HStack {
                    Spacer()
                    Text(isHoldingBreak ? "HOLDING..." : "HOLD TO BREAK FAST")
                        .font(Theme.Typography.technical(16, weight: .bold))
                        .foregroundColor(isHoldingBreak ? .white : Theme.dangerRed)
                        .animation(.none, value: isHoldingBreak)
                    Spacer()
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHoldingBreak {
                            isHoldingBreak = true
                            HapticManager.shared.playLightImpact()
                            withAnimation(.linear(duration: 2.0)) {
                                holdProgress = 1.0
                            }
                            holdTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                HapticManager.shared.playPR() // Big success haptic
                                endFast()
                                holdProgress = 0.0
                                isHoldingBreak = false
                            }
                        }
                    }
                    .onEnded { _ in
                        if isHoldingBreak {
                            holdTimer?.invalidate()
                            holdTimer = nil
                            withAnimation(.easeOut(duration: 0.3)) {
                                holdProgress = 0.0
                            }
                            isHoldingBreak = false
                        }
                    }
            )
            .padding(.horizontal)
        } else {
            VStack(spacing: 20) {
                // Mechanical Vault Selector
                VStack(spacing: 12) {
                    Text("SET FASTING PROTOCOL")
                        .font(Theme.Typography.technical(12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(2)
                    
                    ZStack {
                        // Vault Housing
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.black.opacity(0.4))
                        
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                        
                        // The Spinning Wheel
                        Picker("Protocol", selection: $selectedProtocolHours) {
                            ForEach(fastingProtocols, id: \.1) { protocolName, hours in
                                Text("\(hours) HRS — \(protocolName)")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .tag(hours)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 160)
                        .onChange(of: selectedProtocolHours, initial: false) { oldValue, newValue in
                            HapticManager.shared.playSelection()
                        }
                    }
                    .frame(height: 160)
                    .padding(.horizontal)
                }
                
                // Start Button
                Button(action: { startFast(hours: selectedProtocolHours) }) {
                    Text("INITIATE PROTOCOL")
                        .font(Theme.Typography.technical(16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Theme.accent)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func startFast(hours: Int) {
        let fast = FastingSession(targetHours: hours)
        modelContext.insert(fast)
        try? modelContext.save()
        currentTime = Date()
    }
    
    private func endFast() {
        if let fast = activeFast {
            fast.isCompleted = true
            try? modelContext.save()
        }
    }
    
    private func formatTime(_ totalSeconds: Double) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Level Up Logic
    private func triggerLevelUp(newPhase: FastingPhase) {
        levelUpPhase = newPhase
        
        // Massive Gamified Haptics
        HapticManager.shared.playSuccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            HapticManager.shared.playHeavyImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticManager.shared.playHeavyImpact()
        }
        
        // Show Animation
        withAnimation(.easeIn(duration: 0.2)) {
            showLevelUp = true
        }
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                showLevelUp = false
            }
        }
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self])
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
            
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(colors.last ?? .white)
                        .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                        .blur(radius: geo.size.width * 0.3)
                        .offset(x: isAnimating ? -geo.size.width * 0.2 : geo.size.width * 0.2,
                                y: isAnimating ? -geo.size.height * 0.2 : geo.size.height * 0.2)
                    
                    Circle()
                        .fill(colors.first ?? .white)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .blur(radius: geo.size.width * 0.25)
                        .offset(x: isAnimating ? geo.size.width * 0.3 : -geo.size.width * 0.3,
                                y: isAnimating ? geo.size.height * 0.3 : -geo.size.height * 0.3)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }
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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // The Liquid Wave
                WaveShape(progress: CGFloat(progress), waveHeight: 8, phase: phase)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                    )
                    // The liquid sloshes physically based on device roll
                    .rotationEffect(.radians(-motion.roll * 0.8))
                    // The liquid subtly stretches/squashes based on device pitch for 3D feel
                    .scaleEffect(x: 1.0, y: 1.0 + CGFloat(abs(motion.pitch)) * 0.1)
            }
            .clipShape(Circle())
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
