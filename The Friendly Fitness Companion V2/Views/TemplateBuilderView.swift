import SwiftUI
import SwiftData

struct TemplateBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var templateName: String = ""
    @State private var selectedExercises: [Exercise] = []
    
    @State private var isShowingExerciseSelection = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROUTINE NAME")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        TextField("e.g., Heavy Push Day", text: $templateName)
                            .font(.title2.bold())
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Exercise List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TARGET EXERCISES")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        
                        if selectedExercises.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(Theme.border)
                                Text("No exercises added yet.")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            List {
                                ForEach(selectedExercises) { exercise in
                                    HStack {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        Text(exercise.targetMuscle.uppercased())
                                            .font(Theme.Typography.technical(10, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.accent.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .listRowBackground(Theme.surface)
                                }
                                .onDelete(perform: removeExercise)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Add Exercise Button
                    Button(action: {
                        isShowingExerciseSelection = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("ADD EXERCISE")
                        }
                        .font(Theme.Typography.technical(16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("New Template")
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
                        saveTemplate()
                    }
                    .foregroundColor(Theme.accent)
                    .fontWeight(.bold)
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedExercises.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingExerciseSelection) {
                TemplateExerciseSelectionView(selectedExercises: $selectedExercises)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func removeExercise(at offsets: IndexSet) {
        selectedExercises.remove(atOffsets: offsets)
    }
    
    private func saveTemplate() {
        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newTemplate = WorkoutTemplate(name: trimmedName, targetExercises: selectedExercises)
        modelContext.insert(newTemplate)
        try? modelContext.save()
        
        dismiss()
    }
}

// A simplified selector just for grabbing exercises to put in a Template
struct TemplateExerciseSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    
    @Binding var selectedExercises: [Exercise]
    @State private var searchText = ""
    
    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var groupedExercises: [String: [Exercise]] {
        Dictionary(grouping: filteredExercises, by: { $0.targetMuscle })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                List {
                    ForEach(groupedExercises.keys.sorted(), id: \.self) { muscle in
                        Section(header: Text(muscle.uppercased()).foregroundColor(Theme.accent).font(Theme.Typography.technical(12, weight: .bold))) {
                            ForEach(groupedExercises[muscle] ?? []) { exercise in
                                TemplateExerciseRow(exercise: exercise) {
                                    selectedExercises.append(exercise)
                                    dismiss()
                                }
                                .listRowBackground(Theme.surface)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search exercises...")
            }
            .navigationTitle("Add to Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TemplateExerciseRow: View {
    let exercise: Exercise
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Theme.accent)
            }
        }
    }
}
