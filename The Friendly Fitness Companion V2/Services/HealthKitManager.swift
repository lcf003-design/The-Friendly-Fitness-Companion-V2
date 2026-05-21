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
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let typesToShare: Set = [workoutType, energyType]
        let typesToRead: Set = [hrvType, sleepType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
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
    
    func fetchLatestHRV(completion: @escaping (Double?, Error?) -> Void) {
        guard isAvailable else {
            completion(nil, nil)
            return
        }
        
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, error)
                return
            }
            let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            DispatchQueue.main.async {
                completion(value, nil)
            }
        }
        healthStore.execute(query)
    }
    
    func fetchLatestSleepHours(completion: @escaping (Double?, Error?) -> Void) {
        guard isAvailable else {
            completion(nil, nil)
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -1, to: now)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictEndDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                completion(nil, error)
                return
            }
            
            var totalAsleepTime: TimeInterval = 0
            for sample in sleepSamples {
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    totalAsleepTime += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }
            
            let hours = totalAsleepTime / 3600.0
            DispatchQueue.main.async {
                completion(hours > 0 ? hours : nil, nil)
            }
        }
        healthStore.execute(query)
    }
}
