import Foundation

struct CoachInsight {
    let capacityScore: Int // 0 - 100
    let focusMuscle: String
    let trainingDirectives: [String]
    let coachMessage: String
    let progressiveOverloadTip: String
}

final class AICoachService {
    static let shared = AICoachService()
    
    private init() {}
    
    func generateInsight(sessions: [WorkoutSession], settings: UserSettings, recoveryScore: Double) -> CoachInsight {
        // 1. Analyze recovery
        let capacity = Int(recoveryScore * 100)
        
        // 2. Identify focus muscles from historical sessions
        var muscleFrequencies: [String: Int] = [:]
        for session in sessions {
            for exercise in session.exercises {
                let muscle = exercise.normalizedTargetMuscle
                if !muscle.isEmpty && muscle != "UNKNOWN" {
                    muscleFrequencies[muscle, default: 0] += 1
                }
            }
        }
        
        let allMuscles = MuscleGroup.all
        var focus = "Chest"
        var minCount = Int.max
        for muscle in allMuscles {
            let count = muscleFrequencies[muscle] ?? 0
            if count < minCount {
                minCount = count
                focus = muscle
            }
        }
        
        // 3. Formulate directives based on settings & training phase
        let phase = settings.currentPhase
        var directives: [String] = []
        var message = ""
        var overloadTip = ""
        
        if capacity >= 80 {
            directives = [
                "Target high-intensity working sets to absolute failure.",
                "Incorporate Rest-Pause sets on final compound exercises.",
                "Maintain 4-second eccentric tempo profiles for maximum tension."
            ]
            message = "System state is OPTIMAL. Neuromuscular recovery is peak. Today is the day to push for historical milestones."
            overloadTip = "Increase load on your primary \(focus) lift by 2.5–5 lbs or target +1 rep on your heavy set."
        } else if capacity >= 50 {
            directives = [
                "Focus on strict form and mind-muscle connection.",
                "Leave 1-2 Reps in Reserve (RIR) on primary compound lifts.",
                "Ensure full 2-minute rest intervals between working sets."
            ]
            message = "System state is STABLE. Maintain volume baseline. Focus on pristine execution without failing."
            overloadTip = "Keep the weight identical to last week, but execute all reps with perfect control."
        } else {
            directives = [
                "De-load weights by 10-15% across all exercises.",
                "Avoid forced reps, negatives, or failure sets.",
                "Focus heavily on stretching and mobility flows."
            ]
            message = "System state is COMPROMISED. Central Nervous System fatigue warning. Today should be a structured recovery session or active de-load."
            overloadTip = "Reduce training intensity. Prioritize long-term structural integrity."
        }
        
        if phase == "Strength" {
            directives.insert("Keep rep ranges in the 3-5 bracket with 3+ minute rest times.", at: 0)
        } else if phase == "Cutting" {
            directives.insert("Prioritize training density; keep rest timers strict.", at: 0)
        }
        
        return CoachInsight(
            capacityScore: capacity,
            focusMuscle: focus,
            trainingDirectives: directives,
            coachMessage: message,
            progressiveOverloadTip: overloadTip
        )
    }
    
    func calculateOverloadTarget(for exerciseName: String, sessions: [WorkoutSession], settings: UserSettings) -> (targetWeight: Double, targetReps: Int, note: String) {
        let unit = settings.weightUnit.lowercased()
        let step = unit == "kg" ? 2.5 : 5.0
        
        // Find matching exercises in past sessions
        var lastWeight = 0.0
        var lastReps = 8
        var hitFailureLastTime = false
        
        // Sort sessions by date (latest first to find the most recent matching exercise)
        let sortedSessions = sessions.sorted(by: { $0.timestamp > $1.timestamp })
        
        for session in sortedSessions {
            if let matchedEx = session.exercises.first(where: { $0.loggedName.lowercased() == exerciseName.lowercased() || $0.exerciseRef?.name.lowercased() == exerciseName.lowercased() }) {
                let completedSets = matchedEx.sets.filter { $0.isCompleted }
                if !completedSets.isEmpty {
                    // Find the heaviest completed set
                    if let maxSet = completedSets.max(by: { $0.weight < $1.weight }) {
                        lastWeight = maxSet.weight
                        lastReps = maxSet.reps
                        hitFailureLastTime = maxSet.hitFailure
                    }
                    break
                }
            }
        }
        
        if lastWeight <= 0 {
            return (0.0, 8, "No past logs. Establish a baseline today!")
        }
        
        let phase = settings.currentPhase.lowercased()
        
        if hitFailureLastTime {
            return (
                lastWeight,
                lastReps,
                "Last set hit failure. Solidify \(String(format: "%g", lastWeight)) \(unit) for \(lastReps) reps before adding weight."
            )
        }
        
        if phase.contains("strength") {
            if lastReps >= 5 {
                let nextWeight = lastWeight + step
                return (
                    nextWeight,
                    3,
                    "Strength target met. Load \(String(format: "%g", nextWeight)) \(unit) for 3–5 reps."
                )
            } else {
                return (
                    lastWeight,
                    lastReps + 1,
                    "Strength progression: Lift \(String(format: "%g", lastWeight)) \(unit) for \(lastReps + 1) reps."
                )
            }
        } else {
            // Hypertrophy/Cutting/Recomp default: 8-12 reps target
            if lastReps >= 12 {
                let nextWeight = lastWeight + step
                return (
                    nextWeight,
                    8,
                    "Hypertrophy ceiling hit. Step up to \(String(format: "%g", nextWeight)) \(unit) for 8 reps."
                )
            } else {
                return (
                    lastWeight,
                    lastReps + 1,
                    "Rep progression: Lift \(String(format: "%g", lastWeight)) \(unit) for \(lastReps + 1) reps."
                )
            }
        }
    }
}
