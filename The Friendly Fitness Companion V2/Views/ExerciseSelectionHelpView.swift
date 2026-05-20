import SwiftUI

struct ExerciseSelectionHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Exercise Vault. This is your master database of movements.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. Selecting Movements",
                            icon: "magnifyingglass",
                            color: Theme.accent,
                            content: [
                                "Browse the list or use the search bar to find an exercise by name or target muscle group.",
                                "Tapping an exercise immediately drops it into your active Workout Logger."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Creating Custom Intel",
                            icon: "plus.circle.fill",
                            color: Theme.warningOrange,
                            content: [
                                "If a movement isn't in your vault, tap the **+** icon in the top left corner.",
                                "Here, you can name the exercise, assign the exact target muscle, and attach permanent **Coaching Cues** (e.g. 'Keep chest up', 'Squeeze at the top').",
                                "These cues will be visible every time you log this exercise in the future."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Pruning the Vault",
                            icon: "trash.fill",
                            color: Theme.dangerRed,
                            content: [
                                "Swipe left on any exercise to permanently delete it from the vault.",
                                "Warning: Deleting an exercise here deletes it from your global database, though past sessions will retain the text record."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Exercise Vault Guide")
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
    ExerciseSelectionHelpView()
}
