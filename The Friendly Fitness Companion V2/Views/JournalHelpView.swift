import SwiftUI

struct JournalHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Intro
                        Text("Welcome to the Journal. This is your historical archive and active command center for logging sessions. Precision data entry is critical for the algorithm to accurately chart your progress.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        // Section 1
                        HelpSection(
                            title: "1. Starting a Grind",
                            icon: "plus.circle.fill",
                            color: Theme.accent,
                            content: [
                                "Tap **START GRIND** to open a blank slate for your session.",
                                "Once inside, tap **ADD EXERCISE** to browse the Exercise Vault. If your exercise isn't listed, tap the **+** icon in the Vault to create a custom movement with specific coaching cues.",
                                "Past sessions in the Journal are completely locked and read-only by default. If you need to fix a typo from a previous day, tap the **Edit** button in the top right corner."
                            ]
                        )
                        
                        // Section 2
                        HelpSection(
                            title: "2. Tactile Scrub Logging",
                            icon: "square.grid.3x3.fill",
                            color: Theme.textPrimary,
                            content: [
                                "Log your grinds using a zero-bounce, tactile entry system designed to replace the keyboard.",
                                "**Digital Crown Scrubbing**: Tap and hold on the **Weight** or **Reps** inputs, then drag your finger up or down to dial numbers in. Every unit change triggers a crisp, physical click.",
                                "**Tug-of-War PR Bar**: Fills in real-time as you scrub. Exceeding your Ghost Target (PR) triggers a gold flash, glowing shadow, and intense haptic vibration."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Micro-Metrics & TUT",
                            icon: "clock.fill",
                            color: Theme.warningOrange,
                            content: [
                                "**F (Forced Reps)**: Reps completed beyond failure with a spotter's assistance.",
                                "**N (Negatives)**: Slow, eccentric-only reps performed after concentric failure.",
                                "**TUT (Time Under Tension)**: Automatically calculated by multiplying your reps by your active Tempo Profile duration.",
                                "**+ RP (Rest-Pause)**: Triggers a 15-second countdown timer. Once elapsed, it immediately appends a rest-pause slot to that set to log consecutive micro-sets."
                            ]
                        )
                        
                        // Section 4
                        HelpSection(
                            title: "4. High-Intensity Failure",
                            icon: "flame.fill",
                            color: Theme.dangerRed,
                            content: [
                                "Tapping the Flame icon marks a set as a total muscular failure.",
                                "If an exercise contains even a single failure set, the movement is permanently stamped on your main Dashboard list with a red Pro-Glow effect."
                            ]
                        )
                        
                        // Section 5
                        HelpSection(
                            title: "5. The Operational HUD",
                            icon: "viewfinder",
                            color: Theme.accent,
                            content: [
                                "At the bottom of the active workout screen is a frosted-glass HUD.",
                                "It provides live, session-wide tracking of your **Total Tonnage** (Weight × Reps), your overall **Intensity Score**, and your total **Failure Count**."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Journal Field Guide")
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
    JournalHelpView()
}
