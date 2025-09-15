//
//  ToiletDataManager.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import Foundation
import CoreLocation
import MapKit

// 公廁資料管理器
class ToiletDataManager: ObservableObject {
    @Published var toilets: [ToiletInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let jsonFileName = "toilet"
    private var coordinateCache: [String: (latitude: Double, longitude: Double)] = [:]
    
    // 區域載入緩存（提升性能）
    private var regionCache: [String: [ToiletInfo]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.country.toilet.cache", attributes: .concurrent)
    
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
    
    // 根據位置搜尋附近的公廁（優化版本）
    func findNearbyToilets(userLocation: CLLocation, radius: Double = 5000) -> [ToiletInfo] {
        // 預計算所有有效公廁的距離，避免重複計算
        let toiletsWithDistance = toilets.compactMap { toilet -> (ToiletInfo, Double)? in
            // 檢查座標是否有效
            guard toilet.latitudeDouble != 0.0 && toilet.longitudeDouble != 0.0 else {
                return nil
            }
            
            // 修正座標
            let corrected = correctedCoordinates(for: toilet)
            
            let toiletLocation = CLLocation(
                latitude: corrected.latitude,
                longitude: corrected.longitude
            )
            let distance = userLocation.distance(from: toiletLocation)
            
            // 只保留在範圍內且距離大於0的公廁
            guard distance > 0 && distance <= radius else {
                return nil
            }
            
            return (toilet, distance)
        }
        
        // 按距離排序並返回公廁
        return toiletsWithDistance
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }
    
    // 根據位置搜尋附近的公廁並返回距離（優化版本）
    func findNearbyToiletsWithDistance(userLocation: CLLocation, radius: Double = 5000) -> [(ToiletInfo, Int)] {
        // 預計算所有有效公廁的距離，避免重複計算
        let toiletsWithDistance = toilets.compactMap { toilet -> (ToiletInfo, Double)? in
            // 檢查座標是否有效
            guard toilet.latitudeDouble != 0.0 && toilet.longitudeDouble != 0.0 else {
                return nil
            }
            
            // 修正座標
            let corrected = correctedCoordinates(for: toilet)
            
            let toiletLocation = CLLocation(
                latitude: corrected.latitude,
                longitude: corrected.longitude
            )
            let distance = userLocation.distance(from: toiletLocation)
            
            // 只保留在範圍內且距離大於0的公廁
            guard distance > 0 && distance <= radius else {
                return nil
            }
            
            return (toilet, distance)
        }
        
        // 按距離排序並返回公廁和距離
        return toiletsWithDistance
            .sorted { $0.1 < $1.1 }
            .map { (toilet, distance) in (toilet, Int(distance)) }
    }
    
    // 修正座標（處理經緯度顛倒的情況，帶快取機制）
    private func correctedCoordinates(for toilet: ToiletInfo) -> (latitude: Double, longitude: Double) {
        let cacheKey = "\(toilet.latitude)_\(toilet.longitude)"
        
        // 檢查快取
        if let cached = coordinateCache[cacheKey] {
            return cached
        }
        
        var lat = toilet.latitudeDouble
        var lon = toilet.longitudeDouble
        
        // 檢查是否經緯度顛倒（台灣的緯度應該在 21-25 之間，經度應該在 119-122 之間）
        if lat > 25.0 || lat < 21.0 {
            // 如果緯度超出台灣範圍，可能是經緯度顛倒
            if lon >= 21.0 && lon <= 25.0 {
                let temp = lat
                lat = lon
                lon = temp
            }
        }
        
        let result = (latitude: lat, longitude: lon)
        
        // 快取結果
        coordinateCache[cacheKey] = result
        
        return result
    }
    
    // 計算距離
    func calculateDistance(from userLocation: CLLocation, to toilet: ToiletInfo) -> Int {
        // 檢查座標是否有效
        guard toilet.latitudeDouble != 0.0 && toilet.longitudeDouble != 0.0 else {
            return 999999
        }
        
        // 修正座標
        let corrected = correctedCoordinates(for: toilet)
        
        let toiletLocation = CLLocation(
            latitude: corrected.latitude,
            longitude: corrected.longitude
        )
        let distance = userLocation.distance(from: toiletLocation)
        
        // 如果距離為 0，可能是座標相同或計算錯誤
        if distance == 0.0 {
            return 999999
        }
        
        return Int(distance)
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
    
    // 根據地圖區域載入公廁（優化版本，含緩存）
    func findToiletsInRegion(_ region: MKCoordinateRegion, maxCount: Int = 100) -> [ToiletInfo] {
        // 生成緩存鍵
        let cacheKey = generateCacheKey(for: region)
        
        // 檢查緩存
        if let cachedToilets = regionCache[cacheKey] {
            print("使用緩存：找到 \(cachedToilets.count) 個公廁")
            return cachedToilets
        }
        
        // 計算地圖視窗的邊界
        let center = region.center
        let span = region.span
        
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2
        
        // 根據縮放級別調整最大載入數量
        let zoomLevel = calculateZoomLevel(region)
        let adjustedMaxCount = getMaxToiletsForZoom(zoomLevel, baseMax: maxCount)
        
        // 篩選在地圖視窗內且座標有效的公廁
        let toiletsInRegion = toilets.compactMap { toilet -> (ToiletInfo, Double)? in
            // 檢查座標是否有效
            guard toilet.latitudeDouble != 0.0 && toilet.longitudeDouble != 0.0 else {
                return nil
            }
            
            // 修正座標
            let corrected = correctedCoordinates(for: toilet)
            
            // 檢查是否在地圖視窗內
            guard corrected.latitude >= minLat && corrected.latitude <= maxLat &&
                  corrected.longitude >= minLon && corrected.longitude <= maxLon else {
                return nil
            }
            
            // 計算到地圖中心的距離（用於排序）
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let toiletLocation = CLLocation(latitude: corrected.latitude, longitude: corrected.longitude)
            let distance = centerLocation.distance(from: toiletLocation)
            
            return (toilet, distance)
        }
        
        // 按優先級和距離排序
        let sortedToilets = toiletsInRegion
            .sorted { first, second in
                // 先按優先級排序（特優級 > 優級 > 良級 > 普級）
                let firstPriority = getPriorityScore(first.0.grade)
                let secondPriority = getPriorityScore(second.0.grade)
                
                if firstPriority != secondPriority {
                    return firstPriority > secondPriority
                }
                
                // 相同優先級時按距離排序
                return first.1 < second.1
            }
            .prefix(adjustedMaxCount)
            .map { $0.0 }
        
        let result = Array(sortedToilets)
        
        // 緩存結果（限制緩存大小）
        cacheQueue.async(flags: .barrier) {
            if self.regionCache.count > 50 { // 限制緩存大小
                self.regionCache.removeAll()
            }
            self.regionCache[cacheKey] = result
        }
        
        print("地圖區域載入：找到 \(result.count) 個公廁（縮放級別：\(zoomLevel)）")
        return result
    }
    
    // 生成緩存鍵
    private func generateCacheKey(for region: MKCoordinateRegion) -> String {
        let center = region.center
        let span = region.span
        
        // 將座標四捨五入到小數點後3位，減少緩存鍵的數量
        let lat = String(format: "%.3f", center.latitude)
        let lon = String(format: "%.3f", center.longitude)
        let latDelta = String(format: "%.3f", span.latitudeDelta)
        let lonDelta = String(format: "%.3f", span.longitudeDelta)
        
        return "\(lat)_\(lon)_\(latDelta)_\(lonDelta)"
    }
    
    // 計算縮放級別（優化版本，含限制）
    private func calculateZoomLevel(_ region: MKCoordinateRegion) -> Int {
        let span = region.span
        let latitudeDelta = span.latitudeDelta
        let longitudeDelta = span.longitudeDelta
        
        // 使用較大的跨度來判斷縮放級別，更準確
        let maxDelta = max(latitudeDelta, longitudeDelta)
        
        // 添加縮放限制
        let clampedDelta = max(0.001, min(0.1, maxDelta)) // 限制在 0.001 到 0.1 之間（10km）
        
        // 更精確的縮放級別判斷（含限制）
        if clampedDelta > 0.1 {
            return 1 // 區域級 (>10km) - 大範圍區域（限制）
        } else if clampedDelta > 0.05 {
            return 2 // 城市級 (5-10km) - 大都會區
        } else if clampedDelta > 0.02 {
            return 3 // 區域級 (2-5km) - 縣市範圍
        } else if clampedDelta > 0.01 {
            return 4 // 街道級 (1-2km) - 鄉鎮市區
        } else if clampedDelta > 0.005 {
            return 5 // 詳細級 (500m-1km) - 街道範圍
        } else if clampedDelta > 0.002 {
            return 6 // 超詳細級 (200m-500m) - 建築物級
        } else {
            return 7 // 極詳細級 (<200m) - 建築物級（限制）
        }
    }
    
    // 根據縮放級別獲取最大載入數量（移除數量限制）
    private func getMaxToiletsForZoom(_ zoomLevel: Int, baseMax: Int) -> Int {
        // 不限制數量，顯示所有在範圍內的公廁
        return baseMax
    }
    
    // 獲取公廁評級優先級分數
    private func getPriorityScore(_ grade: String) -> Int {
        switch grade {
        case "特優級":
            return 4
        case "優級":
            return 3
        case "良級":
            return 2
        case "普級":
            return 1
        default:
            return 0
        }
    }
}
