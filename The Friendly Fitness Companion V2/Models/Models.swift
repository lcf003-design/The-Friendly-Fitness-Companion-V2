import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var targetMuscle: String = "" // e.g., "Chest", "Quads"
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
    var id: UUID = UUID()
    var name: String = ""
    var timestamp: Date = Date()
    var endTime: Date? // Used for HealthKit duration calculation
    var rpe: Int = 8 // 1-10
    
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []
    
    init(id: UUID = UUID(), name: String, timestamp: Date = Date(), endTime: Date? = nil, rpe: Int = 8, exercises: [WorkoutExercise] = []) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.endTime = endTime
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
    var id: UUID = UUID()
    var exerciseRef: Exercise?
    
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []
    
    init(id: UUID = UUID(), exerciseRef: Exercise? = nil, sets: [ExerciseSet] = []) {
        self.id = id
        self.exerciseRef = exerciseRef
        self.sets = sets
    }
}

@Model
final class ExerciseSet {
    var id: UUID = UUID()
    var weight: Double = 0.0
    var reps: Int = 0
    var hitFailure: Bool = false
    var forcedReps: Int = 0
    var negatives: Int = 0
    var restPauses: [Int] = [] // Array of reps achieved after pauses
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), weight: Double, reps: Int, hitFailure: Bool = false, forcedReps: Int = 0, negatives: Int = 0, restPauses: [Int] = [], isCompleted: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.hitFailure = hitFailure
        self.forcedReps = forcedReps
        self.negatives = negatives
        self.restPauses = restPauses
        self.isCompleted = isCompleted
    }
}

@Model
final class UserSettings {
    var id: UUID = UUID()
    var userName: String = ""
    var bodyWeight: Double = 0.0
    var weightUnit: String = "lb" // "lb" or "kg"
    var isSeeded: Bool = false
    
    // Phase 6 Expansion Settings
    var isRestTimerEnabled: Bool = true
    var isHapticMetronomeEnabled: Bool = false
    var tempoProfile: String = "" // e.g., "Mentzer HIT (4-2-4)"
    var themePreference: Int = 0 // 0 = System, 1 = Light, 2 = Dark
    var isHealthKitSyncEnabled: Bool = false
    
    // Phase 8 Athlete Biometrics
    var bodyFatPercentage: Double = 0.0
    var heightInches: Int = 0
    var trainingAgeYears: Int = 0
    var currentPhase: String = "Hypertrophy" // e.g., "Hypertrophy", "Strength", "Cutting", "Recomp"
    
    init(id: UUID = UUID(), userName: String = "Athlete", bodyWeight: Double = 0.0, weightUnit: String = "lb", isSeeded: Bool = false, isRestTimerEnabled: Bool = true, isHapticMetronomeEnabled: Bool = false, tempoProfile: String = "Mentzer HIT (4-2-4)", themePreference: Int = 0, isHealthKitSyncEnabled: Bool = false, bodyFatPercentage: Double = 0.0, heightInches: Int = 0, trainingAgeYears: Int = 0, currentPhase: String = "Hypertrophy") {
        self.id = id
        self.userName = userName
        self.bodyWeight = bodyWeight
        self.weightUnit = weightUnit
        self.isSeeded = isSeeded
        
        self.isRestTimerEnabled = isRestTimerEnabled
        self.isHapticMetronomeEnabled = isHapticMetronomeEnabled
        self.tempoProfile = tempoProfile
        self.themePreference = themePreference
        self.isHealthKitSyncEnabled = isHealthKitSyncEnabled
        
        self.bodyFatPercentage = bodyFatPercentage
        self.heightInches = heightInches
        self.trainingAgeYears = trainingAgeYears
        self.currentPhase = currentPhase
    }
}

@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    
    // Store references to the standard exercises that make up this routine
    var targetExercises: [Exercise] = []
    
    init(id: UUID = UUID(), name: String, targetExercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.targetExercises = targetExercises
    }
}

@Model
final class FastingSession {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var targetHours: Int = 16
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), startTime: Date = Date(), targetHours: Int = 16, isCompleted: Bool = false) {
        self.id = id
        self.startTime = startTime
        self.targetHours = targetHours
        self.isCompleted = isCompleted
    }
}
