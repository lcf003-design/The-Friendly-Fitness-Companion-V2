import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var templates: [WorkoutTemplate]
    
    @State private var activeSession: WorkoutSession?
    @State private var isShowingTemplateBuilder = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // THE ARSENAL (Templates)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THE ARSENAL")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Add New Template Button
                                Button(action: {
                                    isShowingTemplateBuilder = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus")
                                            .font(.title)
                                        Text("New Routine")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(width: 120, height: 100)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border, style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    )
                                }
                                
                                // Template Cards
                                ForEach(templates) { template in
                                    Button(action: {
                                        startGrind(from: template)
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(template.name)
                                                .font(.headline)
                                                .foregroundColor(Theme.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            Text("\(template.targetExercises.count) Exercises")
                                                .font(.caption)
                                                .foregroundColor(Theme.accent)
                                        }
                                        .padding()
                                        .frame(width: 140, height: 100, alignment: .topLeading)
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.border, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    
                    Divider().background(Theme.border.opacity(0.3)).padding(.vertical, 16)
                    
                    // HISTORY LIST
                    // HISTORY LIST
                    if sessions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.border)
                            
                            Text("No history. Time to bleed.")
                                .font(Theme.Typography.technical(16))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(sessions) { session in
                                SessionRow(session: session)
                            }
                            .onDelete(perform: deleteSessions)
                            .listRowBackground(Theme.surface)
                        }
                        .scrollContentBackground(.hidden)
                    }
                    
                    Button(action: {
                        let newSession = WorkoutSession(name: "Late Night Grind", timestamp: Date(), rpe: 8, exercises: [])
                        modelContext.insert(newSession)
                        activeSession = newSession
                    }) {
                        Text("START GRIND")
                            .font(Theme.Typography.technical(18, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Theme.accent)
                            .cornerRadius(16)
                            .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding()
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .fullScreenCover(item: $activeSession) { session in
                WorkoutLoggerView(session: session)
            }
            .sheet(isPresented: $isShowingTemplateBuilder) {
                TemplateBuilderView()
            }
        }
    }
    
    private func startGrind(from template: WorkoutTemplate) {
        let newSession = WorkoutSession(name: template.name, timestamp: Date(), rpe: 0, exercises: [])
        modelContext.insert(newSession)
        
        for exercise in template.targetExercises {
            let workoutExercise = WorkoutExercise(exerciseRef: exercise, sets: [])
            newSession.exercises.append(workoutExercise)
        }
        
        activeSession = newSession
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sessions[index])
            }
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.name)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(session.totalIntensityScore) pts")
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.accent)
            }
            HStack {
                Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                ShareLink(item: generateShareText()) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func generateShareText() -> String {
        return "I just crushed the '\(session.name)' grind with an intensity score of \(session.totalIntensityScore) on The Friendly Fitness Companion! Time to bleed. 🩸💪"
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    container.mainContext.insert(Exercise(name: "Bench Press", targetMuscle: "Chest"))
    
    return JournalView()
        .modelContainer(container)
}
