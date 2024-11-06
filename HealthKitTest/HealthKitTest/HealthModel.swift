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
    let bloodSugar: [BloodSugar]?
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
    let id: Int?
    let userID, extensionID: String?
    let exerciseID: Int?
    let burnedKcal: Double?
    let startTime, endTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case extensionID = "extensionId"
        case exerciseID = "exerciseId"
        case burnedKcal, startTime, endTime
    }
}

// MARK: - BloodSugar
struct BloodSugar: Codable {
    let id: Int?
    let userID, extensionID: String?
    let bloodSugar: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case extensionID = "extensionId"
        case bloodSugar, analysisAt
    }
}

// MARK: - HeartRate
struct HeartRate: Codable {
    let id: Int?
    let userID, extensionID: String?
    let heartRateMin, heartRateMax: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case extensionID = "extensionId"
        case heartRateMin, heartRateMax, analysisAt
    }
}

// MARK: - BloodPressure
struct BloodPressure: Codable {
    let id: Int?
    let userID, extensionID: String?
    let bloodPressureMin, bloodPressureMax: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case extensionID = "extensionId"
        case bloodPressureMin, bloodPressureMax, analysisAt
    }
}

// MARK: - OxygenSaturation
struct OxygenSaturation: Codable {
    let id: Int?
    let userID, extensionID: String?
    let oxygenSaturation: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case extensionID = "extensionId"
        case oxygenSaturation, analysisAt
    }
}

