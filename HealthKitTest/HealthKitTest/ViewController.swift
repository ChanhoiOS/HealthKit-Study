//
//  ViewController.swift
//  HealthKitTest
//
//  Created by 이찬호 on 7/8/24.
//

import UIKit
import HealthKit

class ViewController: UIViewController {
    
    @IBOutlet weak var authBtn: UIButton!
    var healthKitManager = HealthKitManager.shared
    var healthModel: HealthModel?
    
    var distance = [Double]()
    var count = [Double]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        healthModel = HealthModel(step: [Step](), exercise: [Exercise](), bloodGluscose: [BloodGluscose](), heartRate: [HeartRate](), bloodPressure: [BloodPressure](), oxygenSaturation: [OxygenSaturation]())
    }
    
    @IBAction func requestAuth(_ sender: Any) {
        if HKHealthStore.isHealthDataAvailable() {
            print("=============헬스데이터 사용 가능 장치=============")
            
            healthKitManager.requestAuthorization { (success, error) in
                print("=============requestAuthorization success=============")
                print(success)
                print("======================================================")
                if success {
                    self.requestLifeLog("test007")
                } else {
                    
                }
            }
        } else {
            print("=============헬스데이터 사용 불가 장치=============")
        }
    }
    
    @IBAction func checkAuth(_ sender: Any) {
//        let healthKitTypes = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
//        let auth = self.healthKitManager.healthStore.authorizationStatus(for: healthKitTypes)
//        
//        switch auth {
//        case .notDetermined:
//            print("notDetermined")
//        case .sharingAuthorized:
//            print("sharingAuthorized")
//        case .sharingDenied:
//            print("sharingDenied")
//        default:
//            print("default")
//        }
        
        let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let readDataTypes: Set<HKObjectType> = [bodyMass]

        healthKitManager.healthStore.getRequestStatusForAuthorization(toShare: [], read: readDataTypes) { (status, error) in
            switch status {
            case .unnecessary:
                print("Authorization already granted.")
            case .shouldRequest:
                print("Authorization not yet requested, should request.")
            case .unknown:
                print("Unknown authorization status.")
            @unknown default:
                print("Unhandled case.")
            }
            
            if let error = error {
                print("Error occurred: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func getData(_ sender: Any) {
        self.getAllWeight()
    }
    
}

extension ViewController {
    func requestLifeLog(_ userId: String) {
        healthModel?.userId = userId
        
        requestStepModel()
    }
}

//MARK: 모델화
extension ViewController {
    func requestStepModel() {
        var stepModel = [Step]()
        var index = 0
        
        healthKitManager.getStepModel { model in
            if let model = model {
                stepModel.append(model)
            }
            
            index += 1
            
            if index == 7 {
                self.healthModel?.step = stepModel
                self.requestBloodPressureModel()
            }
        }
    }
    
    func requestBloodPressureModel() {
        healthKitManager.getBloodPressureModel { model in
            if let model = model {
                self.healthModel?.bloodPressure =  model
                
                self.requestOxygenSaturationModel()
            }
        }
    }
    
    func requestOxygenSaturationModel() {
        healthKitManager.getOxygenSaturationModel { model in
            self.healthModel?.oxygenSaturation = model
            
            self.requestBloodGlucoseModel()
        }
    }
    
    func requestBloodGlucoseModel() {
        healthKitManager.getBloodGlucoseModel { model in
            self.healthModel?.bloodGluscose = model
            
            self.requestHeartRateModel()
        }
    }
    
    func requestHeartRateModel() {
        healthKitManager.getHeartRateModel { model in
            self.healthModel?.heartRate = model
            
            self.requestExerciseModel()
        }
    }
    
    func requestExerciseModel() {
        healthKitManager.getExerciseModel { model in
            self.healthModel?.exercise = model
            
            self.uploadModel()
        }
    }
}

extension ViewController {
    func uploadModel() {
        
        NetworkManager.uploadModelData(healthModel ?? HealthModel())
    }
}



//MARK: 걸음수
extension ViewController {
    // HKStatisticsCollectionQuery 를 사용한 날짜별 걸음수
    func requestStep() {
        healthKitManager.getStepCountPerDay(beforeDays: 6) { success, date, count in
            print("걸은 날짜: ", date)
            print("걸음 수: ", count)
        }
    }
    
    func requestTotalStep() {
        healthKitManager.getTotalStep { sample, error in
            let calendar = Calendar.current
            
            let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: sample?.startDate ?? Date())
            let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: sample?.endDate ?? Date())
            print("걸음 시작 날짜: ", koreanStartDate)
            print("걸음 마지막 날짜: ", koreanEndDate)
            print("데이터 시작 날짜: ", sample?.sumQuantity()?.doubleValue(for: HKUnit.count()))
        }
    }
    
    func requestTodayStep() {
        healthKitManager.getTodayStep { count in
            print("count: ", count)
        }
    }
    
    func requestDistance() {
        healthKitManager.getDistanceCountPerDay(beforeDays: 6) { success, date, distance in
            print("걸은 날짜: ", date)
            print("거리: ", distance)
        }
    }
    
    func requestWalkingWorkout() {
        let group = DispatchGroup()
        healthKitManager.getWalkingWorkouts { workouts, error in
            if let error = error {
                print("Error fetching workouts: \(error.localizedDescription)")
            } else if let workouts = workouts {
                let calendar = Calendar.current
                
                for workout in workouts {
                    let workoutName = workout.workoutActivityType.name
                    let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: workout.startDate) ?? Date()
                    let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: workout.endDate) ?? Date()
                    let kcal = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                    let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0.0
                
                    print("운동 시작시간: ", koreanStartDate)
                    print("운동 끝 시간: ", koreanEndDate)
                    print("운동 거리: ", distance)
                    print("운동 칼로리: ", kcal)
                    
                    self.distance.append(distance)
                }
                
                for workout in workouts {
                    group.enter()
                    self.healthKitManager.getStepsDuringWorkout(startDate: workout.startDate, endDate: workout.endDate) { steps, error in
                        if let step = steps {
                            print("운동 걸음수: ", steps)
                            self.count.append(step)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    print("distance: ", self.distance)
                    print("count: ", self.count)
                }
            }
        }
    }
}

