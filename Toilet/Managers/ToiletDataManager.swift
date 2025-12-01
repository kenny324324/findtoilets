//
//  ToiletDataManager.swift
//  Toilet
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
    
    // 新增：群組後的地點資料
    @Published var locations: [ToiletLocation] = []
    @Published var filteredLocations: [ToiletLocation] = []
    @Published var selectedLocation: ToiletLocation?
    @Published var selectedToilet: ToiletInfo?
    
    private let jsonFileName = "toilet"
    private let optimizedJsonFileName = "toilet_locations"
    private var coordinateCache: [String: (latitude: Double, longitude: Double)] = [:]
    
    // 區域載入緩存（提升性能）
    private var regionCache: [String: [ToiletInfo]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.country.toilet.cache")
    
    init() {
        // init 時不載入資料，等待 View 來呼叫 loadToiletData
    }
    
    // 載入公廁資料
    func loadToiletData() {
        // 如果正在載入，不要重複執行
        guard !isLoading else { return }
        
        // 在主執行緒設置載入狀態
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // 切換到背景執行緒進行耗時操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 嘗試載入預處理過的優化資料
            if let optimizedUrl = Bundle.main.url(forResource: self.optimizedJsonFileName, withExtension: "json") {
                do {
                    print("發現優化資料，開始載入...")
                    let data = try Data(contentsOf: optimizedUrl)
                    let decoder = JSONDecoder()
                    let loadedLocations = try decoder.decode([ToiletLocation].self, from: data)
                    
                    // 從地點還原出所有廁所列表 (如果需要的話)
                    let loadedToilets = loadedLocations.flatMap { $0.allToilets }
                    
                    DispatchQueue.main.async {
                        self.locations = loadedLocations
                        self.filteredLocations = loadedLocations
                        self.toilets = loadedToilets
                        self.isLoading = false
                        print("成功從優化檔載入 \(loadedLocations.count) 個地點，\(loadedToilets.count) 筆公廁資料")
                    }
                    return // 成功載入優化檔，直接結束
                } catch {
                    print("載入優化資料失敗，嘗試載入原始資料: \(error)")
                    // 失敗則繼續往下嘗試載入原始資料
                }
            }
            
            // 2. 載入原始資料（Fallback）
            guard let url = Bundle.main.url(forResource: self.jsonFileName, withExtension: "json") else {
                DispatchQueue.main.async {
                    self.errorMessage = LocalizedStrings.fileNotFound.localized
                    self.isLoading = false
                }
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let loadedToilets = try decoder.decode([ToiletInfo].self, from: data)
                
                // 耗時操作：群組廁所資料為地點
                print("開始計算地點群組...")
                let loadedLocations = ToiletLocation.createFromToilets(loadedToilets)
                
                DispatchQueue.main.async {
                    self.toilets = loadedToilets
                    self.locations = loadedLocations
                    self.filteredLocations = loadedLocations
                    self.isLoading = false
                    
                    print("成功載入原始資料：\(loadedToilets.count) 筆公廁")
                    print("即時群組後：\(loadedLocations.count) 個地點")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "\(LocalizedStrings.dataLoadFailed.localized): \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("載入公廁資料錯誤: \(error)")
            }
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
    
    // 搜尋地點（按名稱、地址、地區、廁所類型）
    func searchLocations(query: String) -> [ToiletLocation] {
        guard !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        return locations.filter { location in
            location.name.lowercased().contains(lowercaseQuery) ||
            location.address.lowercased().contains(lowercaseQuery) ||
            location.administration.lowercased().contains(lowercaseQuery) ||
            location.availableTypes.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    // 根據位置搜尋附近的地點（優化版本）
    func findNearbyLocations(userLocation: CLLocation, radius: Double = 5000) -> [ToiletLocation] {
        // 預計算所有有效地點的距離，避免重複計算
        let locationsWithDistance = locations.compactMap { location -> (ToiletLocation, Double)? in
            let locationCoordinate = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = userLocation.distance(from: locationCoordinate)
            
            if distance <= radius {
                return (location, distance)
            }
            return nil
        }
        
        // 按距離排序並返回
        return locationsWithDistance
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }
    
    // 根據位置搜尋附近的地點並返回距離
    func findNearbyLocationsWithDistance(userLocation: CLLocation, radius: Double = 5000) -> [(ToiletLocation, Int)] {
        // 預計算所有地點的距離
        let locationsWithDistance = locations.compactMap { location -> (ToiletLocation, Double)? in
            // 使用地點的第一個廁所來計算距離
            guard let firstToilet = location.allToilets.first else {
                return nil
            }
            
            // 檢查座標是否有效
            guard firstToilet.latitudeDouble != 0.0 && firstToilet.longitudeDouble != 0.0 else {
                return nil
            }
            
            // 修正座標
            guard let corrected = correctedCoordinates(for: firstToilet) else {
                return nil
            }
            
            let locationCoordinate = CLLocation(
                latitude: corrected.latitude,
                longitude: corrected.longitude
            )
            let distance = userLocation.distance(from: locationCoordinate)
            
            // 只保留在範圍內且距離大於0的地點
            guard distance > 0 && distance <= radius else {
                return nil
            }
            
            return (location, distance)
        }
        
        // 按距離排序並返回地點和距離
        return locationsWithDistance
            .sorted { $0.1 < $1.1 }
            .map { (location, distance) in (location, Int(distance)) }
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
            guard let corrected = correctedCoordinates(for: toilet) else {
                return nil
            }
            
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
            guard let corrected = correctedCoordinates(for: toilet) else {
                return nil
            }
            
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
    private func correctedCoordinates(for toilet: ToiletInfo) -> (latitude: Double, longitude: Double)? {
        let cacheKey = "\(toilet.latitude)_\(toilet.longitude)"
        
        return cacheQueue.sync {
            if let cached = coordinateCache[cacheKey] {
                return cached
            }
            
            guard let coordinate = toilet.correctedCoordinate else {
                return nil
            }
            
            let result = (latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // 快取結果
            coordinateCache[cacheKey] = result
            
            return result
        }
    }
    
    // 計算距離
    func calculateDistance(from userLocation: CLLocation, to toilet: ToiletInfo) -> Int {
        // 檢查座標是否有效
        guard toilet.latitudeDouble != 0.0 && toilet.longitudeDouble != 0.0 else {
            return 999999
        }
        
        // 修正座標
        guard let corrected = correctedCoordinates(for: toilet) else {
            return 999999
        }
        
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
        let cachedToilets = cacheQueue.sync { regionCache[cacheKey] }
        if let cachedToilets {
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
            guard let corrected = correctedCoordinates(for: toilet) else {
                return nil
            }
            
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
        cacheQueue.async {
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
        
        // 添加縮放限制（允許顯示全台甚至全世界）
        let clampedDelta = max(0.001, min(10.0, maxDelta))
        
        if clampedDelta > 2.0 {
            return 1 // 國土級 (>~220km)
        } else if clampedDelta > 1.0 {
            return 2 // 區域級 (110-220km)
        } else if clampedDelta > 0.5 {
            return 3 // 大都會級 (55-110km)
        } else if clampedDelta > 0.2 {
            return 4 // 城市級 (22-55km)
        } else if clampedDelta > 0.1 {
            return 5 // 都市區級 (11-22km)
        } else if clampedDelta > 0.05 {
            return 6 // 區域級 (5-11km)
        } else if clampedDelta > 0.02 {
            return 7 // 街道級 (2-5km)
        } else if clampedDelta > 0.01 {
            return 8 // 詳細級 (1-2km)
        } else if clampedDelta > 0.005 {
            return 9 // 超詳細級 (500m-1km)
        } else {
            return 10 // 極詳細級 (<500m)
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
    
    // MARK: - 測試功能
    
    // 測試群組功能
    func testGrouping() {
        print("=== 開始測試群組功能 ===")
        
        // 載入前100筆資料進行測試
        let testToilets = Array(toilets.prefix(100))
        print("測試資料：\(testToilets.count) 筆")
        
        // 執行群組
        let locations = ToiletLocation.createFromToilets(testToilets)
        print("群組後：\(locations.count) 個地點")
        
        // 顯示詳細統計
        for (index, location) in locations.enumerated() {
            print("\n--- 地點 \(index + 1) ---")
            print("名稱：\(location.name)")
            print("地址：\(location.address)")
            print("座標：\(location.latitude), \(location.longitude)")
            print("管理單位：\(location.administration)")
            print("總廁所數：\(location.totalToiletCount)")
            print("樓層數：\(location.floorCount)")
            print("可用類型：\(Array(location.availableTypes).sorted())")
            
            if location.hasMultipleFloors {
                print("樓層詳情：")
                for floor in location.toiletsByFloor {
                    print("  \(floor.floorName)：\(floor.toiletCount)間 (\(Array(floor.availableTypes).joined(separator: ", ")))")
                }
            }
        }
        
        // 統計資訊
        let totalOriginalToilets = testToilets.count
        let totalGroupedToilets = locations.reduce(0) { $0 + $1.totalToiletCount }
        let multiFloorLocations = locations.filter { $0.hasMultipleFloors }.count
        
        print("\n=== 統計結果 ===")
        print("原始廁所數：\(totalOriginalToilets)")
        print("群組後廁所數：\(totalGroupedToilets)")
        print("地點數：\(locations.count)")
        print("多樓層地點：\(multiFloorLocations)")
        print("單樓層地點：\(locations.count - multiFloorLocations)")
        print("平均每地點廁所數：\(String(format: "%.1f", Double(totalGroupedToilets) / Double(locations.count)))")
        
        // 檢查資料完整性
        if totalOriginalToilets == totalGroupedToilets {
            print("✅ 資料完整性檢查通過")
        } else {
            print("❌ 資料完整性檢查失敗")
        }
        
        print("=== 測試完成 ===")
    }
    
    // 測試特定地址的群組效果
    func testSpecificAddress(_ address: String) {
        print("=== 測試地址：\(address) ===")
        
        let toiletsAtAddress = toilets.filter { $0.address == address }
        print("該地址的廁所數：\(toiletsAtAddress.count)")
        
        if toiletsAtAddress.isEmpty {
            print("❌ 找不到該地址的廁所")
            return
        }
        
        // 顯示原始廁所
        print("\n原始廁所列表：")
        for (index, toilet) in toiletsAtAddress.enumerated() {
            print("\(index + 1). \(toilet.name) - \(toilet.type)")
        }
        
        // 執行群組
        let locations = ToiletLocation.createFromToilets(toiletsAtAddress)
        print("\n群組後：")
        for (index, location) in locations.enumerated() {
            print("\n地點 \(index + 1)：\(location.name)")
            print("樓層數：\(location.floorCount)")
            
            for floor in location.toiletsByFloor {
                print("  \(floor.floorName)：")
                for toilet in floor.toilets {
                    print("    - \(toilet.name) (\(toilet.type))")
                }
            }
        }
        
        print("=== 測試完成 ===")
    }
    
    // 快速測試（只顯示統計）
    func quickTest() {
        print("=== 快速測試 ===")
        
        let testCount = min(200, toilets.count) // 增加到200筆資料
        let testToilets = Array(toilets.prefix(testCount))
        let locations = ToiletLocation.createFromToilets(testToilets)
        
        print("測試 \(testCount) 筆資料")
        print("群組後：\(locations.count) 個地點")
        print("多樓層地點：\(locations.filter { $0.hasMultipleFloors }.count) 個")
        
        // 顯示前5個地點的資訊
        for (index, location) in locations.prefix(5).enumerated() {
            print("\(index + 1). \(location.name) - \(location.totalToiletCount)間廁所")
            if location.hasMultipleFloors {
                print("  樓層：\(location.floorCount)層")
                for floor in location.toiletsByFloor {
                    print("    \(floor.floorName): \(floor.toiletCount)間廁所")
                }
            } else {
                print("  單樓層地點")
            }
        }
        
        // 顯示所有多樓層地點的詳細資訊
        let multiFloorLocations = locations.filter { $0.hasMultipleFloors }
        if !multiFloorLocations.isEmpty {
            print("\n=== 多樓層地點詳細資訊 ===")
            for (index, location) in multiFloorLocations.enumerated() {
                print("\(index + 1). \(location.name)")
                print("  地址：\(location.address)")
                print("  樓層數：\(location.floorCount)")
                for floor in location.toiletsByFloor {
                    print("    \(floor.floorName): \(floor.toiletCount)間廁所")
                    for toilet in floor.toilets {
                        print("      - \(toilet.name)")
                    }
                }
                print("")
            }
        }
        
        // 檢查樓層識別問題
        print("\n=== 樓層識別檢查 ===")
        if multiFloorLocations.isEmpty {
            print("沒有檢測到多樓層地點，檢查原始資料...")
            
            // 檢查前10筆資料的名稱格式
            print("\n前10筆廁所名稱：")
            for (index, toilet) in testToilets.prefix(10).enumerated() {
                print("\(index + 1). \(toilet.name)")
            }
            
            // 檢查是否有包含樓層資訊的廁所
            let floorKeywords = ["F", "樓", "層", "B"]
            let toiletsWithFloor = testToilets.filter { toilet in
                floorKeywords.contains { keyword in
                    toilet.name.contains(keyword)
                }
            }
            
            // ... more code ...
        }
        
        print("=== 快速測試完成 ===")
    }
    
    // 選擇公廁
    func selectToilet(_ toilet: ToiletInfo) {
        selectedToilet = toilet
    }
    
    // 選擇地點
    func selectLocation(_ location: ToiletLocation) {
        selectedLocation = location
    }
}
