//
//  HealthManager.swift
//  HealthKitTest
//
//  Created by 이찬호 on 7/8/24.
//

import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    var hkSamples = [HKQuantitySample]()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!, // 걸음
            HKObjectType.quantityType(forIdentifier: .bodyMass)!, // 체중
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!, // 혈당
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!, // 수축기 혈압
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!, // 이완기 혈압
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!, // 활동 에너지
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!, // 운동 시간
            HKObjectType.workoutType(), // 운동
            HKSeriesType.workoutRoute(), // 운동 경로
            HKQuantityType.quantityType(forIdentifier: .heartRate)!, // 심박수
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)! // 혈중 산소
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success , error in
            completion(success, error)
        }
    }
}

// MARK: 걸음수
extension HealthKitManager {
    func getTodayStep(completion: @escaping (Double) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.count()))
        }
        healthStore.execute(query)
    }
    
    func getTotalStep(completion: @escaping (HKStatistics?, Error?) -> ()) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -14, to: now) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, result, error) in
           
            if let result = result, let sum = result.sumQuantity() {
                let totalSteps = sum.doubleValue(for: HKUnit.count())
                completion(result, nil)
            } else {
                completion(nil, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func getStepCountPerDay(beforeDays: Int, completion: @escaping (Bool, Date?, Double) -> ()) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        let anchorDate = calendar.date(from: anchorComponents)!
        
        let stepsCumulativeQuery = HKStatisticsCollectionQuery(quantityType: stepType,
                                                               quantitySamplePredicate: nil,
                                                               options: .cumulativeSum,
                                                               anchorDate: anchorDate,
                                                               intervalComponents: dateComponents)
        
        stepsCumulativeQuery.initialResultsHandler = { query, results, error in
            if let results = results {
                let startDate = calendar.date(byAdding: .day, value: -beforeDays, to: Date())
                let endDate = Date()
                results.enumerateStatistics(from: startDate!, to: endDate) { (statistics, stop) in
                    if let quantity = statistics.sumQuantity() {
                        let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: statistics.startDate)  // GMT+9로 변환
                        let steps = quantity.doubleValue(for: HKUnit.count())
                        
                        completion(true, koreanStartDate, steps)
                    } else {
                        completion(false, nil, -1)
                    }
                }
            } else {
                print("STEP COUNT DATA NIL")
                completion(false, nil, -1)
            }
        }
        
        healthStore.execute(stepsCumulativeQuery)
    }
}

// MARK: 몸무게
extension HealthKitManager {
    func getAllWeight(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let bodyWeightType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Body weight type not available"]))
            return
        }
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: bodyWeightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }
    
    func getRecentWeight(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let bodyWeightType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Body weight type not available"]))
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -3000, to: now) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: bodyWeightType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }
            completion(samples, error)
        }
                
        healthStore.execute(query)
    }
}

// MARK: 운동
extension HealthKitManager {
    func getAllWorkouts(completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        let workoutType = HKObjectType.workoutType()
        
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -140, to: now) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let workoutQuery = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 2, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                completion(nil, error)
                return
            }
            completion(workouts, nil)
        }
        
        healthStore.execute(workoutQuery)
    }
    
    func getWeeklyWorkouts(completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -14, to: now) else {
            completion(nil, NSError(domain: "HealthKitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid start date"]))
            return
        }

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
            guard let samples = samples as? [HKWorkout], error == nil else {
                completion(nil, error)
                return
            }
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }
    
    func getCalories(for workout: HKWorkout, completion: @escaping (Double) -> Void) {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (_, result, error) in
            var totalCalories = 0.0
            if let result = result, let sum = result.sumQuantity() {
                totalCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                print("운동이름: ",workout.workoutActivityType.name)
                print("칼로리: ", totalCalories)
            }
            completion(totalCalories)
        }
        
        healthStore.execute(query)
    }
}

extension HealthKitManager {
    func fetchOxygenSaturation(completion: @escaping (HKStatistics?, Error?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            
        let query = HKStatisticsQuery(quantityType: oxygenSaturationType, quantitySamplePredicate: predicate, options: [.discreteMin, .discreteMax, .discreteAverage]) { (query, result, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            completion(result, nil)
            
//            let min = result?.minimumQuantity()?.doubleValue(for: HKUnit.percent())
//            let max = result?.maximumQuantity()?.doubleValue(for: HKUnit.percent())
//            let avg = result?.averageQuantity()?.doubleValue(for: HKUnit.percent())
//            
//            completion(min, max, avg, nil)
        }
        
        healthStore.execute(query)
    }
    
    func fetchRecentOxygenSaturation(completion: @escaping (HKQuantitySample?, Error?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: oxygenSaturationType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, nil)
                return
            }

            completion(sample, nil)
        }

        healthStore.execute(query)
    }
}

extension HealthKitManager {
    func fetchHeartRateData(completion: @escaping ([HKSample]?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                completion(samples, error)
            }
                
        healthStore.execute(query)
    }
    
    func fetchHeartRateStatistics(completion: @escaping (HKStatistics?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let calendar = Calendar.current
        let endDate = Date()
        
//        guard let startDate = calendar.date(byAdding: .hour, value: -14, to: endDate) else { return }
//        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
//        
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)  // 오늘 00시
        let predicate = HKQuery.predicateForSamples(withStart: startOfToday, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteMax, .discreteMin]) { (query, result, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let maxHeartRate = result?.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            let minHeartRate = result?.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            completion(result, nil)
        }
        
        healthStore.execute(query)
    }
}

extension HealthKitManager {
    func fetchBloodPressureSamples(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let type = HKQuantityType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.bloodPressure),
              let systolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureDiastolic) else { return }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -300, to: endDate) else { return }

        
        //let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
            if let samples = samples as? [HKCorrelation] {
                for sample in samples {
                    if let systolicType = sample.objects(for: systolicType).first as? HKQuantitySample,
                        let diastolicType = sample.objects(for: diastolicType).first as? HKQuantitySample {
                        self.hkSamples.append(systolicType)
                        self.hkSamples.append(diastolicType)
                    }
                }
                completion(self.hkSamples, nil)
                return
            } else {
                completion(nil, error)
                return
            }
        }
        
        healthStore.execute(query)
    }

    func fetchBloodGlucoseSamples(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -300, to: endDate) else { return }

        //let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }
            
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }
}

extension HealthKitManager {
    
}
