//
//  NetworkManager.swift
//  HealthKitTest
//
//  Created by 이찬호 on 11/8/24.
//

import Foundation
import Alamofire

class NetworkManager {
    static func uploadModelData(_ healthData: HealthModel) {
        let url = "https://daddl-dev.lottesrc.com/m/lifelog/put"
        
        let session = "OWQ0NTRiYzYtMjM5MC00ZGNiLWI5ZDEtZDNmN2Q2Zjc2ODUx"
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Cookie": "SESSION=\(session)"
        ]
        
        guard let jsonData = try? JSONEncoder().encode(healthData) else {
            print("Failed to encode data")
            return
        }
        
        let paramDic = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        AF.request(url, method: .post, parameters: paramDic, encoding: JSONEncoding.default, headers: headers)
            .responseDecodable(of: HealthResponseModel.self) { response in
                print("response: ", response)
            }
    }
}
