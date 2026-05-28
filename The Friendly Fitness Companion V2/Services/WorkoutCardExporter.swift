import SwiftUI
import Photos

@MainActor
final class WorkoutCardExporter {
    static let shared = WorkoutCardExporter()
    
    private init() {}
    
    func renderWorkoutCard(session: WorkoutSession, unit: String) -> UIImage? {
        let cardView = WorkoutCardView(session: session, unit: unit)
            .frame(width: 1200, height: 1200)
            
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 1.0 // Render at 1:1 pixel scale
        return renderer.uiImage
    }
    
    func exportWorkoutCard(session: WorkoutSession, unit: String, completion: @escaping (Bool, String?) -> Void) {
        // Request Photo Library permissions for adding assets
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            self.generateAndSaveImage(session: session, unit: unit, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.generateAndSaveImage(session: session, unit: unit, completion: completion)
                    } else {
                        completion(false, "Photo Library access denied.")
                    }
                }
            }
        default:
            completion(false, "Photo access is restricted. Please enable Photo Library permissions in iOS Settings.")
        }
    }
    
    private func generateAndSaveImage(session: WorkoutSession, unit: String, completion: @escaping (Bool, String?) -> Void) {
        guard let uiImage = renderWorkoutCard(session: session, unit: unit) else {
            completion(false, "Unable to compile the workout card visual layout.")
            return
        }
        
        // Save using performChanges
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, error?.localizedDescription ?? "Could not save to Apple Photos library.")
                }
            }
        }
    }
}

// Custom export card layout matching the modern premium theme
struct WorkoutCardView: View {
    let session: WorkoutSession
    let unit: String
    
    private var totalTonnage: Double {
        session.exercises.flatMap { $0.sets }.filter { $0.isCompleted }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    private var failureCount: Int {
        session.exercises.flatMap { $0.sets }.filter { $0.hitFailure }.count
    }
    
    private var durationString: String {
        guard let start = session.timestamp as Date?, let end = session.endTime else { return "Completed" }
        let elapsed = end.timeIntervalSince(start)
        let mins = Int(elapsed / 60)
        return "\(mins) Min Session"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Friendly Fitness Companion")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Workout Grind Card")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.title)
                    .foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(Theme.midnightMatte)
            
            // Card Content Body
            VStack(alignment: .leading, spacing: 32) {
                // Workout Title and Time
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.name.isEmpty ? "Workout Session" : session.name)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(Theme.textSecondary)
                        Text(session.timestamp.formatted(date: .long, time: .shortened))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("•")
                            .foregroundColor(Theme.textSecondary)
                        
                        Image(systemName: "clock")
                            .foregroundColor(Theme.textSecondary)
                        Text(durationString)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 40)
                
                // Telemetry Stats Row
                HStack(spacing: 24) {
                    // Tonnage
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Volume Moved")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                        Text(String(format: "%.0f %@", totalTonnage, unit.uppercased()))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(Theme.warningOrange)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                    
                    // Intensity Score
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Intensity Score")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                        Text("\(session.totalIntensityScore) Pts")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                    
                    // Failure Count
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Failure Sets")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                        Text("\(failureCount) Sets")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(failureCount > 0 ? Theme.dangerRed : Theme.apexGreen)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 40)
                
                // Completed Exercises Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises Logged")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    VStack(spacing: 12) {
                        ForEach(session.exercises.prefix(6)) { wex in
                            let name = wex.exerciseRef?.name ?? "Unknown Exercise"
                            let completedSets = wex.sets.filter { $0.isCompleted }
                            let maxWeight = completedSets.map { $0.weight }.max() ?? 0.0
                            
                            HStack {
                                Text(name)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(completedSets.count) Sets \(maxWeight > 0 ? String(format: "(Max: %.0f %s)", maxWeight, unit.lowercased()) : "")")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.midnightMatte.opacity(0.4))
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border.opacity(0.2), lineWidth: 1))
                        }
                        
                        if session.exercises.count > 6 {
                            HStack {
                                Spacer()
                                Text("+ \(session.exercises.count - 6) More Exercises Logged")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 24)
            
            Spacer()
            
            // Footer
            HStack {
                Text("Designed for Athletics")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text("friendlyfitness.app")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(Theme.midnightMatte)
        }
        .frame(width: 1200, height: 1200)
        .background(Theme.midnightMatte)
    }
}
