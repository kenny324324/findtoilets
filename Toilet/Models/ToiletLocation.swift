import Foundation
import CoreLocation

// MARK: - 樓層資訊
struct FloorInfo: Identifiable, Codable, Equatable {
    let id = UUID()
    let floorName: String        // 樓層名稱，如 "1F", "2F", "B1"
    let floorOrder: Int          // 排序用數字，B2=-2, B1=-1, 1F=1, 2F=2
    let toilets: [ToiletInfo]    // 該樓層的所有廁所
    
    // 計算屬性：該樓層可用的廁所類型
    var availableTypes: Set<String> {
        return Set(toilets.map { $0.type })
    }
    
    // 計算屬性：該樓層的廁所數量
    var toiletCount: Int {
        return toilets.count
    }
}

// MARK: - 廁所地點
struct ToiletLocation: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String                    // 主要名稱，如 "三峽區公有零售市場"
    let address: String                 // 地址
    let latitude: Double                // 緯度
    let longitude: Double               // 經度
    let administration: String          // 管理單位
    let toiletsByFloor: [FloorInfo]     // 按樓層分組的廁所
    
    // 計算屬性：所有廁所（跨樓層）
    var allToilets: [ToiletInfo] {
        return toiletsByFloor.flatMap { $0.toilets }
    }
    
    // 計算屬性：所有可用的廁所類型（跨樓層）
    var availableTypes: Set<String> {
        return Set(allToilets.map { $0.type })
    }
    
    // 計算屬性：總廁所數量
    var totalToiletCount: Int {
        return allToilets.count
    }
    
    // 計算屬性：是否有超過一層
    var hasMultipleFloors: Bool {
        return toiletsByFloor.count > 1
    }
    
    // 計算屬性：是否有尿布檯（任何一個廁所有尿布檯）
    var hasDiaperStation: Bool {
        return allToilets.contains { $0.hasDiaperStation }
    }
    
    // 計算屬性：場所類型（取第一個廁所的場所類型）
    var placeType: String {
        return allToilets.first?.type2 ?? ""
    }
    
    // 計算屬性：該層廁所的平均評分（基於等級）
    func averageRating(for floorName: String) -> Double {
        let floorToilets = toiletsByFloor.first { $0.floorName == floorName }?.toilets ?? []
        guard !floorToilets.isEmpty else { return 0.0 }
        
        // 將等級轉換為數字評分
        let totalRating = floorToilets.reduce(into: 0.0) { sum, toilet in
            let rating = getRatingFromGrade(toilet.grade)
            sum += rating
        }
        return totalRating / Double(floorToilets.count)
    }
    
    // 將等級轉換為數字評分
    private func getRatingFromGrade(_ grade: String) -> Double {
        switch grade {
        case "特優級": return 5.0
        case "優級": return 4.0
        case "良級": return 3.0
        case "普通級": return 2.0
        case "待改善": return 1.0
        default: return 3.0 // 預設中等評分
        }
    }
    
    // 計算屬性：樓層數量
    var floorCount: Int {
        return toiletsByFloor.count
    }
    
    // 計算屬性：座標
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - 本地化方法
    
    // 地點名稱本地化
    func getLocalizedName() -> String {
        let currentLanguage = Locale.current.languageCode ?? "zh"
        
        if currentLanguage == "zh" {
            return self.name
        } else {
            // 非中文語言，進行關鍵詞替換
            return Self.translateLocationName(self.name)
        }
    }
    
    // 地址本地化
    func getLocalizedAddress() -> String {
        let currentLanguage = Locale.current.languageCode ?? "zh"
        
        if currentLanguage == "zh" {
            return self.address
        } else {
            // 非中文語言，進行關鍵詞替換
            return Self.translateLocationName(self.address)
        }
    }
    
    // 管理單位本地化
    func getLocalizedAdministration() -> String {
        let currentLanguage = Locale.current.languageCode ?? "zh"
        
        if currentLanguage == "zh" {
            return self.administration
        } else {
            // 非中文語言，進行關鍵詞替換
            return Self.translateLocationName(self.administration)
        }
    }
    
    // 場所類型本地化
    func getLocalizedPlaceType() -> String {
        let currentLanguage = Locale.current.languageCode ?? "zh"
        
        if currentLanguage == "zh" {
            return self.placeType
        } else {
            // 非中文語言，使用本地化字串
            return Self.translatePlaceType(self.placeType)
        }
    }
    
    // 計算屬性：主要廁所類型（用於地圖標記顯示）
    var primaryTypes: [String] {
        // 按出現頻率排序，取前3個
        let typeCounts = Dictionary(grouping: allToilets, by: { $0.type })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(typeCounts.prefix(3).map { $0.key })
    }
}

