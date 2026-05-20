import SwiftUI

struct WorkoutLoggerHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Active Grind. This is where you architect your current session.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. Adding Exercises",
                            icon: "plus.app.fill",
                            color: Theme.accent,
                            content: [
                                "Tap the **ADD EXERCISE** button at the bottom of your screen to open the Exercise Vault and select your movements.",
                                "Once added, tap on any exercise in your list to enter the Intensity Matrix and start logging sets."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. The Operational HUD",
                            icon: "viewfinder",
                            color: Theme.warningOrange,
                            content: [
                                "The frosted-glass panel at the bottom tracks your session's vital signs in real-time:",
                                "**Session Tonnage**: Total weight moved (Weight × Reps).",
                                "**Intensity Score**: Your calculated physiological output based on volume and failure.",
                                "**Failures**: The number of absolute muscular failure sets achieved today."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. High-Intensity Pro-Glow",
                            icon: "flame.fill",
                            color: Theme.dangerRed,
                            content: [
                                "If you push an exercise to absolute failure (toggling the flame icon inside the exercise), it will permanently glow red on your list here.",
                                "A glowing red list is the mark of a savage session."
                            ]
                        )
                        
                        HelpSection(
                            title: "4. Finishing the Grind",
                            icon: "checkmark.circle.fill",
                            color: Theme.accent,
                            content: [
                                "When you have completed all your movements, tap **FINISH WORKOUT**.",
                                "This will lock the session, calculate your final scores, and permanently archive it in your Journal."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Workout Logger Guide")
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
    WorkoutLoggerHelpView()
}
