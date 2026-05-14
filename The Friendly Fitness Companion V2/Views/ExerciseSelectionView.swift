import SwiftUI
import SwiftData

struct ExerciseSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    
    @State private var searchText = ""
    @State private var isShowingAddSheet = false
    
    var onSelect: (Exercise) -> Void
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.targetMuscle.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Group exercises by Muscle
    var groupedExercises: [String: [Exercise]] {
        Dictionary(grouping: filteredExercises, by: { $0.targetMuscle })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.border)
                        TextField("Search exercises...", text: $searchText)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .padding()
                    
                    List {
                        ForEach(groupedExercises.keys.sorted(), id: \.self) { muscle in
                            Section(header: Text(muscle.uppercased()).font(Theme.Typography.technical(12, weight: .bold)).foregroundColor(Theme.accent)) {
                                ForEach(groupedExercises[muscle] ?? []) { exercise in
                                    Button(action: {
                                        onSelect(exercise)
                                        dismiss()
                                    }) {
                                        HStack {
                                            Text(exercise.name)
                                                .foregroundColor(Theme.textPrimary)
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(Theme.border)
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteExercises(at: indexSet, in: muscle)
                                }
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddExerciseSheet()
            }
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

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    container.mainContext.insert(Exercise(name: "Bench Press", targetMuscle: "Chest"))
    container.mainContext.insert(Exercise(name: "Squat", targetMuscle: "Quads"))
    
    return ExerciseSelectionView { _ in }
        .modelContainer(container)
}
