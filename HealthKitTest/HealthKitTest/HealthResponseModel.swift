//
//  HealthResponseModel.swift
//  HealthKitTest
//
//  Created by 이찬호 on 11/13/24.
//

import Foundation

struct HealthResponseModel: Codable {
    let timestamp, status: Int?
    let error, message, path: String?
    let data: HealthResponseModelData?
}

// MARK: - HealthResponseModelData
struct HealthResponseModelData: Codable {
    let code: Int?
    let message: String?
    let data: DataData?
}

// MARK: - DataData
struct DataData: Codable {
    let result: Bool?
    let message, createdAt: String?
}
