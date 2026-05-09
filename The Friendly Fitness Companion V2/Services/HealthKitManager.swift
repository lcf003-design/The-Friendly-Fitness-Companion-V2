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
    
    func saveStrengthWorkout(startTime: Date, endTime: Date, name: String, completion: @escaping (Bool, Error?) -> Void) {
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
            
            // Note: In a production app, we would calculate exact calories based on user weight and duration.
            // For now, we calculate a standard weight-lifting metabolic equivalent (MET).
            let durationInHours = endTime.timeIntervalSince(startTime) / 3600.0
            let estimatedCalories = 400.0 * durationInHours // Rough estimate
            
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
