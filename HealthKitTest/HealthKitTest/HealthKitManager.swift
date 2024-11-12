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
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!, // 혈중 산소
            
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)! //걷기 + 달리기 거리
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success , error in
            if error != nil {
                print("=============requestAuthorization error=============")
                print(error.debugDescription)
                print("====================================================")
                completion(false, error)
                return
            } else {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, nil)
                }
            }
        }
        
    }
}

//MARK: 모델화
extension HealthKitManager {
    func getStepModel(completion: @escaping ((Step?) -> Void)) {
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
                let startDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let endDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                results.enumerateStatistics(from: startDate, to: endDate) { (statistics, stop) in
                    if let quantity = statistics.sumQuantity() {
                        let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: statistics.startDate) ?? Date()  // GMT+9로 변환
                        let count = quantity.doubleValue(for: HKUnit.count())
                        let stepCount = Int(count)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let stepDate = dateFormatter.string(from: koreanStartDate)
                        
                        let stepModel = Step(count: stepCount, date: stepDate)
                        completion(stepModel)
                    } else {
                        completion(nil)
                    }
                }
            } else {
                completion(nil)
            }
        }
        
        healthStore.execute(stepsCumulativeQuery)
    }
    
    func getBloodPressureModel(completion: @escaping (([BloodPressure]?)) -> Void) {
        guard let type = HKQuantityType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.bloodPressure),
              let systolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureDiastolic) else { return }

        let calendar = Calendar.current
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 7
        
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.day = 1

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        var bloodPressureModel = [BloodPressure]()

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
            if let samples = samples as? [HKCorrelation] {
                for sample in samples {
                    var systolicMmHg = 0
                    var diastolicMmHg = 0
                    
                    if let systolicType = sample.objects(for: systolicType).first as? HKQuantitySample {
                        systolicMmHg = Int(systolicType.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                    }
                    
                    if let diastolicType = sample.objects(for: diastolicType).first as? HKQuantitySample {
                        diastolicMmHg = Int(diastolicType.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                    }
                    
                    let startDate = sample.startDate
                    let dateFormatter = DateFormatter()
                    if calendar.component(.second, from: startDate) > 0 {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    } else {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:00.000"
                    }
                    
                    let bloodPressureDate = dateFormatter.string(from: startDate)
                    
                    let model = BloodPressure(bloodPressureMin: diastolicMmHg, bloodPressureMax: systolicMmHg, analysisAt: bloodPressureDate)
                    bloodPressureModel.append(model)
                }
                completion(bloodPressureModel)
                
            } else {
                completion(nil)
                
            }
        }
        
        healthStore.execute(query)
    }
    
    func getOxygenSaturationModel(completion: @escaping ([OxygenSaturation]?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let calendar = Calendar.current
        let endDate = Date()
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 7
        
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        var oxygenSaturationModel = [OxygenSaturation]()
        
        let query = HKSampleQuery(sampleType: oxygenSaturationType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
           
            if let samples = samples as? [HKQuantitySample] {
                for sample in samples {
                    var percent = sample.quantity.doubleValue(for: HKUnit.percent())
                    percent *= 100
                    let oxygenSaturationPercent = Int(percent)
                    
                    let startDate = sample.startDate
                    
                    let dateFormatter = DateFormatter()
                    if calendar.component(.second, from: startDate) > 0 {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    } else {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:00.000"
                    }
                    let oxygenSaturationDate = dateFormatter.string(from: startDate)
                    
                    let model = OxygenSaturation(oxygenSaturation: oxygenSaturationPercent, analysisAt: oxygenSaturationDate)
                    oxygenSaturationModel.append(model)
                }
                
                completion(oxygenSaturationModel)
            } else {
                completion([OxygenSaturation]())
            }
        }

        healthStore.execute(query)
    }
    
    func getBloodGlucoseModel(completion: @escaping ([BloodGluscose]?) -> Void) {
        let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
        
        let calendar = Calendar.current
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 7
        
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        var bloodGlucoseModel = [BloodGluscose]()

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            if let samples = samples as? [HKQuantitySample] {
                for sample in samples {
                    var glucose = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
                    let mgDL = Int(glucose)
                    
                    let startDate = sample.startDate
                    
                    let dateFormatter = DateFormatter()
                    if calendar.component(.second, from: startDate) > 0 {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    } else {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:00.000"
                    }
                    let glucoseDate = dateFormatter.string(from: startDate)
                    
                    let model = BloodGluscose(bloodGluscose: mgDL, analysisAt: glucoseDate)
                    bloodGlucoseModel.append(model)
                }
                
                completion(bloodGlucoseModel)
            } else {
                completion([BloodGluscose]())
            }
        }
        
        healthStore.execute(query)
    }
    
    func getHeartRateModel(completion: @escaping ([HeartRate]) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                
        let calendar = Calendar.current
        var timeZone = TimeZone(identifier: "Asia/Seoul") // Setting to KST
        
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        let anchorDate = calendar.date(from: anchorComponents)!
        
        var heartRateModel = [HeartRate]()
        
        let query = HKStatisticsCollectionQuery(quantityType: heartRateType,
                                                quantitySamplePredicate: nil,
                                                options: [.discreteMin, .discreteMax, .discreteAverage],
                                                anchorDate: anchorDate,
                                                intervalComponents: dateComponents)
        
        query.initialResultsHandler = { query, result, error in
            result?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let minimum = statistics.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let heartRateMin = Int(minimum)
                let maximum = statistics.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let heartRateMax = Int(maximum)
                let average = statistics.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let heartRateAvg = Int(average)
                let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: statistics.startDate) ?? Date()
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                let heartRateDate = dateFormatter.string(from: koreanStartDate)
                
                let model = HeartRate(heartRateMin: heartRateMin, heartRateMax: heartRateMax, heartRateAvg: heartRateAvg, analysisAt: heartRateDate)
                
                if heartRateAvg > 0 {
                    heartRateModel.append(model)
                }
            }
            
            completion(heartRateModel)
        }
        
        healthStore.execute(query)
    }
    
    func getExerciseModel(completion: @escaping ([Exercise]?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 17
        guard let startDate = calendar.date(from: startDateComponents) else { return }

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        var exerciseModel = [Exercise]()
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
            
            if let samples = samples as? [HKWorkout] {
                for sample in samples {
                    let workoutName = sample.workoutActivityType.name
                    let rawValue = sample.workoutActivityType.rawValue
                    let exerciseId = Int(rawValue)
                    let duration = sample.duration
                    let hour = Int(duration)
                    let kcal = sample.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                    let meter = sample.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0.0
                    let distance = Int(meter)
                    let endDate = sample.endDate
                    
                    let dateFormatter = DateFormatter()
                    if calendar.component(.second, from: startDate) > 0 {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    } else {
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:00.000"
                    }
                    let exerciseEndDate = dateFormatter.string(from: endDate)
                    
                    let model = Exercise(exerciseID: exerciseId, burnedKcal: kcal, exerciseHour: hour, distance: distance, count: 0, endTime: exerciseEndDate)
                    exerciseModel.append(model)
                }
                
                completion(exerciseModel)
            }
        }
        
        healthStore.execute(query)
    }
}


