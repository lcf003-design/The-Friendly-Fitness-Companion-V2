import SwiftUI

struct ProfileHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to your Profile. This is the central hub for your identity, macros, and global settings.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. The Macro Matrix",
                            icon: "chart.pie.fill",
                            color: Theme.accent,
                            content: [
                                "The top section displays your daily nutritional targets.",
                                "Tap **EDIT MACROS** to adjust your Caloric, Protein, Carb, and Fat goals based on your current physique objectives (e.g. cutting vs bulking).",
                                "These targets provide a constant baseline reference for your daily discipline."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. The Settings Gear",
                            icon: "gearshape.fill",
                            color: Theme.textSecondary,
                            content: [
                                "Tap the gear icon in the top right to access the **Command Settings**.",
                                "Inside Settings, you can customize the Grind Engine (Tempo Profiles, Ghost Targets), manage your Exercise Vault, sync with Apple Health, and export your entire database."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile Guide")
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
    ProfileHelpView()
}
