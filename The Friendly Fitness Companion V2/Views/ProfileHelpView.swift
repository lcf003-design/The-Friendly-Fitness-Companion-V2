import SwiftUI

struct ProfileHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to your Profile. This is the central hub for your identity, macros, and global settings.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. The Macro Matrix",
                            icon: "chart.pie.fill",
                            color: Theme.accent,
                            content: [
                                "The top section displays your daily nutritional targets.",
                                "Tap **EDIT MACROS** to adjust your Caloric, Protein, Carb, and Fat goals based on your current physique objectives (e.g. cutting vs bulking).",
                                "These targets provide a constant baseline reference for your daily discipline."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. The Physique Vault & Biometrics",
                            icon: "photo.on.rectangle.angled",
                            color: Theme.accent,
                            content: [
                                "Track your visual transformation over time. Upload photos tagged with your bodyweight and training phase.",
                                "Select any two photos to open the **Before/After Curtain Slider**. Drag the dividing slider handle back and forth to superimpose and compare changes.",
                                "**Biometric Logs**: Log body weight and body fat tracking points over time. View interactive progression and history charts directly on your profile.",
                                "All photos and data are stored locally on your device for absolute privacy."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. The Settings Gear",
                            icon: "gearshape.fill",
                            color: Theme.textSecondary,
                            content: [
                                "Tap the gear icon in the top right to access the **Command Settings**.",
                                "Inside Settings, you can customize the Grind Engine (Tempo Rest Timers, Haptic Cadence Metronome, Ghost Targets), manage your Exercise Database, sync with Apple Health, and export your entire database."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

#Preview {
    ProfileHelpView()
}
