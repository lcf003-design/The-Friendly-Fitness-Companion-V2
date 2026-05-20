import SwiftUI

struct FastingHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Fasting Toolbox. This module tracks your physiological state when you are not actively feeding.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. The Control Ring",
                            icon: "record.circle",
                            color: Theme.accent,
                            content: [
                                "Tap the center of the massive ring at the top to START or STOP your fast.",
                                "Once active, the ring will slowly fill, visually tracking your progression through the 7 distinct physiological phases."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. The 7 Phases",
                            icon: "moon.stars.fill",
                            color: Theme.warningOrange,
                            content: [
                                "Below the ring are full-screen interactive cards detailing the 7 phases of a fast:",
                                "**Blood Sugar Normalization**",
                                "**Fat Burning (Ketosis Transition)**",
                                "**Deep Ketosis**",
                                "**Autophagy (Cellular Clean-up)**",
                                "**Peak HGH (Human Growth Hormone)**",
                                "**Insulin Reduction**",
                                "**Immune Regeneration**",
                                "Tap any card to view the exact scientific mechanics of what is happening inside your body at that specific hour marker."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Fasting History",
                            icon: "clock.fill",
                            color: Theme.textSecondary,
                            content: [
                                "At the very top of the screen is the **History** tab.",
                                "Tap it to view a ledger of all your completed fasts, including your longest fast ever recorded and your average fasting duration."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Fasting Toolbox Guide")
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
    FastingHelpView()
}
