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
    
    var distance = [Double]()
    var count = [Double]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func requestAuth(_ sender: Any) {
        if HKHealthStore.isHealthDataAvailable() {
            print("=============헬스데이터 사용 가능 장치=============")
            
            healthKitManager.requestAuthorization { (success, error) in
                print("=============requestAuthorization success=============")
                print(success)
                print("======================================================")
                if success {
                    self.requestBloodGlucoseModel()
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

//MARK: 모델화
extension ViewController {
    func requestStepModel() {
        var stepModel = [Step]()
        var index = 0
        
        healthKitManager.getStepModel { model in
            if let model = model {
                stepModel.append(model)
            } else {
                stepModel.append(Step(count: nil, date: nil))
            }
            
            index += 1
            
            if index == 7 {
                print("stepModel: ", stepModel)
            }
        }
    }
    
    func requestBloodPressureModel() {
        healthKitManager.getBloodPressureModel { model in
            if let model = model {
                print("bllodpressureModel: ", model)
            }
        }
    }
    
    func requestOxygenSaturationModel() {
        healthKitManager.getOxygenSaturationModel { model in
            print("model: ", model)
        }
    }
    
    func requestBloodGlucoseModel() {
        healthKitManager.getBloodGlucoseModel { model in
            print("model: ", model)
        }
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
    case .americanFootball:             return "American Football"
    case .archery:                      return "Archery"
    case .australianFootball:           return "Australian Football"
    case .badminton:                    return "Badminton"
    case .baseball:                     return "Baseball"
    case .basketball:                   return "Basketball"
    case .bowling:                      return "Bowling"
    case .boxing:                       return "Boxing"
    case .climbing:                     return "Climbing"
    case .crossTraining:                return "Cross Training"
    case .curling:                      return "Curling"
    case .cycling:                      return "Cycling"
    case .dance:                        return "Dance"
    case .danceInspiredTraining:        return "Dance Inspired Training"
    case .elliptical:                   return "Elliptical"
    case .equestrianSports:             return "Equestrian Sports"
    case .fencing:                      return "Fencing"
    case .fishing:                      return "Fishing"
    case .functionalStrengthTraining:   return "Functional Strength Training"
    case .golf:                         return "Golf"
    case .gymnastics:                   return "Gymnastics"
    case .handball:                     return "Handball"
    case .hiking:                       return "Hiking"
    case .hockey:                       return "Hockey"
    case .hunting:                      return "Hunting"
    case .lacrosse:                     return "Lacrosse"
    case .martialArts:                  return "Martial Arts"
    case .mindAndBody:                  return "Mind and Body"
    case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
    case .paddleSports:                 return "Paddle Sports"
    case .play:                         return "Play"
    case .preparationAndRecovery:       return "Preparation and Recovery"
    case .racquetball:                  return "Racquetball"
    case .rowing:                       return "Rowing"
    case .rugby:                        return "Rugby"
    case .running:                      return "Running"
    case .sailing:                      return "Sailing"
    case .skatingSports:                return "Skating Sports"
    case .snowSports:                   return "Snow Sports"
    case .soccer:                       return "Soccer"
    case .softball:                     return "Softball"
    case .squash:                       return "Squash"
    case .stairClimbing:                return "Stair Climbing"
    case .surfingSports:                return "Surfing Sports"
    case .swimming:                     return "Swimming"
    case .tableTennis:                  return "Table Tennis"
    case .tennis:                       return "Tennis"
    case .trackAndField:                return "Track and Field"
    case .traditionalStrengthTraining:  return "Traditional Strength Training"
    case .volleyball:                   return "Volleyball"
    case .walking:                      return "Walking"
    case .waterFitness:                 return "Water Fitness"
    case .waterPolo:                    return "Water Polo"
    case .waterSports:                  return "Water Sports"
    case .wrestling:                    return "Wrestling"
    case .yoga:                         return "Yoga"

    // iOS 10
    case .barre:                        return "Barre"
    case .coreTraining:                 return "Core Training"
    case .crossCountrySkiing:           return "Cross Country Skiing"
    case .downhillSkiing:               return "Downhill Skiing"
    case .flexibility:                  return "Flexibility"
    case .highIntensityIntervalTraining:    return "High Intensity Interval Training"
    case .jumpRope:                     return "Jump Rope"
    case .kickboxing:                   return "Kickboxing"
    case .pilates:                      return "Pilates"
    case .snowboarding:                 return "Snowboarding"
    case .stairs:                       return "Stairs"
    case .stepTraining:                 return "Step Training"
    case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
    case .wheelchairRunPace:            return "Wheelchair Run Pace"

    // iOS 11
    case .taiChi:                       return "Tai Chi"
    case .mixedCardio:                  return "Mixed Cardio"
    case .handCycling:                  return "Hand Cycling"

    // iOS 13
    case .discSports:                   return "Disc Sports"
    case .fitnessGaming:                return "Fitness Gaming"

    // Catch-all
    default:                            return "Other"
    }
  }
}
