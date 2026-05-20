import SwiftUI

struct SettingsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Command Settings. This is the root configuration panel for the entire ecosystem.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. The Grind Engine",
                            icon: "engine.combustion.fill",
                            color: Theme.accent,
                            content: [
                                "**Automated Rest Timer**: Enables the 120-second background countdown during active sessions.",
                                "**Haptic Metronome & Tempo Profile**: If enabled, the app will pulse physical haptics to guide your rep cadence (e.g., 4 seconds down, 2 second pause). Select your preferred Tempo Profile here.",
                                "**Ghost Target**: Dictates how the Inroad Gauge inside an active exercise behaves. 'Most Recent' compares your current set against the exact same exercise from your last session. 'All-Time PR' forces you to compete against your absolute best historical performance."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Apple Health Sync",
                            icon: "heart.fill",
                            color: Theme.dangerRed,
                            content: [
                                "Toggle this to push your completed workouts directly to Apple Health. This includes total duration, active calories burned, and volume."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Data Export",
                            icon: "square.and.arrow.up",
                            color: Theme.warningOrange,
                            content: [
                                "Tap Export to generate a raw CSV file of your entire database. This guarantees you own your data and can run your own analytics in Excel."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings Guide")
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
    SettingsHelpView()
}
