import SwiftUI
import SwiftData

struct ExerciseManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var allWorkoutExercises: [WorkoutExercise]
    @Query private var userSettings: [UserSettings]
    
    @State private var isShowingAddSheet = false
    
    // Group exercises by target muscle
    private var groupedExercises: [String: [Exercise]] {
        Dictionary(grouping: allExercises, by: { $0.targetMuscle })
    }
    
    private func max1RM(for exerciseName: String) -> Double {
        let matchingExercises = allWorkoutExercises.filter { $0.exerciseRef?.name.lowercased() == exerciseName.lowercased() }
        let maxProjected = matchingExercises.flatMap { wex in
            wex.sets.filter { $0.weight > 0 && $0.reps > 0 }.map { set in
                // Epley formula matches the 1RM Calculator tool
                return set.weight * (1.0 + (Double(set.reps) / 30.0))
            }
        }.max() ?? 0.0
        return maxProjected
    }
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            if allExercises.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 50))
                        .foregroundColor(Theme.border)
                    Text("The Vault is Empty")
                        .font(Theme.Typography.technical(16))
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                List {
                    // THE ORACLE: PR TRACKING
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                let unit = userSettings.first?.weightUnit ?? "lb"
                                PRCard(title: "BENCH", max1RM: max1RM(for: "Bench Press"), unit: unit)
                                PRCard(title: "SQUAT", max1RM: max1RM(for: "Squat"), unit: unit)
                                PRCard(title: "DEADLIFT", max1RM: max1RM(for: "Deadlift"), unit: unit)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    } header: {
                        Text("THE ORACLE (EST 1RM)")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.warningOrange)
                            .tracking(1)
                    }
                    
                    ForEach(groupedExercises.keys.sorted(), id: \.self) { muscle in
                        Section {
                            ForEach(groupedExercises[muscle] ?? []) { exercise in
                                NavigationLink(destination: LazyView(ExerciseHistoryView(exercise: exercise))) {
                                    ExerciseRowView(exercise: exercise)
                                }
                            }
                            .onDelete { indexSet in
                                deleteExercises(at: indexSet, in: muscle)
                            }
                        } header: {
                            Text(muscle.uppercased())
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .tracking(1)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("The Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isShowingAddSheet = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddExerciseSheet()
        }
    }
    
    private func deleteExercises(at offsets: IndexSet, in muscle: String) {
        guard let exercisesInGroup = groupedExercises[muscle] else { return }
        for index in offsets {
            let exerciseToDelete = exercisesInGroup[index]
            modelContext.delete(exerciseToDelete)
        }
        try? modelContext.save()
    }
}

struct PRCard: View {
    let title: String
    let max1RM: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            Text(max1RM > 0 ? "\(max1RM, specifier: "%.1f")" : "---")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(unit.uppercased())
                .font(Theme.Typography.technical(10, weight: .bold))
                .foregroundColor(Theme.accent)
        }
        .padding()
        .frame(width: 120, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.warningOrange.opacity(0.5), lineWidth: 1)
        )
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.surface)
    }
}

struct AddExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedMuscle: String = "Chest"
    @State private var notes: String = ""
    
    let muscleGroups = [
        "Chest", "Back", "Shoulders", "Arms", "Lats", "Core", "Quads", "Hamstrings", "Calves", "Glutes", "Full Body"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXERCISE NAME")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            
                            TextField("e.g. Deficit Bulgarian Split Squat", text: $name)
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TARGET MUSCLE")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            
                            Picker("Target Muscle", selection: $selectedMuscle) {
                                ForEach(muscleGroups, id: \.self) { muscle in
                                    Text(muscle).tag(muscle)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .background(Theme.surface)
                            .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("COACHING CUES (OPTIONAL)")
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            
                            TextField("e.g. Keep chest up, drive through heel", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(12)
                        }
                        
                    }
                    .padding()
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .foregroundColor(Theme.accent)
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newExercise = Exercise(
            name: trimmedName,
            targetMuscle: selectedMuscle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        modelContext.insert(newExercise)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    container.mainContext.insert(Exercise(name: "Bench Press", targetMuscle: "Chest"))
    container.mainContext.insert(Exercise(name: "Squat", targetMuscle: "Quads"))
    
    return NavigationStack {
        ExerciseManagerView()
    }
    .modelContainer(container)
}

// Prevents eager instantiation of views inside NavigationLinks
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
