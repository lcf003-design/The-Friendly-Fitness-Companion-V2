import SwiftUI

struct ActiveExerciseHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Zero-Bounce Active Exercise View. This is your primary console for logging physical trauma.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. Tactile Scrub Logging",
                            icon: "square.grid.3x3.fill",
                            color: Theme.accent,
                            content: [
                                "Log your grinds using a zero-bounce, tactile entry system designed to replace the keyboard.",
                                "**Digital Crown Scrubbing**: Tap and hold on the **Weight** or **Reps** inputs, then drag your finger up or down to dial numbers in (weight increments by standard 2.5 lb plates). Every unit change triggers a crisp, physical click.",
                                "**Tug-of-War PR Bar**: A progress bar tracks your live set volume (`Weight x Reps`) against your Ghost Target (historical PR). Exceeding it triggers a gold flash, glowing shadow, and a heavy PR haptic vibration."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Micro-Metrics & TUT",
                            icon: "clock.fill",
                            color: Theme.warningOrange,
                            content: [
                                "**F (Forced Reps)**: Reps completed beyond failure with a spotter's assistance.",
                                "**N (Negatives)**: Slow, eccentric-only reps performed after concentric failure.",
                                "**TUT (Time Under Tension)**: Automatically calculated by multiplying your reps by your active Tempo Profile duration (e.g. 4s eccentric + 2s pause = 6s per rep).",
                                "**+ RP (Rest-Pause)**: Triggers a 15-second countdown timer. When it expires, it appends a rest-pause slot to that set to log consecutive micro-sets."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. High-Intensity Failure",
                            icon: "flame.fill",
                            color: Theme.dangerRed,
                            content: [
                                "Tapping the Flame icon marks a set as a total muscular failure.",
                                "If an exercise contains a failure set, the entire movement will glow red on the main Workout Logger screen.",
                                "A red Pro-Glow indicates a maximized growth stimulus."
                            ]
                        )
                        
                        HelpSection(
                            title: "4. Notes & Coaching Cues",
                            icon: "text.bubble.fill",
                            color: Theme.textPrimary,
                            content: [
                                "Tap the **NOTES** toggle to reveal any coaching cues you set in the vault, or to add specific session notes for this exercise (e.g. 'Seat height 4')."
                            ]
                        )
                        
                        HelpSection(
                            title: "5. Set Management",
                            icon: "trash",
                            color: Theme.dangerRed,
                            content: [
                                "Need to remove a set? Tap the explicit **Trash** icon in the right-most column of any set to permanently delete it from the record."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Active Exercise Guide")
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
    ActiveExerciseHelpView()
}