//MARK: 몸무게
extension ViewController {
    func getAllWeight() {
        healthKitManager.getAllWeight { samples, error in
            let calendar = Calendar.current
            
            if let error = error {
                print("Error fetching weight samples: \(error)")
                return
            }
            
            if let samples = samples {
                if !samples.isEmpty {
                    for sample in samples {
                        let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                        let startDate = sample.startDate
                        let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: startDate)
                        print("weight: \(weight)", "startData: \(koreanStartDate)")
                    }
                } else {
                    print("sample 데이터 없음")
                }
            } else {
                print("sample 데이터 없음2")
            }
        }
    }
    
    func getRecentWeight() {
        healthKitManager.getRecentWeight { samples, error in
            if let samples = samples {
                for sample in samples {
                    print("weight StartDate: ", sample.startDate)
                    print("weight EndDate: ", sample.endDate)
                    print("weight kilo: ", sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
            }
        }
    }
    
    func getLastWeight() {
        healthKitManager.getLastWeight { samples, error in
            if let samples = samples {
                for sample in samples {
                    print("weight StartDate: ", sample.startDate)
                    print("weight EndDate: ", sample.endDate)
                    print("weight kilo: ", sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
            }
        }
    }
}

// MARK: 운동
extension ViewController {
    // 특정 기간 내 운동, 날짜, 칼로리
    func requestWeeklyWorkout() {
        healthKitManager.getWeeklyWorkouts { workouts, error in
            if let error = error {
                print("Error fetching workouts: \(error.localizedDescription)")
            } else if let workouts = workouts {
                let calendar = Calendar.current
                
                for workout in workouts {
                    let workoutName = workout.workoutActivityType.name
                    let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: workout.startDate) ?? Date()
                    let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: workout.endDate) ?? Date()
                    let duration = workout.duration
                    let kcal = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                    let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0.0
                    
                    
                    print("운동 종류: ", workoutName)
                    print("운동 시작시간: ", koreanStartDate)
                    print("운동 종료시간: ", koreanEndDate)
                    print("운동 시간: ", duration)
                    print("운동 칼로리: ", kcal)
                    
                    if workoutName == "Walking" {
                        print("운동 거리: ", distance)
                    }
                    
//                    if workoutName == "Walking" {
//                        self.healthKitManager.getStepsDuringWorkout(startDate: workout.startDate, endDate: workout.endDate) { steps, error in
//                            print("운동 걸음수: ", steps)
//                        }
//                    }
                }
            }
        }
    }
    
    func getAllWorkouts() {
        // 특정 기간 내 최근 운동 개수 limit
        healthKitManager.getAllWorkouts { workouts, error in
            let calendar = Calendar.current
            
            if let workouts = workouts {
                for workout in workouts {
                    let workoutName = workout.workoutActivityType.name
                    let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: workout.startDate)
                    let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: workout.endDate)
                    let kcal = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                    
                    print("운동 종류: ", workoutName)
                    print("startDate: ", koreanStartDate)
                    print("endDate: ", koreanEndDate)
                    print("운동 칼로리: ", kcal)
                }
            }
        }
    }
}

