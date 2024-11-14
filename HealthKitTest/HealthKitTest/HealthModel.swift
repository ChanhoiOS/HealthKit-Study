//
//  HealthModel.swift
//  HealthKitTest
//
//  Created by 이찬호 on 11/6/24.
//

import Foundation

// MARK: - HealthDataModel
struct HealthModel: Codable {
    var userId: String?
    var providerType: String = "APPLE_HEALTH"
    var bloodPressures: [BloodPressure]?
    var oxygenSaturations: [OxygenSaturation]?
    var bloodSugars: [BloodSugar]?
    var steps: [Step]?
    var heartRates: [HeartRate]?
    var exercises: [Exercise]?
}

// MARK: - BloodPressure
struct BloodPressure: Codable {
    let bloodPressureMax: Int?
    let bloodPressureMin: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case bloodPressureMax
        case bloodPressureMin
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

// MARK: - BloodSugar
struct BloodSugar: Codable {
    let bloodSugar: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case bloodSugar
        case analysisAt
    }
}

// MARK: - Step
struct Step: Codable {
    let step: Int?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case step
        case date
    }
}

// MARK: - HeartRate
struct HeartRate: Codable {
    let heartRateAvg: Int?
    let heartRateMax: Int?
    let heartRateMin: Int?
    let analysisAt: String?

    enum CodingKeys: String, CodingKey {
        case heartRateAvg
        case heartRateMax
        case heartRateMin
        case analysisAt
    }
}

// MARK: - Exercise
struct Exercise: Codable {
    let exerciseId: String?
    let startTime: String?
    let endTime: String?
    let exerciseTime: Int?
    let burnedKcal: Double?
    let distance: Int?

    enum CodingKeys: String, CodingKey {
        case exerciseId
        case startTime
        case endTime
        case exerciseTime
        case distance
        case burnedKcal
    }
}