// MARK: 걸음수
extension HealthKitManager {
    func getTodayStep(completion: @escaping (Double) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let startDate = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, 
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, _ in
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
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 2
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        //guard let startDate = calendar.date(byAdding: .day, value: -2, to: Date()) else { return }
        
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
                        completion(false, startDate, 0)
                    }
                }
            } else {
                completion(false, nil, 0)
            }
        }
        
        healthStore.execute(stepsCumulativeQuery)
    }
    
    func getDistanceCountPerDay(beforeDays: Int, completion: @escaping (Bool, Date?, Double) -> ()) {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        let anchorDate = calendar.date(from: anchorComponents)!
        
        let stepsCumulativeQuery = HKStatisticsCollectionQuery(quantityType: distanceType,
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
                        let distance = quantity.doubleValue(for: HKUnit.meter())
                        
                        completion(true, koreanStartDate, distance)
                    } else {
                        completion(false, startDate, 0)
                    }
                }
            } else {
                completion(false, nil, 0)
            }
        }
        
        healthStore.execute(stepsCumulativeQuery)
    }
    
    func getStepsDuringWorkout(startDate: Date, endDate: Date, completion: @escaping (Double?, Error?) -> Void) {
        // 걸음 수 타입 정의
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        // 해당 시간대에 걸음 수를 쿼리하기 위한 predicate 설정
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        // 통계 쿼리 생성 (cumulativeSum 옵션 사용)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, result, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            // 걸음 수 데이터 처리
            if let sum = result?.sumQuantity() {
                let steps = sum.doubleValue(for: HKUnit.count())
                completion(steps, nil)
            } else {
                completion(nil, nil)
            }
        }
        
        // HealthKit 쿼리 실행
        healthStore.execute(query)
    }
    
    func getWalkingWorkouts(completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -140, to: now) else {
            completion(nil, NSError(domain: "HealthKitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid start date"]))
            return
        }

        // 운동 유형 필터 (걷기, 달리기)
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        // HKWorkoutActivityType을 걷기와 달리기로 필터링
        let activityPredicate = HKQuery.predicateForWorkouts(with: .walking)
        
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, activityPredicate])
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: combinedPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
            guard let samples = samples as? [HKWorkout], error == nil else {
                completion(nil, error)
                return
            }
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }

}

