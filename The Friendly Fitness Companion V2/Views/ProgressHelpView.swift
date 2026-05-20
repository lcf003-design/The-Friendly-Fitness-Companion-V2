import SwiftUI

struct ProgressHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Workout History vault. This is a chronological ledger of every time you bled for your goals.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. The Chronological Ledger",
                            icon: "clock.arrow.circlepath",
                            color: Theme.accent,
                            content: [
                                "All your past grinds are recorded here, sorted from newest to oldest.",
                                "Review the high-level Intensity Score and the number of exercises performed at a glance."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Session Drill-Down",
                            icon: "magnifyingglass",
                            color: Theme.warningOrange,
                            content: [
                                "**Tap any session** to open its full Session Summary.",
                                "You can review every single exact weight, rep, and set logged on that specific day.",
                                "Use this log to remind yourself exactly what you need to beat today."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress Analytics Guide")
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
    ProgressHelpView()
}