// MARK: 혈당
extension ViewController {
    func getPeriodBloodGlucose() {
        let calendar = Calendar.current
        
        healthKitManager.getPeriodBloodGlucose { (samples, error) in
            if let error = error {
                print("Error fetching blood glucose samples: \(error)")
                return
            }
            
            for sample in samples ?? [] {
                let glucose = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
                let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: sample.startDate)
                let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: sample.endDate)
                print("Blood Glucose: \(glucose)", "startDate: \(koreanStartDate)")
            }
        }
    }
    
    func getLimitBloodGlucose() {
        healthKitManager.getLimitBloodGlucose { samples, error in
            if let error = error {
                print("Error fetching blood glucose samples: \(error)")
                return
            }
            
            for sample in samples ?? [] {
                let glucose = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
                let startDate = sample.startDate
                let endDate = sample.endDate
                print("Blood Glucose: \(glucose)", "startDate: \(startDate)")
            }
        }
    }
}

// MARK: 심박수
extension ViewController {
    func requestHeartRate() {
        let calendar = Calendar.current
        
        healthKitManager.getHeartRateData { samples, error in
            if let samples = samples {
                for (_, sample) in samples.enumerated() {
                    if  let heartRateSample = sample as? HKQuantitySample {
                        let heartRateUnit =  HKUnit.count().unitDivided(by: HKUnit .minute())
                        let heartRate =  Int(heartRateSample.quantity.doubleValue(for: heartRateUnit))
                        let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: heartRateSample.startDate)
                        let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: heartRateSample.endDate)
                        
                        print("heartRate: \(heartRate)", "startDate: \(koreanStartDate)", "endDate: \(koreanEndDate)")
                    }
                }
            }
        }
    }
    
    func requestHeartRateMaxMin() {
        healthKitManager.getHeartRateMaxMin { result, error in
            let maxHeartRate = result?.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            let minHeartRate = result?.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            let startDate = result?.startDate ?? Date()
            let endDate = result?.endDate ?? Date()
            
            print("maxHeartRate: \(maxHeartRate)", "minHeartRate: \(minHeartRate)", "startDate: \(startDate)", "endDate: \(endDate)")
        }
    }
    
    func requestHeartRateEveryDay() {
        let calendar = Calendar.current
        healthKitManager.getHeartRateEveryDay { samples, error in
            if let samples = samples {
                for (_, sample) in samples.enumerated() {
                    print("date: \(sample.date)", "max: \(sample.max)", "min: \(sample.min)", "avg: \(sample.avg)")
                }
            }
        }
    }
    
    func requestHeartRateHour() {
        healthKitManager.getHeartRateHourly { samples, error in
            if let samples = samples {
                for (_, sample) in samples.enumerated() {
                    print("date: \(sample.date)", "max: \(sample.max)", "min: \(sample.min)", "avg: \(sample.avg)")
                }
            }
        }
    }
}