// MARK: 몸무게
extension HealthKitManager {
    func getAllWeight(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let bodyWeightType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Body weight type not available"]))
            return
        }
        
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
        guard let startDate = calendar.date(byAdding: .day, value: -14, to: now) else { return }
        
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
    
    func getLastWeight(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let bodyWeightType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Body weight type not available"]))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: bodyWeightType,
                                  predicate: predicate,
                                  limit: 1,
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
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 14
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
//        guard let startDate = calendar.date(byAdding: .day, value: -14, to: now) else {
//            completion(nil, NSError(domain: "HealthKitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid start date"]))
//            return
//        }

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
    func getPeriodBloodGlucose(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
        
        let calendar = Calendar.current
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 7
        
        //guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else { return }
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")

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
    
    func getLimitBloodGlucose(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -300, to: endDate) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
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
    func getHeartRateData(completion: @escaping ([HKSample]?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                completion(samples, error)
            }
                
        healthStore.execute(query)
    }
    
    func getHeartRateMaxMin(completion: @escaping (HKStatistics?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let calendar = Calendar.current
        let endDate = Date()
        
        //guard let startDate = calendar.date(byAdding: .hour, value: -14, to: endDate) else { return }
        //let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
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
    
    func getHeartRateEveryDay(completion: @escaping ([(date: Date, min: Double, max: Double, avg: Double)]?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                
        let calendar = Calendar.current
        var timeZone = TimeZone(identifier: "Asia/Seoul") // Setting to KST
        
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        let anchorDate = calendar.date(from: anchorComponents)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: heartRateType,
                                                quantitySamplePredicate: nil,
                                                options: [.discreteMin, .discreteMax, .discreteAverage],
                                                anchorDate: anchorDate,
                                                intervalComponents: dateComponents)
        
        query.initialResultsHandler = { query, result, error in
            guard let result = result, error == nil else {
                completion(nil, error)
                return
            }
            
            var heartRateData: [(date: Date, min: Double, max: Double, avg: Double)] = []
            
            result.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let minHeartRate = statistics.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let maxHeartRate = statistics.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let avgHeartRate = statistics.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: statistics.startDate)  // GMT+9로 변환
                let date = statistics.startDate.addingTimeInterval(TimeInterval(timeZone!.secondsFromGMT(for: statistics.startDate)))
                
                heartRateData.append((date: koreanStartDate ?? date, min: minHeartRate, max: maxHeartRate, avg: avgHeartRate))
            }
            
            completion(heartRateData, nil)
        }
        
        healthStore.execute(query)
    }
    
    func getHeartRateHourly(completion: @escaping ([(date: Date, min: Double, max: Double, avg: Double)]?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: "Asia/Seoul") // Setting to KST
        
        let endDate = Date()
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 2
        
        //guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else { return }
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.hour = 1  // One hour interval

        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        //let anchorDate = calendar.date(from: anchorComponents)!
        let anchorDate = calendar.startOfDay(for: startDate)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: heartRateType,
                                                quantitySamplePredicate: nil,
                                                options: [.discreteMin, .discreteMax, .discreteAverage],
                                                anchorDate: anchorDate,
                                                intervalComponents: dateComponents)
        
        query.initialResultsHandler = { query, result, error in
            guard let result = result, error == nil else {
                completion(nil, error)
                return
            }
            
            var heartRateData: [(date: Date, min: Double, max: Double, avg: Double)] = []
            
            result.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let minHeartRate = statistics.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let maxHeartRate = statistics.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let avgHeartRate = statistics.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0.0
                let date = statistics.startDate.addingTimeInterval(TimeInterval(timeZone!.secondsFromGMT(for: statistics.startDate)))
                
                heartRateData.append((date: date, min: minHeartRate, max: maxHeartRate, avg: avgHeartRate))
            }
            
            completion(heartRateData, nil)
        }
        
        healthStore.execute(query)
    }

}

