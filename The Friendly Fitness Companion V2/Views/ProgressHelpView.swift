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
                            title: "1. Grouped Workout Routines",
                            icon: "folder.fill",
                            color: Theme.accent,
                            content: [
                                "Your workouts are grouped by their unique name (e.g., Leg Day, Push Day).",
                                "See the total grinds logged for each routine and your average intensity score at a glance."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Trend Charts & Stats",
                            icon: "chart.xyaxis.line",
                            color: Theme.warningOrange,
                            content: [
                                "**Tap any routine** to open its dedicated progress dashboard.",
                                "Analyze your Tonnage Volume and Intensity Score over time using interactive trend charts.",
                                "Review tactical stats like Max Tonnage and Average Intensity to ensure progressive overload."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Body Parts & Activation Stats",
                            icon: "figure.strengthtraining.traditional",
                            color: Theme.apexGreen,
                            content: [
                                "Switch to the **Body Parts** tab to track recovery, status, and weekly volume for each individual muscle group in a single consolidated list.",
                                "**Dual Metric Readouts**: View both your last-trained duration ('LAST: 3 DAYS AGO') and total weekly set volume ('WEEKLY: 12 SETS') side-by-side on each muscle item.",
                                "**Tactile Detail Sheets**: Tap any muscle row to reveal its dedicated status sheet with circular recovery dial, active status indicators, and a comprehensive workout ledger."
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
