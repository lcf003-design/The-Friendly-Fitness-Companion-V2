import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var templates: [WorkoutTemplate]
    
    @State private var activeSession: WorkoutSession? = nil
    @State private var isActiveSessionNew = false
    @State private var isShowingTemplateBuilder = false
    @State private var isShowingHelp = false
    
    enum FilterType: String, CaseIterable {
        case all = "ALL"
        case failure = "ABSOLUTE FAILURE"
        case restPause = "REST-PAUSE"
    }
    @State private var activeFilter: FilterType = .all
    
    private var filteredSessions: [WorkoutSession] {
        switch activeFilter {
        case .all:
            return sessions
        case .failure:
            return sessions.filter { session in
                session.exercises.contains { exercise in
                    exercise.sets.contains { $0.hitFailure }
                }
            }
        case .restPause:
            return sessions.filter { session in
                session.exercises.contains { exercise in
                    exercise.sets.contains { !$0.restPauses.isEmpty }
                }
            }
        }
    }
    
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
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            modelContext.delete(template)
                                            try? modelContext.save()
                                        }) {
                                            Label("Delete Routine", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    
                    Divider().background(Theme.border.opacity(0.3)).padding(.vertical, 16)
                    
                    // HISTORY LIST
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(FilterType.allCases, id: \.self) { filter in
                                    Button(action: {
                                        withAnimation { activeFilter = filter }
                                    }) {
                                        Text(filter.rawValue)
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(activeFilter == filter ? Theme.midnightMatte : Theme.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(activeFilter == filter ? Theme.accent : Theme.surface)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(activeFilter == filter ? Theme.accent : Theme.border, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 8)
                    }
                    if filteredSessions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.border)
                            
                            Text(sessions.isEmpty ? "No history. Time to bleed." : "No sessions match filter.")
                                .font(Theme.Typography.technical(16))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredSessions) { session in
                                Button(action: {
                                    isActiveSessionNew = false
                                    activeSession = session
                                }) {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onDelete(perform: deleteSessions)
                            .listRowBackground(Theme.surface)
                        }
                        .scrollContentBackground(.hidden)
                    }
                    
                    Button(action: {
                        let newSession = WorkoutSession(name: "Late Night Grind", timestamp: Date(), rpe: 8, exercises: [])
                        modelContext.insert(newSession)
                        isActiveSessionNew = true
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
            .fullScreenCover(item: $activeSession) { session in
                WorkoutLoggerView(session: session, isNewSession: isActiveSessionNew)
            }
            .sheet(isPresented: $isShowingHelp) {
                JournalHelpView()
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
        
        isActiveSessionNew = true
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
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    
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
                
                Button(action: {
                    if let image = renderSessionReport() {
                        generatedImage = image
                        showShareSheet = true
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(activityItems: [image])
            }
        }
    }
    
    @MainActor
    private func renderSessionReport() -> UIImage? {
        let view = SessionReportView(session: session)
            .frame(width: 800) // Fixed width to ensure high fidelity rendering
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0 // High scale factor for crisp sharing
        
        return renderer.uiImage
    }
}

// MARK: - Shareable Lookbook Component
struct SessionReportView: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 8) {
                Text(session.name.uppercased())
                    .font(Theme.Typography.technical(48, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(session.timestamp.formatted(date: .abbreviated, time: .shortened).uppercased())
                    .font(Theme.Typography.technical(16, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(2)
            }
            
            // Intensity Score
            VStack(spacing: 0) {
                Text("\(session.totalIntensityScore)")
                    .font(Theme.Typography.technical(120, weight: .black))
                    .foregroundColor(Theme.accent)
                Text("INTENSITY SCORE")
                    .font(Theme.Typography.technical(18, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(4)
            }
            
            // Exercises List
            VStack(alignment: .leading, spacing: 16) {
                ForEach(session.exercises) { exercise in
                    let rawName = exercise.loggedName.isEmpty ? (exercise.exerciseRef?.name ?? "UNKNOWN") : exercise.loggedName
                    let name = rawName.uppercased()
                    let totalVolume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                    let setSummary = String(format: "%d SETS • %.1f VOL", exercise.sets.count, totalVolume)
                    
                    HStack {
                        Text(name)
                            .font(Theme.Typography.technical(20, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(setSummary)
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .foregroundColor(Theme.warningOrange)
                    }
                    Divider().background(Theme.border.opacity(0.3))
                }
            }
            .padding(.horizontal, 40)
            
            Spacer(minLength: 40)
            
            // Watermark
            Text("THE FRIENDLY FITNESS COMPANION — COMMAND CENTER DATA V2")
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
                .tracking(3)
        }
        .padding(60)
        .background(Theme.midnightMatte)
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    container.mainContext.insert(Exercise(name: "Bench Press", targetMuscle: "Chest"))
    
    return JournalView()
        .modelContainer(container)
}