// MARK: 혈압
extension ViewController {
    func getPeriodBloodPressure() {
        let calendar = Calendar.current
        
        healthKitManager.getPeriodBloodPressure { (samples, error) in
            if let error = error {
                print("Error fetching blood pressure samples: \(error)")
                return
            }
            if let samples = samples {
                for sample in samples {
                    let mmHg = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: sample.startDate)
                    let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: sample.endDate)
                    print("mmHg: \(mmHg)", "startData: \(koreanStartDate)", "endDate: \(koreanEndDate)")
                }
            }
        }
    }
    
    func getLastBloodPressure() {
        let calendar = Calendar.current
        
        healthKitManager.getLastBloodPressure { (samples, error) in
            if let error = error {
                print("Error fetching blood pressure samples: \(error)")
                return
            }
            if let samples = samples {
                for sample in samples {
                    let mmHg = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: sample.startDate)
                    let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: sample.endDate)
                    print("mmHg: \(mmHg)", "startData: \(koreanStartDate)", "endDate: \(koreanEndDate)")
                }
            }
        }
    }
}

// MARK: 산소포화도
extension ViewController {
    func reqeustAllOxygenSaturation() {
        let calendar = Calendar.current
        
        healthKitManager.getAllOxygenSaturation { samples, error in
            if let error = error {
                print("Error fetching blood pressure samples: \(error)")
                return
            }
            if let samples = samples {
                for sample in samples {
                    let percent = sample.quantity.doubleValue(for: HKUnit.percent())
                    let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: sample.startDate)
                    let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: sample.endDate)
                    print("percent: \(percent)", "startData: \(koreanStartDate)", "endDate: \(koreanEndDate)")
                }
            }
        }
    }
    
    func reqeustPeriodAvgOxygenSaturation() {
        let calendar = Calendar.current
        
        healthKitManager.getPeriodAvgOxygenSaturation { samples, error in
            if let error = error {
                print("Error fetching blood pressure samples: \(error)")
                return
            }
            if let samples = samples {
                let min = samples.minimumQuantity()?.doubleValue(for: HKUnit.percent())
                let max = samples.maximumQuantity()?.doubleValue(for: HKUnit.percent())
                let avg = samples.averageQuantity()?.doubleValue(for: HKUnit.percent())
                
                let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: samples.startDate)
                let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: samples.endDate)
                
                print("min: \(String(describing: min))", "max: \(String(describing: max))", "avg: \(String(describing: avg))")
                print("startDate: \(String(describing: koreanStartDate))", print("endDate: \(String(describing: koreanEndDate))"))
            }
        }
    }
    
    func reqeustRecentOxygenSaturation() {
        let calendar = Calendar.current
        
        healthKitManager.getRecentOxygenSaturation { sample, error in
            if let error = error {
                print("Error fetching blood pressure samples: \(error)")
                return
            }
            if let sample = sample?.first {
                let percent = sample.quantity.doubleValue(for: HKUnit.percent())
                let koreanStartDate = calendar.date(byAdding: .hour, value: 9, to: sample.startDate)
                let koreanEndDate = calendar.date(byAdding: .hour, value: 9, to: sample.endDate)
                print("percent: ", percent)
                print("startDate: ", koreanStartDate)
                print("endDate: ", koreanEndDate)
            }
        }
    }
    
    func requestEverydayOxygenSaturation() {
        let calendar = Calendar.current
        
        healthKitManager.getEverydayOxygenSaturation() { samples, error in
            if let samples = samples {
                for (_, sample) in samples.enumerated() {
                    print("date: \(sample.date)", "max: \(sample.max)", "min: \(sample.min)", "avg: \(sample.avg)")
                }
            }
        }
    }
}

