import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var targetMuscle: String = "" // e.g., "Chest", "Quads"
    var notes: String?
    var defaultRestTime: Int = 120 // Default rest time in seconds
    
    @Relationship(inverse: \WorkoutExercise.exerciseRef)
    var loggedInstances: [WorkoutExercise]?
    
    init(id: UUID = UUID(), name: String, targetMuscle: String, notes: String? = nil, defaultRestTime: Int = 120) {
        self.id = id
        self.name = name
        self.targetMuscle = targetMuscle
        self.notes = notes
        self.defaultRestTime = defaultRestTime
    }
    
    var normalizedTargetMuscle: String {
        let muscle = targetMuscle
        if muscle == "Arms" {
            let lowerName = name.lowercased()
            if lowerName.contains("bicep") || lowerName.contains("curl") || lowerName.contains("hammer") {
                return "Biceps"
            } else if lowerName.contains("tricep") || lowerName.contains("pushdown") || lowerName.contains("extension") || lowerName.contains("skullcrusher") {
                return "Triceps"
            } else {
                return "Biceps"
            }
        } else if muscle == "Lats" {
            return "Back"
        } else if muscle == "Core" {
            return "Abs"
        }
        return muscle
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
    
    var loggedName: String = ""
    var loggedTargetMuscle: String = ""
    var supersetGroupId: UUID? = nil
    
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []
    
    init(id: UUID = UUID(), exerciseRef: Exercise? = nil, sets: [ExerciseSet] = [], supersetGroupId: UUID? = nil) {
        self.id = id
        self.exerciseRef = exerciseRef
        self.loggedName = exerciseRef?.name ?? "UNKNOWN"
        self.loggedTargetMuscle = exerciseRef?.targetMuscle ?? "UNKNOWN"
        self.sets = sets
        self.supersetGroupId = supersetGroupId
    }
    
    var normalizedTargetMuscle: String {
        let muscle = loggedTargetMuscle.isEmpty ? (exerciseRef?.targetMuscle ?? "UNKNOWN") : loggedTargetMuscle
        if muscle == "Arms" {
            let name = loggedName.isEmpty ? (exerciseRef?.name ?? "") : loggedName
            let lowerName = name.lowercased()
            if lowerName.contains("bicep") || lowerName.contains("curl") || lowerName.contains("hammer") {
                return "Biceps"
            } else if lowerName.contains("tricep") || lowerName.contains("pushdown") || lowerName.contains("extension") || lowerName.contains("skullcrusher") {
                return "Triceps"
            } else {
                return "Biceps"
            }
        } else if muscle == "Lats" {
            return "Back"
        } else if muscle == "Core" {
            return "Abs"
        }
        return muscle
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
    var setType: String = "working" // "working", "warmup", "drop"
    // CloudKit doesn't support primitive arrays, so we store it as a comma-separated string
    var restPausesData: String = ""
    var notes: String = ""
    
    // Cardio metrics
    var cardioDistance: Double = 0.0
    var cardioDurationSeconds: Int = 0
    var cardioCalories: Int = 0
    
    // Computed property for UI usage
    var restPauses: [Int] {
        get {
            guard !restPausesData.isEmpty else { return [] }
            return restPausesData.split(separator: ",").compactMap { Int($0) }
        }
        set {
            restPausesData = newValue.map { String($0) }.joined(separator: ",")
        }
    }
    
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), weight: Double, reps: Int, hitFailure: Bool = false, forcedReps: Int = 0, negatives: Int = 0, restPauses: [Int] = [], isCompleted: Bool = false, setType: String = "working", cardioDistance: Double = 0.0, cardioDurationSeconds: Int = 0, cardioCalories: Int = 0) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.hitFailure = hitFailure
        self.forcedReps = forcedReps
        self.negatives = negatives
        self.isCompleted = isCompleted
        self.setType = setType
        self.cardioDistance = cardioDistance
        self.cardioDurationSeconds = cardioDurationSeconds
        self.cardioCalories = cardioCalories
        
        // This setter triggers the data population
        self.restPauses = restPauses
    }
}

@Model
final class UserSettings {
    var id: UUID = UUID()
    var userName: String = ""
    var bodyWeight: Double = 0.0
    var weightUnit: String = "lb" // "lb" or "kg"
    var isSeeded: Bool = false
    var isOnboarded: Bool = false
    
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
    
    // V2 Expanded Biometrics
    var userAgeYears: Int = 25
    var activityLevel: String = "Moderate"
    
    // Ghost Tracking
    var ghostTrackingPreference: Int = 0 // 0 = Most Recent, 1 = All-Time PR
    
    // Recovery Telemetry Override
    var isRecoveryOverridden: Bool = false
    var manualRecoveryScore: Double = 0.8 // Default to 80%
    
    // Premium Gym Log Fields
    var activeWorkoutSessionId: UUID? = nil
    var availablePlatesCSV: String = "45,35,25,10,5,2.5"
    
