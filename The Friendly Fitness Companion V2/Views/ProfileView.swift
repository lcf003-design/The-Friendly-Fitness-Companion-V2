import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var settingsQuery: [UserSettings]
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
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    let phases = ["Hypertrophy", "Strength", "Cutting", "Recomp"]
    
    private var settings: UserSettings? {
        settingsQuery.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Avatar Header
                        VStack(spacing: 16) {
                            Circle()
                                .fill(Theme.surface)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(settings?.userName.prefix(1).uppercased() ?? "M")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                )
                                .shadow(color: Theme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            if isEditing {
                                TextField("Enter Name", text: $draftName)
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Theme.surface)
                                    .cornerRadius(8)
                            } else {
                                Text(settings?.userName ?? "Athlete")
                                    .font(.title.bold())
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Scouting Report Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SCOUTING REPORT")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                BiometricCard(title: "BODY WEIGHT", value: String(format: "%.1f", settings?.bodyWeight ?? 0), unit: "lbs", isEditing: isEditing, text: $draftWeight, keyboardType: .decimalPad)
                                
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
                                } else {
                                    Text(settings?.currentPhase ?? "Hypertrophy")
                                        .font(.headline)
                                        .foregroundColor(Theme.accent)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
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
                }
            }
            .navigationTitle("Me")
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
        }
    }
    
    private func startEditing() {
        draftName = settings?.userName ?? ""
        draftWeight = String(settings?.bodyWeight ?? 0)
        draftBodyFat = String(settings?.bodyFatPercentage ?? 0)
        draftHeight = String(settings?.heightInches ?? 0)
        draftAge = String(settings?.trainingAgeYears ?? 0)
        draftPhase = settings?.currentPhase ?? "Hypertrophy"
        isEditing = true
    }
    
    private func saveProfile() {
        if let currentSettings = settings {
            currentSettings.userName = draftName
            if let weight = Double(draftWeight) { currentSettings.bodyWeight = weight }
            if let fat = Double(draftBodyFat) { currentSettings.bodyFatPercentage = fat }
            if let height = Int(draftHeight) { currentSettings.heightInches = height }
            if let age = Int(draftAge) { currentSettings.trainingAgeYears = age }
            currentSettings.currentPhase = draftPhase
        }
        try? modelContext.save()
        isEditing = false
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

#Preview {
    ProfileView()
        .modelContainer(for: [Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self], inMemory: true)
}
