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
        
        var locations: [ToiletLocation] = []
        
        for (address, addressToilets) in addressGroups {
            // 第二層：按座標分組（處理同一地址不同建築）
            let coordinateGroups = groupByCoordinate(addressToilets, threshold: 50) // 50公尺
            
            for coordinateToilets in coordinateGroups {
                // 第三層：按樓層分組
                let floorGroups = groupByFloor(coordinateToilets)
                
                // 建立 ToiletLocation
                let location = ToiletLocation(
                    name: extractLocationName(from: coordinateToilets),
                    address: address,
                    latitude: Double(coordinateToilets.first?.latitude ?? "0") ?? 0,
                    longitude: Double(coordinateToilets.first?.longitude ?? "0") ?? 0,
                    administration: coordinateToilets.first?.administration ?? "",
                    toiletsByFloor: floorGroups
                )
                locations.append(location)
            }
        }
        
        return locations
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
                
                let distance = calculateDistance(
                    lat1: Double(toilet.latitude) ?? 0, lon1: Double(toilet.longitude) ?? 0,
                    lat2: Double(otherToilet.latitude) ?? 0, lon2: Double(otherToilet.longitude) ?? 0
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
    
    // 按樓層分組
    private static func groupByFloor(_ toilets: [ToiletInfo]) -> [FloorInfo] {
        var floorGroups: [String: [ToiletInfo]] = [:]
        
        for toilet in toilets {
            let floorInfo = extractFloorInfo(from: toilet.name)
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
    
    // 從廁所名稱提取樓層資訊
    static func extractFloorInfo(from name: String) -> (floorName: String, floorOrder: Int) {
        let patterns = [
            "([0-9]+)F": 1,           // 1F, 2F, 3F
            "([0-9]+)樓": 1,          // 1樓, 2樓
            "B([0-9]+)": -1,          // B1, B2 (負數)
            "地下([0-9]+)樓": -1,      // 地下1樓
            "([0-9]+)層": 1           // 1層, 2層
        ]
        
        for (pattern, multiplier) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               let range = Range(match.range(at: 1), in: name),
               let floorNumber = Int(String(name[range])) {
                
                let floorOrder = floorNumber * multiplier
                let floorName = String(name[range]) + (multiplier == -1 ? "F" : "F")
                
                return (floorName: floorName, floorOrder: floorOrder)
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
