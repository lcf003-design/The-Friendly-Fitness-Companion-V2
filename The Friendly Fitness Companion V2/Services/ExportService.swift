import Foundation
import SwiftData

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    func generateCSV(sessions: [WorkoutSession]) -> URL? {
        var csvString = "Date,Workout Name,Exercise,Set,Weight,Reps,Intensity Score\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        for session in sessions {
            let dateStr = formatter.string(from: session.timestamp)
            let workoutName = session.name.replacingOccurrences(of: ",", with: " ")
            let intensity = session.totalIntensityScore
            
            for exercise in session.exercises {
                let exerciseName = exercise.exerciseRef?.name.replacingOccurrences(of: ",", with: " ") ?? "Unknown"
                
                for (index, set) in exercise.sets.enumerated() {
                    let setNum = index + 1
                    let line = "\(dateStr),\(workoutName),\(exerciseName),\(setNum),\(set.weight),\(set.reps),\(intensity)\n"
                    csvString.append(line)
                }
            }
        }
        
        let fileName = "Workout_History_\(Int(Date().timeIntervalSince1970)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to create CSV: \(error)")
            return nil
        }
    }
}
