import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var settings: UserSettings
    
    @Query private var allSessions: [WorkoutSession]
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var isShowingHelp = false
    
    let tempoOptions = [
        "Mentzer HIT (4-2-4)",
        "Standard Hypertrophy (3-1-3)",
        "Explosive Power (2-0-1)",
        "Isometrics (1-4-1)"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Section: Grind Engine
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Workout Engine")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                // Rest Timer Toggle
                                Toggle("Automated Rest Timer", isOn: $settings.isRestTimerEnabled)
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding()
                                    .background(Theme.surface)
                                    .tint(Theme.warningOrange)
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                // Haptic Metronome Toggle
                                Toggle("Haptic Metronome", isOn: $settings.isHapticMetronomeEnabled)
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding()
                                    .background(Theme.surface)
                                    .tint(Theme.accent)
                                
                                if settings.isHapticMetronomeEnabled {
                                    Divider().background(Theme.border.opacity(0.3))
                                    
                                    // Tempo Picker
                                    HStack {
                                        Text("Tempo Profile")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                        Picker("Tempo Profile", selection: $settings.tempoProfile) {
                                            ForEach(tempoOptions, id: \.self) { tempo in
                                                Text(tempo).tag(tempo)
                                            }
                                        }
                                        .tint(Theme.accent)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                }
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                // Ghost Target Picker
                                HStack {
                                    Text("Ghost Target")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Picker("Ghost Target", selection: $settings.ghostTrackingPreference) {
                                        Text("Most Recent").tag(0)
                                        Text("All-Time PR").tag(1)
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.accent)
                                }
                                .padding()
                                .background(Theme.surface)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Section: Ecosystem
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ecosystem Sync")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                // HealthKit Toggle
                                Toggle("Sync to Apple Health", isOn: $settings.isHealthKitSyncEnabled)
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding()
                                    .background(Theme.surface)
                                    .tint(Theme.accent)
                                    .onChange(of: settings.isHealthKitSyncEnabled) {
                                        if settings.isHealthKitSyncEnabled {
                                            HealthKitManager.shared.requestAuthorization { success, _ in
                                                DispatchQueue.main.async {
                                                    if !success {
                                                        settings.isHealthKitSyncEnabled = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                // Theme Override
                                HStack {
                                    Text("Appearance")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Picker("Theme", selection: $settings.themePreference) {
                                        Text("System").tag(0)
                                        Text("Light").tag(1)
                                        Text("Dark").tag(2)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 200)
                                }
                                .padding()
                                .background(Theme.surface)
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                // Weight Unit Selection
                                HStack {
                                    Text("Weight Unit")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Picker("Weight Unit", selection: $settings.weightUnit) {
                                        Text("lbs").tag("lb")
                                        Text("kg").tag("kg")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 150)
                                    .onChange(of: settings.weightUnit) { oldValue, newValue in
                                        if newValue == "kg" {
                                            settings.bodyWeight = (settings.bodyWeight * 0.45359237).rounded(to: 1)
                                            settings.barbellWeight = 20.0
                                            settings.barbellType = "Olympic Bar (20 kg)"
                                            settings.availablePlatesCSV = "25,20,15,10,5,2.5,1.25"
                                        } else if newValue == "lb" {
                                            settings.bodyWeight = (settings.bodyWeight / 0.45359237).rounded(to: 1)
                                            settings.barbellWeight = 45.0
                                            settings.barbellType = "Olympic Bar (45 lb)"
                                            settings.availablePlatesCSV = "45,35,25,10,5,2.5"
                                        }
                                        try? modelContext.save()
                                    }
                                }
                                .padding()
                                .background(Theme.surface)
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                // Exercise Vault Button
                                NavigationLink(destination: ExerciseManagerView()) {
                                    HStack {
                                        Image(systemName: "archivebox.fill")
                                            .foregroundColor(Theme.accent)
                                        Text("The Exercise Vault")
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                }
                                
                                Divider().background(Theme.border.opacity(0.3))
                                
                                // Barbell & Plate Inventory Studio Button
                                NavigationLink(destination: PlateInventoryStudioView(settings: settings)) {
                                    HStack {
                                        Image(systemName: "dumbbell.fill")
                                            .foregroundColor(Theme.warningOrange)
                                        Text("Barbell & Plates Studio")
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Section: Data Management
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Management")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                Button(action: {
                                    if let url = ExportService.shared.generateCSV(sessions: allSessions) {
                                        exportedURL = url
                                        showShareSheet = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(Theme.accent)
                                        Text("Export Workout History (CSV)")
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Command Settings")
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
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $isShowingHelp) {
            SettingsHelpView()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

// ShareSheet Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}




#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self, FastingLogEntry.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let dummySettings = UserSettings()
    container.mainContext.insert(dummySettings)
    
    return SettingsView(settings: dummySettings)
        .modelContainer(container)
}
