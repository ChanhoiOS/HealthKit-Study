//
//  HealthModel.swift
//  HealthKitTest
//
//  Created by 이찬호 on 11/6/24.
//

import Foundation

// MARK: - HealthDataModel
struct HealthModel: Codable {
    let step: [Step]?
    let weight: [WeightData]?
    let exercise: [Exercise]?
    let bloodGluscose: [BloodGluscose]?
    let heartRate: [HeartRate]?
    let bloodPressure: [BloodPressure]?
    let oxygenSaturation: [OxygenSaturation]?
}

// MARK: - Step
struct Step: Codable {
    let count: Int?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case count
        case date
    }
}

// MARK: - Weight
struct WeightData: Codable {
    let id: Int?
    let userID, extensionID: String?
    let weight: Double?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case extensionID = "extensionId"
        case weight, analysisAt
    }
}

// MARK: - Exercise
struct Exercise: Codable {
    let exerciseID: Int?
    let burnedKcal: Double?
    let exerciseHour: Int?
    let distance: Int?
    let count: Int?
    let endTime: String?

    enum CodingKeys: String, CodingKey {
        case exerciseID = "exerciseId"
        case exerciseHour
        case distance
        case count
        case burnedKcal, endTime
    }
}

// MARK: - BloodSugar
struct BloodGluscose: Codable {
    let bloodGluscose: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case bloodGluscose
        case analysisAt
    }
}

// MARK: - HeartRate
struct HeartRate: Codable {
    let heartRateMin: Int?
    let heartRateMax: Int?
    let heartRateAvg: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case heartRateMin
        case heartRateMax
        case heartRateAvg
        case analysisAt
    }
}

// MARK: - BloodPressure
struct BloodPressure: Codable {
    let bloodPressureMin, bloodPressureMax: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case bloodPressureMin
        case bloodPressureMax
        case analysisAt
    }
}

// MARK: - OxygenSaturation
struct OxygenSaturation: Codable {
    let oxygenSaturation: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case oxygenSaturation
        case analysisAt
    }
}

