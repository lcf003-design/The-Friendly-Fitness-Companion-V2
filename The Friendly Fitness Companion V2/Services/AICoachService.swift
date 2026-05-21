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
                let muscle = exercise.loggedTargetMuscle
                if !muscle.isEmpty && muscle != "UNKNOWN" {
                    muscleFrequencies[muscle, default: 0] += 1
                }
            }
        }
        
        let allMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
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
}
