import SwiftUI

struct TemplateBuilderHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text("Welcome to the Template Builder. This is where you architect repeatable grinds.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 8)
                        
                        HelpSection(
                            title: "1. Architecting a Blueprint",
                            icon: "hammer.fill",
                            color: Theme.accent,
                            content: [
                                "Templates allow you to save a specific sequence of exercises so you don't have to manually add them every time you hit the gym.",
                                "Name your template (e.g., 'Push Day A', 'Legs Heavy') and tap **ADD EXERCISE** to stack your movements in the exact order you perform them."
                            ]
                        )
                        
                        HelpSection(
                            title: "2. Reordering Movements",
                            icon: "arrow.up.arrow.down",
                            color: Theme.warningOrange,
                            content: [
                                "Press and hold the drag handles on the right side of any added exercise to reorder the stack.",
                                "The order you set here is the exact order the exercises will appear when you launch a session from this template."
                            ]
                        )
                        
                        HelpSection(
                            title: "3. Launching a Template",
                            icon: "rocket.fill",
                            color: Theme.dangerRed,
                            content: [
                                "Once saved, your templates will appear at the top of the Journal tab.",
                                "Tapping a template instantly generates a new active session pre-loaded with all of its exercises, ready for you to log your sets."
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Template Builder Guide")
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
    TemplateBuilderHelpView()
}