    // V2 Weekly Fasting schedule targets Mon-Sun (e.g. 16,16,16,16,16,16,16)
    var weeklyFastingScheduleCSV: String = "16,16,16,16,16,16,16"
    
    // Barbell Settings
    var barbellType: String = "Olympic Bar (45 lb)"
    var barbellWeight: Double = 45.0
    
    init(id: UUID = UUID(), userName: String = "Athlete", bodyWeight: Double = 0.0, weightUnit: String = "lb", isSeeded: Bool = false, isOnboarded: Bool = false, isRestTimerEnabled: Bool = true, isHapticMetronomeEnabled: Bool = false, tempoProfile: String = "Mentzer HIT (4-2-4)", themePreference: Int = 0, isHealthKitSyncEnabled: Bool = false, bodyFatPercentage: Double = 0.0, heightInches: Int = 0, trainingAgeYears: Int = 0, currentPhase: String = "Hypertrophy", ghostTrackingPreference: Int = 0, isRecoveryOverridden: Bool = false, manualRecoveryScore: Double = 0.8, activeWorkoutSessionId: UUID? = nil, availablePlatesCSV: String = "45,35,25,10,5,2.5", userAgeYears: Int = 25, activityLevel: String = "Moderate", weeklyFastingScheduleCSV: String = "16,16,16,16,16,16,16", barbellType: String = "Olympic Bar (45 lb)", barbellWeight: Double = 45.0) {
        self.id = id
        self.userName = userName
        self.bodyWeight = bodyWeight
        self.weightUnit = weightUnit
        self.isSeeded = isSeeded
        self.isOnboarded = isOnboarded
        
        self.isRestTimerEnabled = isRestTimerEnabled
        self.isHapticMetronomeEnabled = isHapticMetronomeEnabled
        self.tempoProfile = tempoProfile
        self.themePreference = themePreference
        self.isHealthKitSyncEnabled = isHealthKitSyncEnabled
        
        self.bodyFatPercentage = bodyFatPercentage
        self.heightInches = heightInches
        self.trainingAgeYears = trainingAgeYears
        self.currentPhase = currentPhase
        
        self.userAgeYears = userAgeYears
        self.activityLevel = activityLevel
        
        self.ghostTrackingPreference = ghostTrackingPreference
        
        self.isRecoveryOverridden = isRecoveryOverridden
        self.manualRecoveryScore = manualRecoveryScore
        
        self.activeWorkoutSessionId = activeWorkoutSessionId
        self.availablePlatesCSV = availablePlatesCSV
        self.weeklyFastingScheduleCSV = weeklyFastingScheduleCSV
        self.barbellType = barbellType
        self.barbellWeight = barbellWeight
    }
}

@Model
final class BiometricLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var weight: Double?
    var bodyFatPercentage: Double?
    var notes: String = ""
    
    init(weight: Double? = nil, bodyFat: Double? = nil, notes: String = "") {
        self.id = UUID()
        self.timestamp = Date()
        self.weight = weight
        self.bodyFatPercentage = bodyFat
        self.notes = notes
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
    var endTime: Date? = nil
    
    var energyRating: Int? = nil
    var focusRating: Int? = nil
    var hungerRating: Int? = nil
    var wellnessNotes: String? = nil
    
    init(id: UUID = UUID(), startTime: Date = Date(), targetHours: Int = 16, isCompleted: Bool = false, endTime: Date? = nil, energyRating: Int? = nil, focusRating: Int? = nil, hungerRating: Int? = nil, wellnessNotes: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.targetHours = targetHours
        self.isCompleted = isCompleted
        self.endTime = endTime
        self.energyRating = energyRating
        self.focusRating = focusRating
        self.hungerRating = hungerRating
        self.wellnessNotes = wellnessNotes
    }
}

@Model
final class PhysiquePhoto {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    @Attribute(.externalStorage) var imageData: Data?
    var weightAtTime: Double = 0.0
    var phaseAtTime: String = "Hypertrophy"
    var note: String = ""
    
    init(id: UUID = UUID(), timestamp: Date = Date(), imageData: Data? = nil, weightAtTime: Double = 0.0, phaseAtTime: String = "Hypertrophy", note: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.imageData = imageData
        self.weightAtTime = weightAtTime
        self.phaseAtTime = phaseAtTime
        self.note = note
    }
}

struct MuscleGroup {
    static let all: [String] = [
        "Abs", "Back", "Biceps", "Calves", "Chest",
        "Glutes", "Hamstrings", "Quads", "Shoulders", "Triceps", "Cardio"
    ]
}

@Model
final class WaterLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var amountOz: Double = 0.0
    
    init(id: UUID = UUID(), timestamp: Date = Date(), amountOz: Double) {
        self.id = id
        self.timestamp = timestamp
        self.amountOz = amountOz
    }
}

