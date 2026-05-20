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
                            title: "1. The Intensity Matrix",
                            icon: "square.grid.3x3.fill",
                            color: Theme.accent,
                            content: [
                                "The main logging area is a 3-tier matrix.",
                                "**Top Level (Primary Input):** Log your weight and reps.",
                                "**Middle Level (Inroad Gauge):** A horizontal bar that tracks your current set's weight against your Ghost Target (historical PR). Pushing past the Ghost triggers a gold pulse—you are setting a new PR.",
                                "**Bottom Level (Micro-Metrics):** Technical tracking for advanced training variables."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Micro-Metrics & TUT",
                            icon: "microbe",
                            color: Theme.warningOrange,
                            content: [
                                "**F (Forced Reps):** Reps completed beyond failure with a spotter's physical assistance.",
                                "**N (Negatives):** Slow, eccentric-only reps performed after concentric failure.",
                                "**TUT (Time Under Tension):** The app calculates this automatically. It extracts the duration from your active Tempo Profile (e.g. 4-2-4 = 10s) and multiplies it by your reps.",
                                "**+ RP (Rest-Pause):** Triggers a 15-second countdown timer. You can stop or restart this timer using the interactive gauge. Once elapsed, it appends a 'Rest-Pause' slot to that set."
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
