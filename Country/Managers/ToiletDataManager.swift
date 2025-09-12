//
//  ToiletDataManager.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import Foundation
import CoreLocation

// 公廁資料管理器
class ToiletDataManager: ObservableObject {
    @Published var toilets: [ToiletInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let jsonFileName = "toilet"
    
    init() {
        loadToiletData()
    }
    
    // 載入公廁資料
    func loadToiletData() {
        isLoading = true
        errorMessage = nil
        
        guard let url = Bundle.main.url(forResource: jsonFileName, withExtension: "json") else {
            errorMessage = "找不到 toilet.json 檔案"
            isLoading = false
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            toilets = try decoder.decode([ToiletInfo].self, from: data)
            isLoading = false
            print("成功載入 \(toilets.count) 筆公廁資料")
        } catch {
            errorMessage = "載入公廁資料失敗: \(error.localizedDescription)"
            isLoading = false
            print("載入公廁資料錯誤: \(error)")
        }
    }
    
    // 搜尋公廁（按名稱、地址、地區）
    func searchToilets(query: String) -> [ToiletInfo] {
        guard !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        return toilets.filter { toilet in
            toilet.name.lowercased().contains(lowercaseQuery) ||
            toilet.address.lowercased().contains(lowercaseQuery) ||
            toilet.village.lowercased().contains(lowercaseQuery) ||
            toilet.type2.lowercased().contains(lowercaseQuery)
        }
    }
    
    // 根據位置搜尋附近的公廁
    func findNearbyToilets(userLocation: CLLocation, radius: Double = 5000) -> [ToiletInfo] {
        return toilets.filter { toilet in
            let toiletLocation = CLLocation(
                latitude: toilet.latitudeDouble,
                longitude: toilet.longitudeDouble
            )
            let distance = userLocation.distance(from: toiletLocation)
            return distance <= radius
        }.sorted { toilet1, toilet2 in
            let location1 = CLLocation(
                latitude: toilet1.latitudeDouble,
                longitude: toilet1.longitudeDouble
            )
            let location2 = CLLocation(
                latitude: toilet2.latitudeDouble,
                longitude: toilet2.longitudeDouble
            )
            
            let distance1 = userLocation.distance(from: location1)
            let distance2 = userLocation.distance(from: location2)
            
            return distance1 < distance2
        }
    }
    
    // 篩選公廁（按等級）
    func filterToiletsByGrade(_ grade: String) -> [ToiletInfo] {
        return toilets.filter { $0.grade == grade }
    }
    
    // 篩選公廁（按場所類型）
    func filterToiletsByType(_ type: String) -> [ToiletInfo] {
        return toilets.filter { $0.type2 == type }
    }
    
    // 篩選有尿布台的公廁
    func filterToiletsWithDiaperStation() -> [ToiletInfo] {
        return toilets.filter { $0.hasDiaperStation }
    }
    
    // 獲取所有等級選項
    func getAllGrades() -> [String] {
        return Array(Set(toilets.map { $0.grade })).sorted()
    }
    
    // 獲取所有場所類型選項
    func getAllTypes() -> [String] {
        return Array(Set(toilets.map { $0.type2 })).sorted()
    }
    
    // 獲取統計資訊
    func getStatistics() -> (total: Int, byGrade: [String: Int], byType: [String: Int]) {
        let total = toilets.count
        
        let byGrade = Dictionary(grouping: toilets, by: { $0.grade })
            .mapValues { $0.count }
        
        let byType = Dictionary(grouping: toilets, by: { $0.type2 })
            .mapValues { $0.count }
        
        return (total: total, byGrade: byGrade, byType: byType)
    }
}
