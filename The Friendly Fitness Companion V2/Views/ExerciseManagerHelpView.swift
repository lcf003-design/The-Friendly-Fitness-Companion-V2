import SwiftUI

struct ExerciseManagerHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Exercise Manager. This is the global directory of every movement in your database.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. Global Database",
                            icon: "server.rack",
                            color: Theme.accent,
                            content: [
                                "Unlike the vault seen during an active workout, this manager allows you to browse, edit, and delete exercises without being inside a session.",
                                "Use the search bar to filter by name or muscle group."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Adding New Movements",
                            icon: "plus.circle.fill",
                            color: Theme.warningOrange,
                            content: [
                                "Tap the **+** icon in the top right to add a custom exercise.",
                                "You must define a specific Target Muscle (e.g., 'Chest', 'Quads') so the Dashboard's Anatomical Heatmap can accurately track your recovery.",
                                "Any Coaching Cues you add here will be visible every time you log this exercise in the future."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Pruning the Database",
                            icon: "trash.fill",
                            color: Theme.dangerRed,
                            content: [
                                "Swipe left on any exercise to permanently delete it.",
                                "Deleting an exercise removes it from the global selection vault, but it does *not* erase the historical data of past workouts where you used this exercise."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Exercise Manager Guide")
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
    ExerciseManagerHelpView()
}
