import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var targetMuscle: String // e.g., "Chest", "Quads"
    var notes: String?
    
    @Relationship(inverse: \WorkoutExercise.exerciseRef)
    var loggedInstances: [WorkoutExercise]?
    
    init(id: UUID = UUID(), name: String, targetMuscle: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.targetMuscle = targetMuscle
        self.notes = notes
    }
}

@Model
final class WorkoutSession {
    var id: UUID
    var name: String
    var timestamp: Date
    var rpe: Int // 1-10
    
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise]
    
    init(id: UUID = UUID(), name: String, timestamp: Date = Date(), rpe: Int = 8, exercises: [WorkoutExercise] = []) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.rpe = rpe
        self.exercises = exercises
    }
    
    // Custom Intensity Score formula
    var totalIntensityScore: Int {
        var score = 0
        for ex in exercises {
            for set in ex.sets {
                var setScore = Double(set.weight) * Double(set.reps) * 0.1
                if set.hitFailure { setScore += 50 }
                setScore += Double(set.forcedReps * 15)
                setScore += Double(set.negatives * 20)
                setScore += Double(set.restPauses.count * 25) // 25 points per rest-pause segment
                score += Int(setScore)
            }
        }
        return score
    }
}

@Model
final class WorkoutExercise {
    var id: UUID
    var exerciseRef: Exercise?
    
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet]
    
    init(id: UUID = UUID(), exerciseRef: Exercise? = nil, sets: [ExerciseSet] = []) {
        self.id = id
        self.exerciseRef = exerciseRef
        self.sets = sets
    }
}

@Model
final class ExerciseSet {
    var id: UUID
    var weight: Double
    var reps: Int
    var hitFailure: Bool
    var forcedReps: Int
    var negatives: Int
    var restPauses: [Int] // Array of reps achieved after pauses
    
    init(id: UUID = UUID(), weight: Double, reps: Int, hitFailure: Bool = false, forcedReps: Int = 0, negatives: Int = 0, restPauses: [Int] = []) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.hitFailure = hitFailure
        self.forcedReps = forcedReps
        self.negatives = negatives
        self.restPauses = restPauses
    }
}

@Model
final class UserSettings {
    var id: UUID
    var weightUnit: String // "lb" or "kg"
    var isSeeded: Bool
    
    init(id: UUID = UUID(), weightUnit: String = "lb", isSeeded: Bool = false) {
        self.id = id
        self.weightUnit = weightUnit
        self.isSeeded = isSeeded
    }
}