// MARK: - 群組邏輯
extension ToiletLocation {
    
    // 從 ToiletInfo 陣列建立 ToiletLocation
    static func createFromToilets(_ toilets: [ToiletInfo]) -> [ToiletLocation] {
        // 第一層：按地址分組
        let addressGroups = Dictionary(grouping: toilets) { $0.address }
        
        var initialLocations: [ToiletLocation] = []
        
        for (address, addressToilets) in addressGroups {
            let validToilets = addressToilets.filter { $0.correctedCoordinate != nil }
            guard !validToilets.isEmpty else { continue }
            
            // 計算所有座標的中心點
            let coordinates = validToilets.compactMap { $0.correctedCoordinate }
            let centerLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
            let centerLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
            
            // 同一地址的廁所全部合併成一個地點
            let floorGroups = groupByFloor(validToilets)
            
            let location = ToiletLocation(
                name: extractLocationName(from: validToilets),
                address: address,
                latitude: centerLat,
                longitude: centerLon,
                administration: validToilets.first?.administration ?? "",
                toiletsByFloor: floorGroups
            )
            initialLocations.append(location)
        }
        
        // 第二層：座標合併（處理地址寫法不同但實際位置相同的情況）
        // 閾值：20公尺 (0.0002 約為 20m)
        let mergeThreshold = 20.0
        var finalLocations: [ToiletLocation] = []
        var mergedIndices: Set<Int> = []
        
        for i in 0..<initialLocations.count {
            if mergedIndices.contains(i) { continue }
            
            var currentLocation = initialLocations[i]
            var mergedToilets = currentLocation.allToilets
            mergedIndices.insert(i)
            
            for j in (i + 1)..<initialLocations.count {
                if mergedIndices.contains(j) { continue }
                
                let otherLocation = initialLocations[j]
                let distance = calculateDistance(
                    lat1: currentLocation.latitude, lon1: currentLocation.longitude,
                    lat2: otherLocation.latitude, lon2: otherLocation.longitude
                )
                
                // 如果距離夠近，視為同一地點進行合併
                if distance < mergeThreshold {
                    print("🔄 [合併偵測] 發現重疊地點：")
                    print("   主地點：\(currentLocation.name) (座標: \(currentLocation.latitude), \(currentLocation.longitude))")
                    print("   副地點：\(otherLocation.name) (座標: \(otherLocation.latitude), \(otherLocation.longitude))")
                    print("   距離：\(String(format: "%.2f", distance)) 公尺")
                    
                    mergedToilets.append(contentsOf: otherLocation.allToilets)
                    mergedIndices.insert(j)
                }
            }
            
            // 如果有合併發生，重新建立 Location 物件
            if mergedToilets.count > currentLocation.allToilets.count {
                print("✅ [合併執行] 成功合併 \(mergedToilets.count) 間廁所到地點：\(currentLocation.name)")
                let floorGroups = groupByFloor(mergedToilets)
                
                // 重新計算中心點
                let validToilets = mergedToilets.filter { $0.correctedCoordinate != nil }
                let coordinates = validToilets.compactMap { $0.correctedCoordinate }
                let newLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
                let newLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
                
                currentLocation = ToiletLocation(
                    name: extractLocationName(from: mergedToilets),
                    address: currentLocation.address, // 使用第一個地址
                    latitude: newLat,
                    longitude: newLon,
                    administration: currentLocation.administration,
                    toiletsByFloor: floorGroups
                )
            }
            
            finalLocations.append(currentLocation)
        }
        
        return finalLocations
    }
    
