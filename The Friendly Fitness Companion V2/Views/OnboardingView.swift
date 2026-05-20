import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @Binding var isPresented: Bool
    
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var weightString = ""
    @State private var isKg = false
    @State private var selectedPhase = "Hypertrophy"
    @State private var useRestTimer = true
    @State private var useMetronome = false
    
    let phases = ["Hypertrophy", "Strength", "Cutting", "Recomp"]
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            VStack {
                // Progress Indicator
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Rectangle()
                            .fill(index <= currentStep ? Theme.accent : Theme.surface)
                            .frame(height: 4)
                            .cornerRadius(2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Paged Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    identityStep.tag(1)
                    objectiveStep.tag(2)
                    hapticsStep.tag(3)
                    healthKitStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                Spacer()
                
                // Navigation Footer
                HStack {
                    if currentStep > 0 {
                        Button("BACK") {
                            withAnimation { currentStep -= 1 }
                        }
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        if currentStep < 4 {
                            withAnimation { currentStep += 1 }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentStep == 4 ? "INITIALIZE SYSTEM" : "NEXT")
                            .font(Theme.Typography.technical(14, weight: .bold))
                            .foregroundColor(Theme.midnightMatte)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .background(Theme.accent)
                            .cornerRadius(12)
                            .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(currentStep == 1 && (userName.isEmpty || weightString.isEmpty))
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Steps
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.warningOrange)
                .shadow(color: Theme.warningOrange.opacity(0.5), radius: 20)
                .padding(.bottom, 20)
            
            Text("THE COMMAND CENTER")
                .font(Theme.Typography.technical(24, weight: .black))
                .foregroundColor(Theme.textPrimary)
                .tracking(2)
            
            Text("Welcome to your new operating system. We have stripped away the noise so you can focus entirely on the iron. Let's configure your baseline.")
                .font(Theme.Typography.technical(16))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)
        }
        .padding()
    }
    
    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("OPERATOR DESIGNATION")
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .tracking(1)
                
                TextField("Your Name", text: $userName)
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT MASS")
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .tracking(1)
                
                HStack {
                    TextField("Weight", text: $weightString)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)
                    
                    Button(action: { isKg.toggle() }) {
                        Text(isKg ? "KG" : "LB")
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .foregroundColor(Theme.midnightMatte)
                            .frame(width: 60)
                            .padding(.vertical, 16)
                            .background(Theme.textPrimary)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(32)
    }
    
    private var objectiveStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("PRIMARY DIRECTIVE")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.accent)
                .tracking(1)
                .padding(.horizontal, 32)
            
            Text("Select your current training phase. This determines your baseline macro targets.")
                .font(Theme.Typography.technical(14))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 32)
            
            VStack(spacing: 16) {
                ForEach(phases, id: \.self) { phase in
                    Button(action: { selectedPhase = phase }) {
                        HStack {
                            Text(phase.uppercased())
                                .font(Theme.Typography.technical(16, weight: .bold))
                                .foregroundColor(selectedPhase == phase ? Theme.midnightMatte : Theme.textPrimary)
                            Spacer()
                            if selectedPhase == phase {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.midnightMatte)
                            }
                        }
                        .padding()
                        .background(selectedPhase == phase ? Theme.accent : Theme.surface)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
    }
    
    private var hapticsStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("GRIND ENGINE CONFIG")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.warningOrange)
                .tracking(1)
            
            Text("This app relies heavily on physical haptics to guide your intensity without requiring you to stare at the screen.")
                .font(Theme.Typography.technical(14))
                .foregroundColor(Theme.textSecondary)
            
            VStack(spacing: 24) {
                Toggle(isOn: $useRestTimer) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto Rest Timer")
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("Automatically starts a 120s timer after you log a set.")
                            .font(Theme.Typography.technical(12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .tint(Theme.warningOrange)
                
                Toggle(isOn: $useMetronome) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Haptic Metronome")
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("Pulses your phone physically to guide rep tempo (e.g. 4 seconds down).")
                            .font(Theme.Typography.technical(12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .tint(Theme.warningOrange)
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(16)
        }
        .padding(32)
    }
    
    private var healthKitStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("SYSTEMS INTEGRATION")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.apexGreen)
                .tracking(1)
            
            Text("Authorize Apple Health to automatically sync your intensity scores and heavy sets directly to your Fitness rings.")
                .font(Theme.Typography.technical(14))
                .foregroundColor(Theme.textSecondary)
            
            VStack(spacing: 24) {
                Button(action: {
                    HealthKitManager.shared.requestAuthorization { success, error in
                        if success {
                            HapticManager.shared.playSuccess()
                        } else {
                            HapticManager.shared.playHeavyImpact()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                        Text("Connect to Apple Health")
                            .font(Theme.Typography.technical(16, weight: .bold))
                    }
                    .foregroundColor(Theme.midnightMatte)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.apexGreen)
                    .cornerRadius(12)
                }
                
                Text("This allows the app to write 'Traditional Strength Training' workouts and estimate Active Calories Burned.")
                    .font(Theme.Typography.technical(12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(16)
        }
        .padding(32)
    }
    
    // MARK: - Completion
    
    private func completeOnboarding() {
        guard let settings = userSettings.first else { return }
        
        settings.userName = userName
        settings.bodyWeight = Double(weightString) ?? 0.0
        settings.weightUnit = isKg ? "kg" : "lb"
        settings.currentPhase = selectedPhase
        settings.isRestTimerEnabled = useRestTimer
        settings.isHapticMetronomeEnabled = useMetronome
        settings.isHealthKitSyncEnabled = HealthKitManager.shared.isAvailable // Auto enable if requested
        settings.isOnboarded = true
        
        try? modelContext.save()
        HapticManager.shared.playHeavyImpact()
        isPresented = false
    }
}
