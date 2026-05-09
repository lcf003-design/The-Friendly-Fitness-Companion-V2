import SwiftUI
import SwiftData
import Combine

struct FastingPhase: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let duration: String
    let icon: String
    let description: String
    let color: Color
    let biologicalEffects: [String]
}

struct FastingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Query private var fasts: [FastingSession]
    
    @State private var currentTime = Date()
    @State private var selectedProtocolHours: Int = 16
    @State private var selectedPhase: FastingPhase?
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
        FastingPhase(title: "Blood Sugar Normalizing", duration: "0 - 4 HRS", icon: "drop.fill", description: "Insulin levels drop and your body begins utilizing circulating glucose.", color: Theme.accent, biologicalEffects: [
            "Insulin secretion halts, allowing fat cells to unlock.",
            "Digestive system processes the last meal.",
            "Circulating glucose is burned for immediate energy."
        ]),
        FastingPhase(title: "Glycogen Depletion", duration: "4 - 12 HRS", icon: "bolt.fill", description: "Your body depletes stored glycogen in the liver and begins transitioning energy sources.", color: Theme.warningOrange, biologicalEffects: [
            "Liver glycogen stores are aggressively drained.",
            "Metabolic switch begins turning on.",
            "Hunger hormones (Ghrelin) peak and then subside."
        ]),
        FastingPhase(title: "Ketosis State", duration: "12 - 16 HRS", icon: "flame.fill", description: "Fat burning mode is unlocked. Your liver begins producing ketones for fuel.", color: .red, biologicalEffects: [
            "Fatty acids are released into the bloodstream.",
            "Liver converts fat into powerful ketone bodies.",
            "Mental clarity sharpens as brain uses ketones."
        ]),
        FastingPhase(title: "Autophagy", duration: "16+ HRS", icon: "allergens.fill", description: "Deep cellular repair begins. Your body starts clearing out damaged cells.", color: .purple, biologicalEffects: [
            "Cellular recycling engine is fully engaged.",
            "Old, damaged proteins are destroyed and rebuilt.",
            "Human Growth Hormone (HGH) skyrockets."
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
    
    var currentPhaseData: (title: String, icon: String, color: Color) {
        if elapsedHours < 4 { return ("Blood Sugar", "drop.fill", Theme.accent) }
        if elapsedHours < 12 { return ("Glycogen", "bolt.fill", Theme.warningOrange) }
        if elapsedHours < 16 { return ("Ketosis", "flame.fill", .red) }
        return ("Autophagy", "allergens.fill", .purple)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        
                        // Infographic Cards (Horizontal Scroll)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PHYSIOLOGICAL PHASES")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<phases.count, id: \.self) { i in
                                        let phase = phases[i]
                                        Button(action: {
                                            selectedPhase = phase
                                        }) {
                                            VStack(alignment: .leading, spacing: 12) {
                                                HStack {
                                                    Image(systemName: phase.icon)
                                                        .font(.title2)
                                                        .foregroundColor(phase.color)
                                                    Spacer()
                                                    Text(phase.duration)
                                                        .font(Theme.Typography.technical(10, weight: .bold))
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                                
                                                Text(phase.title)
                                                    .font(.headline.bold())
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                Text(phase.description)
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .padding()
                                            .frame(width: 220, height: 140, alignment: .topLeading)
                                            .background(Theme.surface)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Theme.border, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Circular Timer HUD
                        ZStack {
                            Circle()
                                .stroke(Theme.border.opacity(0.3), lineWidth: 20)
                                .frame(width: 280, height: 280)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(progress))
                                .stroke(currentPhaseData.color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear, value: progress)
                            
                            VStack(spacing: 12) {
                                Image(systemName: currentPhaseData.icon)
                                    .font(.system(size: 40))
                                    .foregroundColor(currentPhaseData.color)
                                    .symbolEffect(.pulse, options: .repeating, isActive: activeFast != nil)
                                
                                Text(formatTime(elapsedHours * 3600))
                                    .font(.system(size: 48, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                if let fast = activeFast {
                                    Text("TARGET: \(fast.targetHours) HRS")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                } else {
                                    Text("READY TO FAST")
                                        .font(Theme.Typography.technical(12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // Controls
                        if activeFast != nil {
                            Button(action: endFast) {
                                Text("BREAK FAST")
                                    .font(Theme.Typography.technical(16, weight: .bold))
                                    .foregroundColor(Theme.midnightMatte)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(Theme.warningOrange)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 20) {
                                // Protocol Selection Menu
                                Menu {
                                    ForEach(fastingProtocols, id: \.1) { protocolName, hours in
                                        Button(action: { selectedProtocolHours = hours }) {
                                            Text("\(protocolName) (\(hours) HRS)")
                                            if selectedProtocolHours == hours {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "timer")
                                            .foregroundColor(Theme.accent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("SELECTED PROTOCOL")
                                                .font(Theme.Typography.technical(10, weight: .bold))
                                                .foregroundColor(Theme.textSecondary)
                                            
                                            Text(fastingProtocols.first(where: { $0.1 == selectedProtocolHours })?.0 ?? "Custom")
                                                .font(.headline.bold())
                                                .foregroundColor(Theme.textPrimary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(selectedProtocolHours) HRS")
                                            .font(Theme.Typography.technical(14, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .padding(.trailing, 8)
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal)
                                
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
                }
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
            }
            .sheet(item: $selectedPhase) { phase in
                FastingPhaseDetailView(phase: phase)
                    .presentationDetents([.fraction(0.85), .large])
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
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Hero Icon
                        ZStack {
                            Circle()
                                .fill(phase.color.opacity(0.1))
                                .frame(width: 140, height: 140)
                            
                            Image(systemName: phase.icon)
                                .font(.system(size: 60))
                                .foregroundColor(phase.color)
                                .shadow(color: phase.color.opacity(0.5), radius: 20)
                        }
                        .padding(.top, 40)
                        
                        // Title & Duration
                        VStack(spacing: 8) {
                            Text(phase.title.uppercased())
                                .font(Theme.Typography.technical(24, weight: .black))
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text(phase.duration)
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(phase.color)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(phase.color.opacity(0.15))
                                .cornerRadius(8)
                        }
                        
                        // Description
                        Text(phase.description)
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        // Biological Effects
                        VStack(alignment: .leading, spacing: 16) {
                            Text("BIOLOGICAL EFFECTS")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            
                            ForEach(phase.biologicalEffects, id: \.self) { effect in
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(phase.color)
                                        .font(.system(size: 20))
                                    Text(effect)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
}
