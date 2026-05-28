import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins
import AVFoundation

struct CSVFile: Transferable {
    let text: String
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .commaSeparatedText) { file in
            file.text.data(using: .utf8) ?? Data()
        } importing: { data in
            CSVFile(text: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.timestamp, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var templates: [WorkoutTemplate]
    
    @State private var activeSession: WorkoutSession? = nil
    @State private var isActiveSessionNew = false
    @State private var isShowingTemplateBuilder = false
    @State private var isShowingHelp = false
    @State private var isShowingImportSheet = false
    @State private var sharingRoutineQR: WorkoutTemplate? = nil
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case failure = "Absolute Failure"
        case restPause = "Rest-Pause"
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
    
    private var workoutHistoryCSV: String {
        var csv = "Session Date,Session Name,Intensity Score,Exercise Name,Target Muscle,Set Number,Set Type,Weight (lb/kg),Reps,Failure reached,Forced Reps,Negatives,Notes\n"
        
        let sortedSessions = sessions.sorted { $0.timestamp > $1.timestamp }
        for session in sortedSessions {
            let sessionDate = session.timestamp.formatted(date: .numeric, time: .shortened)
            let sessionName = session.name.replacingOccurrences(of: ",", with: " ")
            let intensity = session.totalIntensityScore
            
            for exercise in session.exercises {
                let exerciseName = (exercise.loggedName.isEmpty ? (exercise.exerciseRef?.name ?? "Unknown") : exercise.loggedName).replacingOccurrences(of: ",", with: " ")
                let muscle = exercise.normalizedTargetMuscle
                
                for (index, set) in exercise.sets.enumerated() {
                    let setNum = index + 1
                    let type = set.setType
                    let weight = set.weight
                    let reps = set.reps
                    let failure = set.hitFailure ? "YES" : "NO"
                    let forced = set.forcedReps
                    let negatives = set.negatives
                    let notes = set.notes.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ")
                    
                    csv += "\(sessionDate),\(sessionName),\(intensity),\(exerciseName),\(muscle),\(setNum),\(type),\(weight),\(reps),\(failure),\(forced),\(negatives),\(notes)\n"
                }
            }
        }
        return csv
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // THE ARSENAL (Templates)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routines")
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
                                
                                // Import Routine Button
                                Button(action: {
                                    isShowingImportSheet = true
                                }) {
                                    VStack {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.title)
                                        Text("Import Routine")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(Theme.warningOrange)
                                    .frame(width: 120, height: 100)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.warningOrange.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5]))
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
                                        Button(action: {
                                            sharingRoutineQR = template
                                        }) {
                                            Label("Share QR Code", systemImage: "qrcode")
                                        }
                                        
                                        Button(action: {
                                            let code = encodeRoutine(template)
                                            UIPasteboard.general.string = code
                                            HapticManager.shared.playSuccess()
                                        }) {
                                            Label("Share Routine Code", systemImage: "square.and.arrow.up")
                                        }
                                        
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
                            
                            Text(sessions.isEmpty ? "No workout history yet. Start a session below!" : "No sessions match filter.")
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
                        let newSession = WorkoutSession(name: "Workout Session", timestamp: Date(), rpe: 8, exercises: [])
                        modelContext.insert(newSession)
                        isActiveSessionNew = true
                        activeSession = newSession
                    }) {
                        Text("Start Workout")
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(
                        item: CSVFile(text: workoutHistoryCSV),
                        preview: SharePreview("workout_history.csv")
                    ) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(Theme.accent)
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
            .sheet(isPresented: $isShowingImportSheet) {
                ImportRoutineSheet()
            }
            .sheet(item: $sharingRoutineQR) { template in
                ShareRoutineQRSheet(template: template)
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
    
    private func encodeRoutine(_ template: WorkoutTemplate) -> String {
        let cleanName = template.name.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ";", with: "").replacingOccurrences(of: ",", with: "")
        var exercisesPart = ""
        for ex in template.targetExercises {
            let cleanExName = ex.name.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ";", with: "").replacingOccurrences(of: ",", with: "")
            let cleanMuscle = ex.targetMuscle.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ";", with: "").replacingOccurrences(of: ",", with: "")
            if !exercisesPart.isEmpty {
                exercisesPart += ";"
            }
            exercisesPart += "\(cleanExName),\(cleanMuscle)"
        }
        return "FFC-ROUTINE:\(cleanName)|\(exercisesPart)"
    }
}