extension HealthKitManager {
    func getPeriodBloodPressure(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let type = HKQuantityType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.bloodPressure),
              let systolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureDiastolic) else { return }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }

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
    
    func getLastBloodPressure(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let type = HKQuantityType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.bloodPressure),
              let systolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureDiastolic) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
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
}

extension HealthKitManager {
    func getAllOxygenSaturation(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let calendar = Calendar.current
        let endDate = Date()
        //guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.day! -= 7
        
        //guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else { return }
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: oxygenSaturationType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let sample = samples as? [HKQuantitySample] else {
                completion(nil, nil)
                return
            }

            completion(sample, nil)
        }

        healthStore.execute(query)
    }
    
    func getPeriodAvgOxygenSaturation(completion: @escaping (HKStatistics?, Error?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            
        let query = HKStatisticsQuery(quantityType: oxygenSaturationType, quantitySamplePredicate: predicate, options: [.discreteMin, .discreteMax, .discreteAverage]) { (query, result, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            completion(result, nil)
        }
        
        healthStore.execute(query)
    }
    
    func getRecentOxygenSaturation(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: oxygenSaturationType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let sample = samples as? [HKQuantitySample] else {
                completion(nil, nil)
                return
            }

            completion(sample, nil)
        }

        healthStore.execute(query)
    }
    
    func getEverydayOxygenSaturation(completion: @escaping ([(date: Date, min: Double, max: Double, avg: Double)]?, Error?) -> Void) {
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: "Asia/Seoul") // Setting to KST
        
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.timeZone = TimeZone(identifier: "Asia/Seoul")
        let anchorDate = calendar.date(from: anchorComponents)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: oxygenSaturationType,
                                                quantitySamplePredicate: nil,
                                                options: [.discreteMin, .discreteMax, .discreteAverage],
                                                anchorDate: anchorDate,
                                                intervalComponents: dateComponents)
        
        query.initialResultsHandler = { query, result, error in
            guard let result = result, error == nil else {
                completion(nil, error)
                return
            }
            
            var heartRateData: [(date: Date, min: Double, max: Double, avg: Double)] = []
            
            result.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let minHeartRate = statistics.minimumQuantity()?.doubleValue(for: HKUnit.percent()) ?? 0.0
                let maxHeartRate = statistics.maximumQuantity()?.doubleValue(for: HKUnit.percent()) ?? 0.0
                let avgHeartRate = statistics.averageQuantity()?.doubleValue(for: HKUnit.percent()) ?? 0.0
                let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: statistics.startDate)  // GMT+9로 변환
                let date = statistics.startDate.addingTimeInterval(TimeInterval(timeZone!.secondsFromGMT(for: statistics.startDate)))
                
                heartRateData.append((date: koreanStartDate ?? date, min: minHeartRate, max: maxHeartRate, avg: avgHeartRate))
            }
            
            completion(heartRateData, nil)
        }
        
        healthStore.execute(query)
    }
}
