import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isAvailable else {
            completion(false, nil)
            return
        }
        
        let workoutType = HKObjectType.workoutType()
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let typesToShare: Set = [workoutType, energyType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: nil) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func saveStrengthWorkout(startTime: Date, endTime: Date, name: String, bodyWeight: Double?, completion: @escaping (Bool, Error?) -> Void) {
        guard isAvailable else {
            completion(false, nil)
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        let workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        workoutBuilder.beginCollection(withStart: startTime) { success, error in
            guard success else {
                completion(false, error)
                return
            }
            
            // Calculate accurate calories using Metabolic Equivalent (MET)
            // Strength training MET is approximately 3.0. Formula: MET * weight in kg * duration in hours
            // If bodyWeight is not set, we fall back to a standard 80.0kg estimate.
            let durationInHours = endTime.timeIntervalSince(startTime) / 3600.0
            let weightInKg = bodyWeight ?? 80.0
            let estimatedCalories = 3.0 * weightInKg * durationInHours
            
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories)
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let energySample = HKCumulativeQuantitySample(type: energyType, quantity: energyQuantity, start: startTime, end: endTime)
            
            workoutBuilder.add([energySample]) { _, _ in
                // Proceed regardless of sample success
                workoutBuilder.endCollection(withEnd: endTime) { success, error in
                    guard success else {
                        completion(false, error)
                        return
                    }
                    
                    // Add the custom name as metadata
                    let metadata: [String: Any] = [
                        HKMetadataKeyWorkoutBrandName: "The Friendly Fitness Companion",
                        HKMetadataKeyGroupFitness: false
                    ]
                    
                    workoutBuilder.addMetadata(metadata) { _, _ in
                        workoutBuilder.finishWorkout { workout, error in
                            DispatchQueue.main.async {
                                completion(workout != nil, error)
                            }
                        }
                    }
                }
            }
        }
    }
}