struct ImportRoutineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var shareCode: String = ""
    @State private var errorMessage: String? = nil
    @State private var isShowingScanner = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scan or Paste Routine Code")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.warningOrange)
                            .tracking(1.5)
                        
                        Text("Scan a routine QR code or enter a valid Friendly Fitness Companion routine code to import it into your arsenal.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Button(action: {
                        isShowingScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan Routine QR Code")
                        }
                        .font(Theme.Typography.technical(14, weight: .black))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.accent)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Rectangle()
                            .fill(Theme.border.opacity(0.3))
                            .frame(height: 1)
                        Text("OR")
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        Rectangle()
                            .fill(Theme.border.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)
                    
                    TextField("FFC-ROUTINE:RoutineName|Exercise1,Muscle;...", text: $shareCode, axis: .vertical)
                        .lineLimit(4...8)
                        .padding()
                        .background(Theme.surface)
                        .foregroundColor(Theme.textPrimary)
                        .font(.system(.body, design: .monospaced))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        .padding(.horizontal)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.none)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer()
                    
                    Button(action: importRoutine) {
                        Text("Import Routine")
                            .font(Theme.Typography.technical(16, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(shareCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Theme.accent)
                            .cornerRadius(12)
                    }
                    .disabled(shareCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Import Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                NavigationStack {
                    QRScannerView(onScan: { decodedString in
                        shareCode = decodedString
                        isShowingScanner = false
                        importRoutine()
                    }, onFailure: { error in
                        errorMessage = "Camera Error: \(error.localizedDescription)"
                        isShowingScanner = false
                    })
                    .navigationTitle("Scan Routine QR")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                isShowingScanner = false
                            }
                            .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    private func importRoutine() {
        let code = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.hasPrefix("FFC-ROUTINE:") else {
            errorMessage = "Invalid code: Missing FFC-ROUTINE prefix."
            HapticManager.shared.playHeavyImpact()
            return
        }
        
        let payload = String(code.dropFirst("FFC-ROUTINE:".count))
        let parts = payload.components(separatedBy: "|")
        guard parts.count >= 2 else {
            errorMessage = "Invalid code: Missing name or exercise payload."
            HapticManager.shared.playHeavyImpact()
            return
        }
        
        let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Invalid code: Routine name cannot be empty."
            HapticManager.shared.playHeavyImpact()
            return
        }
        
        let exercisesPart = parts[1]
        let entries = exercisesPart.components(separatedBy: ";")
        
        var importedExercises: [Exercise] = []
        
        // Fetch all existing exercises to reuse references if they exist
        let descriptor = FetchDescriptor<Exercise>()
        let existingExercises = (try? modelContext.fetch(descriptor)) ?? []
        
        for entry in entries {
            let entryClean = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entryClean.isEmpty else { continue }
            
            let exParts = entryClean.components(separatedBy: ",")
            guard exParts.count >= 2 else { continue }
            
            let exName = exParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let exMuscle = exParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !exName.isEmpty else { continue }
            
            // Look up existing exercise
            if let existing = existingExercises.first(where: { $0.name.lowercased() == exName.lowercased() }) {
                importedExercises.append(existing)
            } else {
                // Validate muscle
                let muscle = MuscleGroup.all.first(where: { $0.lowercased() == exMuscle.lowercased() }) ?? "Shoulders"
                let newEx = Exercise(name: exName, targetMuscle: muscle)
                modelContext.insert(newEx)
                importedExercises.append(newEx)
            }
        }
        
        guard !importedExercises.isEmpty else {
            errorMessage = "No valid exercises found in code."
            HapticManager.shared.playHeavyImpact()
            return
        }
        
        let template = WorkoutTemplate(name: name, targetExercises: importedExercises)
        modelContext.insert(template)
        
        do {
            try modelContext.save()
            HapticManager.shared.playSuccess()
            dismiss()
        } catch {
            errorMessage = "Database save failed."
            HapticManager.shared.playHeavyImpact()
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
                Text(session.name)
                    .font(Theme.Typography.technical(48, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Typography.technical(16, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(2)
            }
            
            // Intensity Score
            VStack(spacing: 0) {
                Text("\(session.totalIntensityScore)")
                    .font(Theme.Typography.technical(120, weight: .black))
                    .foregroundColor(Theme.accent)
                Text("Intensity Score")
                    .font(Theme.Typography.technical(18, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(4)
            }
            
            // Exercises List
            VStack(alignment: .leading, spacing: 16) {
                ForEach(session.exercises) { exercise in
                    let rawName = exercise.loggedName.isEmpty ? (exercise.exerciseRef?.name ?? "Unknown") : exercise.loggedName
                    let name = rawName
                    let totalVolume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                    let setSummary = String(format: "%d Sets • %.1f Vol", exercise.sets.count, totalVolume)
                    
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
            Text("The Friendly Fitness Companion — Session Data Summary")
                .font(Theme.Typography.technical(12, weight: .bold))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
                .tracking(3)
        }
        .padding(60)
        .background(Theme.midnightMatte)
    }
}

struct ShareRoutineQRSheet: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss
    
    private var qrCodeString: String {
        let cleanName = template.name.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ";", with: "").replacingOccurrences(of: ",", with: "")
        var exercisesPart = ""
        for ex in template.targetExercises {
            let cleanExName = ex.name.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ";", with: "").replacingOccurrences(of: ",", with: "")
            let cleanMuscle = ex.targetMuscle.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ";", with: "").replacingOccurrences(of: ",", with: "")
            if !exercisesPart.isEmpty {
                exercisesPart += ";"
            }
            exercisesPart += "\(cleanExName),\(cleanMuscle)"
        }
        return "FFC-ROUTINE:\(cleanName)|\(exercisesPart)"
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text(template.name)
                        .font(Theme.Typography.technical(20, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let qrImage = generateQRCode(from: qrCodeString) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.3), radius: 10)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(Theme.dangerRed)
                            Text("Failed to generate QR Code")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(width: 250, height: 250)
                        .background(Theme.surface)
                        .cornerRadius(16)
                    }
                    
                    Text("Have your friend scan this QR Code from their Import Routine screen to copy this workout instantly.")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle("Share Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}

#if !targetEnvironment(simulator)
struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onFailure: (Error) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onFailure: onFailure)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: (String) -> Void
        var onFailure: (Error) -> Void
        
        init(onScan: @escaping (String) -> Void, onFailure: @escaping (Error) -> Void) {
            self.onScan = onScan
            self.onFailure = onFailure
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                onScan(stringValue)
            }
        }
    }
}

class QRScannerViewController: UIViewController {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
#else
struct QRScannerView: View {
    var onScan: (String) -> Void
    var onFailure: (Error) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 50))
                .foregroundColor(Theme.textSecondary)
            
            Text("Camera unavailable in iOS Simulator")
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            
            Button("Simulate Scan (Chest & Back Routine)") {
                onScan("FFC-ROUTINE:Chest & Back Day|Bench Press,Chest;Bent Over Row,Back")
            }
            .padding()
            .background(Theme.accent)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
    }
}
#endif

#Preview {
    let schema = Schema([Exercise.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self, UserSettings.self, FastingSession.self, WorkoutTemplate.self, FastingLogEntry.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    container.mainContext.insert(Exercise(name: "Bench Press", targetMuscle: "Chest"))
    
    return JournalView()
        .modelContainer(container)
}