extension HKWorkoutActivityType {
  /*
   Simple mapping of available workout types to a human readable name.
   */
  var name: String {
    switch self {
    case .americanFootball:             return "americanFootball"
    case .archery:                      return "archery"
    case .australianFootball:           return "australianFootball"
    case .badminton:                    return "badminton"
    case .baseball:                     return "baseball"
    case .basketball:                   return "basketball"
    case .bowling:                      return "bowling"
    case .boxing:                       return "boxing"
    case .climbing:                     return "climbing"
    case .crossTraining:                return "crossTraining"
    case .curling:                      return "curling"
    case .cycling:                      return "cycling"
    case .dance:                        return "dance"
    case .danceInspiredTraining:        return "danceInspiredTraining"
    case .elliptical:                   return "elliptical"
    case .equestrianSports:             return "equestrianSports"
    case .fencing:                      return "fencing"
    case .fishing:                      return "fishing"
    case .functionalStrengthTraining:   return "functionalStrengthTraining"
    case .golf:                         return "golf"
    case .gymnastics:                   return "gymnastics"
    case .handball:                     return "handball"
    case .hiking:                       return "hiking"
    case .hockey:                       return "hockey"
    case .hunting:                      return "hunting"
    case .lacrosse:                     return "lacrosse"
    case .martialArts:                  return "martialArts"
    case .mindAndBody:                  return "mindAndBody"
    case .mixedMetabolicCardioTraining: return "mixedMetabolicCardioTraining"
    case .paddleSports:                 return "paddleSports"
    case .play:                         return "play"
    case .preparationAndRecovery:       return "preparationAndRecovery"
    case .racquetball:                  return "racquetball"
    case .rowing:                       return "rowing"
    case .rugby:                        return "rugby"
    case .running:                      return "running"
    case .sailing:                      return "sailing"
    case .skatingSports:                return "skatingSports"
    case .snowSports:                   return "snowSports"
    case .soccer:                       return "soccer"
    case .softball:                     return "softball"
    case .squash:                       return "squash"
    case .stairClimbing:                return "stairClimbing"
    case .surfingSports:                return "surfingSports"
    case .swimming:                     return "swimming"
    case .tableTennis:                  return "tableTennis"
    case .tennis:                       return "tennis"
    case .trackAndField:                return "trackAndField"
    case .traditionalStrengthTraining:  return "traditionalStrengthTraining"
    case .volleyball:                   return "volleyball"
    case .walking:                      return "walking"
    case .waterFitness:                 return "waterFitness"
    case .waterPolo:                    return "waterPolo"
    case .waterSports:                  return "waterSports"
    case .wrestling:                    return "wrestling"
    case .yoga:                         return "yoga"

    // iOS 10
    case .barre:                        return "barre"
    case .coreTraining:                 return "coreTraining"
    case .crossCountrySkiing:           return "crossCountrySkiing"
    case .downhillSkiing:               return "downhillSkiing"
    case .flexibility:                  return "flexibility"
    case .highIntensityIntervalTraining:    return "highIntensityIntervalTraining"
    case .jumpRope:                     return "jumpRope"
    case .kickboxing:                   return "kickboxing"
    case .pilates:                      return "pilates"
    case .snowboarding:                 return "snowboarding"
    case .stairs:                       return "stairs"
    case .stepTraining:                 return "stepTraining"
    case .wheelchairWalkPace:           return "wheelchairWalkPace"
    case .wheelchairRunPace:            return "wheelchairRunPace"

    // iOS 11
    case .taiChi:                       return "taiChi"
    case .mixedCardio:                  return "mixedCardio"
    case .handCycling:                  return "handCycling"

    // iOS 13
    case .discSports:                   return "discSports"
    case .fitnessGaming:                return "fitnessGaming"

    // Catch-all
    default:                            return "Other"
    }
  }
}
