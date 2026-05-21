import SwiftUI

struct DashboardHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Intro
                        Text("Welcome to the Command Center. This is your high-level reconnaissance screen, designed to give you an immediate tactical overview of your recovery and momentum.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        // Section 1
                        HelpSection(
                            title: "1. The Weekly Score & Volume",
                            icon: "flame.fill",
                            color: Theme.warningOrange,
                            content: [
                                "**Weekly Score**: Your total Intensity points accumulated over the last 7 days. This is a direct measurement of how hard you are pushing.",
                                "**Workouts**: The sheer number of sessions logged this week. Consistency is key."
                            ]
                        )
                        
                        // Section 2
                        HelpSection(
                            title: "2. The Recovery Heatmap",
                            icon: "figure.walk",
                            color: Theme.accent,
                            content: [
                                "This anatomical map visualizes your recovery state based on the muscle groups you've recently trained. **Tap any muscle node** to view its specific recovery status and recent exercises.",
                                "**Concentric Pulsing Waves**: Nodes that are exhausted or recovering will pulse on the map to show active rebuilding status.",
                                "**Recovery Wheel Gauge**: Inside the detail sheet, a custom 0-100% circular dial indicates the precise metabolic recovery state of the targeted muscle group.",
                                "**Red/Orange (Active Damage)**: Muscle was trained within the last 48 hours. It is currently rebuilding.",
                                "**Green (Recovered)**: Muscle has had adequate rest and is ready to be targeted again."
                            ]
                        )
                        
                        // Section 3
                        HelpSection(
                            title: "3. The Intensity Trend",
                            icon: "chart.xyaxis.line",
                            color: Theme.warningOrange,
                            content: [
                                "A line graph plotting the Intensity Score of your recent sessions.",
                                "Watch for upward trajectories. If the line is flatlining or dropping, you are either under-recovering or not pushing close enough to failure."
                            ]
                        )
                        
                        // Section 4
                        HelpSection(
                            title: "4. The Toolbox (Top Right)",
                            icon: "wrench.and.screwdriver.fill",
                            color: Theme.textPrimary,
                            content: [
                                "Tap the wrench icon to access peripheral systems, including the **Fasting Calculator**, which allows you to track metabolic resting phases and physiological states between grinds."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard Field Guide")
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

struct HelpSection: View {
    let title: String
    let icon: String
    let color: Color
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title.uppercased())
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(content, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(Theme.textSecondary)
                        // Note: SwiftUI Text supports basic Markdown, so **bold** and *italic* will render automatically.
                        Text(try! AttributedString(markdown: line))
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    DashboardHelpView()
}