    // 清理地點名稱（移除樓層、廁所類型等資訊）
    private static func cleanLocationName(_ name: String) -> String {
        var cleanName = name
        
        // 移除廁所類型
        let toiletTypePatterns = [
            "-男廁所?", "-女廁所?", "-親子廁所?", "-無障礙廁所?",
            "-混合廁所?", "-性別友善廁所?", "-通用廁所?",
            "男廁所?$", "女廁所?$", "親子廁所?$", "無障礙廁所?$",
            "混合廁所?$", "性別友善廁所?$", "通用廁所?$"
        ]
        
        for pattern in toiletTypePatterns {
            cleanName = cleanName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 移除樓層資訊
        let floorPatterns = ["[0-9]+F", "[0-9]+樓", "B[0-9]+", "地下[0-9]+樓", "[0-9]+層"]
        for pattern in floorPatterns {
            cleanName = cleanName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return cleanName.trimmingCharacters(in: CharacterSet(charactersIn: "-_ \t\n"))
    }
    
    // 按座標分組
    private static func groupByCoordinate(_ toilets: [ToiletInfo], threshold: Double) -> [[ToiletInfo]] {
        var groups: [[ToiletInfo]] = []
        var used: Set<Int> = []
        
        for (i, toilet) in toilets.enumerated() {
            if used.contains(i) { continue }
            
            var group = [toilet]
            used.insert(i)
            
            for (j, otherToilet) in toilets.enumerated() {
                if used.contains(j) { continue }
                
                guard let coord1 = toilet.correctedCoordinate,
                      let coord2 = otherToilet.correctedCoordinate else {
                    continue
                }
                
                let distance = calculateDistance(
                    lat1: coord1.latitude, lon1: coord1.longitude,
                    lat2: coord2.latitude, lon2: coord2.longitude
                )
                
                if distance <= threshold {
                    group.append(otherToilet)
                    used.insert(j)
                }
            }
            
            groups.append(group)
        }
        
        return groups
    }
    
    // 按樓層分組（相同樓層合併，保留區域資訊在廁所名稱中）
    private static func groupByFloor(_ toilets: [ToiletInfo]) -> [FloorInfo] {
        var floorGroups: [String: [ToiletInfo]] = [:]
        
        for toilet in toilets {
            let floorInfo = extractFloorInfo(from: toilet.name)
            // 只用樓層作為 key，讓相同樓層的所有廁所合併在一起
            let key = "\(floorInfo.floorName)-\(floorInfo.floorOrder)"
            
            if floorGroups[key] == nil {
                floorGroups[key] = []
            }
            floorGroups[key]?.append(toilet)
        }
        
        return floorGroups.compactMap { (key, toilets) in
            let floorInfo = extractFloorInfo(from: toilets.first?.name ?? "")
            
            return FloorInfo(
                floorName: floorInfo.floorName,
                floorOrder: floorInfo.floorOrder,
                toilets: toilets
            )
        }.sorted { $0.floorOrder < $1.floorOrder }
    }
    
    // 從廁所名稱提取區域名稱（例如「自修室」、「中央」、「停車場」）
    static func extractAreaName(from name: String) -> String {
        // 移除主要建築名稱
        var areaName = name
        
        // 常見的建築名稱模式
        let buildingPatterns = [
            "國立臺灣圖書館",
            "台北101",
            "捷運.*站",
            ".*市場",
            ".*百貨",
            ".*大樓"
        ]
        
        for pattern in buildingPatterns {
            areaName = areaName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 移除樓層資訊
        let floorPatterns = ["[0-9]+F", "[0-9]+樓", "B[0-9]+", "地下[0-9]+樓", "[0-9]+層"]
        for pattern in floorPatterns {
            areaName = areaName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 移除廁所類型
        let toiletTypePatterns = [
            "-?男廁所?", "-?女廁所?", "-?親子廁所?", "-?無障礙廁所?",
            "-?混合廁所?", "-?性別友善廁所?", "-?通用廁所?"
        ]
        for pattern in toiletTypePatterns {
            areaName = areaName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 清理前後的分隔符和空白
        areaName = areaName.trimmingCharacters(in: CharacterSet(charactersIn: "-_ \t\n"))
        
        return areaName
    }
    
    // 從廁所名稱提取樓層資訊
    static func extractFloorInfo(from name: String) -> (floorName: String, floorOrder: Int) {
        // 先檢查地下樓層（優先級最高）
        if let regex = try? NSRegularExpression(pattern: "(?:B|地下)([0-9]+)(?:樓|F)?"),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name),
           let floorNumber = Int(String(name[range])) {
            return (floorName: "B\(floorNumber)", floorOrder: -floorNumber)
        }
        
        // 檢查地上樓層
        let patterns = [
            "([0-9]+)F",      // 1F, 2F, 3F
            "([0-9]+)樓",     // 1樓, 2樓
            "([0-9]+)層"      // 1層, 2層
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               let range = Range(match.range(at: 1), in: name),
               let floorNumber = Int(String(name[range])) {
                // 統一使用 "XF" 格式
                return (floorName: "\(floorNumber)F", floorOrder: floorNumber)
            }
        }
        
        // 如果沒有找到樓層資訊，預設為1F
        return (floorName: "1F", floorOrder: 1)
    }
    
    // 提取地點名稱
    private static func extractLocationName(from toilets: [ToiletInfo]) -> String {
        // 嘗試從廁所名稱中提取共同前綴
        let names = toilets.map { $0.name }
        
        // 移除樓層資訊後找共同前綴
        let cleanNames = names.map { name in
            var cleanName = name
            for pattern in ["[0-9]+F", "[0-9]+樓", "B[0-9]+", "地下[0-9]+樓", "[0-9]+層"] {
                cleanName = cleanName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }
            return cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 找最長共同前綴
        if let commonPrefix = findCommonPrefix(cleanNames), !commonPrefix.isEmpty {
            return commonPrefix
        }
        
        // 如果沒有共同前綴，使用第一個廁所的名稱（移除樓層資訊）
        return cleanNames.first ?? toilets.first?.name ?? "未知地點"
    }
    
    // 找共同前綴
    private static func findCommonPrefix(_ strings: [String]) -> String? {
        guard !strings.isEmpty else { return nil }
        
        var prefix = strings[0]
        for string in strings.dropFirst() {
            while !string.hasPrefix(prefix) && !prefix.isEmpty {
                prefix = String(prefix.dropLast())
            }
        }
        
        return prefix.isEmpty ? nil : prefix
    }
    
    // 計算兩點間距離（公尺）
    private static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        return location1.distance(from: location2)
    }
    
    // MARK: - 翻譯方法
    
    // 地點名稱關鍵詞翻譯
    private static func translateLocationName(_ chinese: String) -> String {
        let commonTermsMapping: [String: String] = [
            // 交通運輸
            "車站": "Station",
            "機場": "Airport",
            "高鐵": "High Speed Rail",
            "捷運": "MRT",
            "火車站": "Train Station",
            "客運站": "Bus Station",
            "轉運站": "Transfer Station",
            "停車場": "Parking",
            
            // 政府機關
            "政府": "Government",
            "公所": "Office",
            "區公所": "District Office",
            "市公所": "City Office",
            "縣政府": "County Government",
            "市政府": "City Government",
            "區": "District",
            "市": "City",
            "縣": "County",
            "鄉": "Township",
            "鎮": "Town",
            
            // 醫療
            "醫院": "Hospital",
            "診所": "Clinic",
            "衛生所": "Health Center",
            "榮總": "Veterans General Hospital",
            "長庚": "Chang Gung",
            "台大": "National Taiwan University",
            
            // 教育
            "大學": "University",
            "學院": "College",
            "學校": "School",
            "國小": "Elementary School",
            "國中": "Junior High School",
            "高中": "High School",
            "小學": "Elementary School",
            "中學": "Middle School",
            
            // 商業
            "購物中心": "Shopping Center",
            "百貨公司": "Department Store",
            "商場": "Mall",
            "市場": "Market",
            "夜市": "Night Market",
            "商店": "Store",
            "餐廳": "Restaurant",
            "咖啡廳": "Cafe",
            
            // 景點
            "公園": "Park",
            "森林公園": "Forest Park",
            "紀念館": "Memorial Hall",
            "博物館": "Museum",
            "圖書館": "Library",
            "文化中心": "Cultural Center",
            "體育館": "Gymnasium",
            "運動中心": "Sports Center",
            "游泳池": "Swimming Pool",
            
            // 宗教
            "寺廟": "Temple",
            "教堂": "Church",
            "宮": "Palace",
            "廟": "Temple",
            "寺": "Temple",
            
            // 其他
            "大樓": "Building",
            "廣場": "Square",
            "地下": "Underground",
            "地上": "Ground",
            "樓": "Floor",
            "層": "Floor",
            "號": "No.",
            "路": "Road",
            "街": "Street",
            "巷": "Lane",
            "弄": "Alley"
        ]
        
        var translated = chinese
        for (chineseTerm, englishTerm) in commonTermsMapping {
            translated = translated.replacingOccurrences(of: chineseTerm, with: englishTerm)
        }
        
        return translated
    }
    
    // 場所類型翻譯
    private static func translatePlaceType(_ chinese: String) -> String {
        let placeTypeMapping: [String: String] = [
            "商業營業場所": "Commercial Venue",
            "交通運輸場站": "Transportation Hub",
            "觀光遊憩場所": "Tourist Attraction",
            "宗教禮儀場所": "Religious Venue",
            "政府機關": "Government Building",
            "教育場所": "Educational Institution",
            "醫療場所": "Healthcare Facility"
        ]
        
        return placeTypeMapping[chinese] ?? chinese
    }
}
