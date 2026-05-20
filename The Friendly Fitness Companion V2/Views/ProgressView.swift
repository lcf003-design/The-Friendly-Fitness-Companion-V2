import SwiftUI
import SwiftData

struct ProgressView: View {
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var userSettings: [UserSettings]
    
    @State private var selectedSession: WorkoutSession?
    @State private var isShowingHelp = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                if allSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.textSecondary)
                        Text("NO HISTORY FOUND")
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(2)
                        Text("Log your first grind to start tracking progress.")
                            .font(Theme.Typography.technical(14))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(allSessions) { session in
                            Button(action: {
                                selectedSession = session
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(session.name)
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(session.totalIntensityScore) PTS")
                                            .font(Theme.Typography.technical(14, weight: .black))
                                            .foregroundColor(Theme.accent)
                                        Text("\(session.exercises.count) EXERCISES")
                                            .font(Theme.Typography.technical(10, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Theme.border)
                                        .padding(.leading, 8)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .fullScreenCover(item: $selectedSession) { session in
                WorkoutLoggerView(session: session, isNewSession: false)
            }
            .sheet(isPresented: $isShowingHelp) {
                ProgressHelpView()
            }
        }
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [WorkoutSession.self, UserSettings.self], inMemory: true)
}
