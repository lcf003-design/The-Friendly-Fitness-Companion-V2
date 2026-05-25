import SwiftUI
import SwiftData

struct QuickBiometricLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var userSettings: [UserSettings]
    
    @State private var weightString = ""
    @State private var bodyFatString = ""
    @State private var noteString = ""
    
    private var unit: String {
        userSettings.first?.weightUnit ?? "lb"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title HUD header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Biometric Ingestion")
                                .font(Theme.Typography.technical(12, weight: .black))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2.0)
                            Text("Record Today's Biometrics")
                                .font(Theme.Typography.technical(10, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .tracking(1.0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Inputs
                        VStack(spacing: 16) {
                            // Weight Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Body Weight (\(unit))")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.0)
                                
                                TextField("0.0", text: $weightString)
                                    .keyboardType(.decimalPad)
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.warningOrange)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal)
                            
                            // Body Fat Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Body Fat Percentage (%)")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.0)
                                
                                TextField("0.0", text: $bodyFatString)
                                    .keyboardType(.decimalPad)
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.accent)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal)
                            
                            // Notes Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Log Notes")
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.0)
                                
                                TextField("Optional (e.g. morning scale check)", text: $noteString)
                                    .font(.body)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Save Button
                        Button(action: saveLog) {
                            Text("Save Readings")
                                .font(Theme.Typography.technical(16, weight: .black))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Theme.accent)
                                .cornerRadius(12)
                                .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Log Biometrics")
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
        .preferredColorScheme(.dark)
        .onAppear {
            if let settings = userSettings.first {
                if settings.bodyWeight > 0 {
                    weightString = String(format: "%.1f", settings.bodyWeight)
                }
                if settings.bodyFatPercentage > 0 {
                    bodyFatString = String(format: "%.1f", settings.bodyFatPercentage)
                }
            }
        }
    }
    
    private func saveLog() {
        let weight = Double(weightString)
        let bodyFat = Double(bodyFatString)
        
        let newLog = BiometricLog(
            weight: weight,
            bodyFat: bodyFat,
            notes: noteString.isEmpty ? "Quick Log" : noteString
        )
        
        modelContext.insert(newLog)
        
        // Sync to UserSettings
        if let settings = userSettings.first {
            if let w = weight {
                settings.bodyWeight = w
            }
            if let bf = bodyFat {
                settings.bodyFatPercentage = bf
            }
        }
        
        try? modelContext.save()
        HapticManager.shared.playSuccess()
        dismiss()
    }
}
