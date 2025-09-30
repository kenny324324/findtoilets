import SwiftUI
import CoreLocation
import UIKit

struct CountryView: View {
    @Binding var sheetPresented: Bool
    @Binding var selectedDetent: PresentationDetent
    @State private var searchText: String = ""
    @State private var suggestions: [ToiletLocation] = [] // 儲存建議地點資訊
    @State private var selectedToilet: ToiletInfo?   // 儲存選中的公廁
    @FocusState private var isSearchFieldFocused: Bool // 控制鍵盤焦點
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var nearbyLocations: [ToiletLocation] = [] // 緩存附近地點
    @State private var nearbyLocationsWithDistance: [(ToiletLocation, Int)] = [] // 緩存帶距離的附近地點
    @ObservedObject var locationManager: LocationManager // 使用傳入的 LocationManager
    @StateObject private var toiletDataManager = ToiletDataManager() // 公廁資料管理器
    @Binding var mapToilets: [ToiletInfo] // 要在地圖上顯示的公廁
    @State private var showingSettings = false // 控制設定 sheet 顯示
    @State private var selectedToiletForDetail: ToiletInfo? = nil // 選中要顯示詳細資訊的公廁
    @State private var showingToiletDetail = false // 控制是否顯示公廁詳細頁面
    @Binding var selectedToiletFromMap: ToiletInfo? // 從地圖選中的公廁
    @Binding var selectedLocationFromMap: ToiletLocation? // 從地圖選中的地點
    @State private var selectedLocationForDetail: ToiletLocation? = nil // 選中要顯示詳細資訊的地點
    @State private var showingLocationDetail = false // 控制是否顯示地點詳細頁面

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 固定的標題和搜尋區域
            VStack(spacing: 16) {
                // 標題 + 設定按鈕
                HStack {
                    Text(LocalizedStrings.appTitle.localized)
                        .font(.titleRounded(.bold))
                    
                    Spacer()
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                }

                // 搜尋框 + 定位按鈕
                HStack(spacing: 12) {
                    // 搜尋框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.bodyRounded(.bold))
                        TextField(LocalizedStrings.searchPlaceholder.localized, text: $searchText)
                            .font(.bodyRounded())
                            .focused($isSearchFieldFocused)
                                .onChange(of: searchText) { query in
                                    // 用戶開始搜尋時，停止定位
                                    locationManager.stopLocationUpdates()
                                    // 使用真實資料搜尋
                                    loadSuggestions(for: query)
                                }
                            .font(.bodyRounded(.bold))
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(18)
                }
                }
                .padding(.horizontal, 5)
                .padding(.top)
                .padding(.leading)
                .padding(.trailing)
                .padding(.bottom, 16)
                .background(Color(.systemBackground))
                
                // 分格線
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)

                // 可捲動的內容區域 - 使用 GeometryReader 確保獨立捲動
                GeometryReader { geometry in
                    if isLoading {
                        CustomLoadingView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "location.slash")
                                .font(.customRounded(50))
                                .foregroundColor(.gray)
                            Text(LocalizedStrings.locationPermissionRequired.localized)
                                .font(.headlineRounded())
                                .padding(.top)
                            Text(LocalizedStrings.locationPermissionDescription.localized)
                                .font(.subheadlineRounded())
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button(LocalizedStrings.goToSettings.localized) {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !suggestions.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(suggestions, id: \.id) { location in
                                    Button(action: {
                                        selectedLocationForDetail = location
                                        showingLocationDetail = true
                                    }) {
                                        LocationRowView(location: location, distance: getRealDistanceForLocation(location))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .onAppear {
                            mapToilets = suggestions.flatMap { $0.allToilets }
                        }
                    } else if !searchText.isEmpty {
                        VStack {
                            Spacer()
                            Text(LocalizedStrings.noToiletsFound.localized)
                                .foregroundColor(.gray)
                                .font(.bodyRounded())
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 預設顯示附近公廁
                        if toiletDataManager.isLoading {
                            VStack {
                                Spacer()
                                ProgressView(LocalizedStrings.loadingToilets.localized)
                                    .font(.subheadlineRounded())
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if locationManager.isLocating {
                                VStack {
                                    Spacer()
                                    ProgressView(LocalizedStrings.locating.localized)
                                        .font(.subheadlineRounded())
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                if nearbyLocations.isEmpty {
                                    VStack {
                                        Spacer()
                                        Image(systemName: "location.slash")
                                            .font(.customRounded(50))
                                            .foregroundColor(.gray)
                                        Text(LocalizedStrings.needLocationForNearby.localized)
                                            .font(.headlineRounded())
                                            .padding(.top)
                                        Text(LocalizedStrings.pressLocationButton.localized)
                                            .font(.subheadlineRounded())
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .onAppear {
                                        mapToilets = []
                                    }
                                } else {
                                    ScrollView {
                                        LazyVStack(spacing: 0) {
                                            ForEach(nearbyLocationsWithDistance, id: \.0.id) { locationWithDistance in
                                                Button(action: {
                                                    selectedLocationForDetail = locationWithDistance.0
                                                    showingLocationDetail = true
                                                }) {
                                                    LocationRowView(location: locationWithDistance.0, distance: locationWithDistance.1)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .onAppear {
                                        mapToilets = nearbyLocations.flatMap { $0.allToilets }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: locationManager.location) { _ in
                // 位置變化時更新附近公廁緩存
                updateNearbyToilets()
            }
            .onChange(of: locationManager.authorizationStatus) { status in
                // 權限狀態變更時更新附近公廁緩存
                print("權限狀態變更：\(status.rawValue)")
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    // 權限獲得後，立即更新附近公廁
                    updateNearbyToilets()
                } else if status == .denied || status == .restricted {
                    // 權限被拒絕時，清空附近公廁
                    nearbyLocations = []
                    nearbyLocationsWithDistance = []
                }
            }
            .onAppear {
                // 初始載入時更新附近公廁緩存
                updateNearbyToilets()
            }
            .onChange(of: selectedToiletFromMap) { newToilet in
                // 當從地圖選中公廁時，自動跳轉到詳細頁面
                if let toilet = newToilet {
                    selectedToiletForDetail = toilet
                    showingToiletDetail = true
                    // 清空地圖選中的公廁，避免重複觸發
                    selectedToiletFromMap = nil
                }
            }
            .onChange(of: selectedLocationFromMap) { newLocation in
                // 當從地圖選中地點時，自動跳轉到地點詳細頁面
                if let location = newLocation {
                    selectedLocationForDetail = location
                    showingLocationDetail = true
                    // 清空地圖選中的地點，避免重複觸發
                    selectedLocationFromMap = nil
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .interactiveDismissDisabled(true)
            }
            .background(
                // 使用隱藏的 NavigationLink 來處理程式化的導航
                Group {
                    // 廁所詳情
                    NavigationLink(
                        destination: selectedToiletForDetail.map { ToiletDetailView(toilet: $0) },
                        isActive: $showingToiletDetail
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    // 地點詳情
                    NavigationLink(
                        destination: selectedLocationForDetail.map { LocationDetailView(location: $0) },
                        isActive: $showingLocationDetail
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            )
        }
    }

    // 搜尋功能
    private func loadSuggestions(for query: String) {
        if query.isEmpty {
            // 清空搜尋文字時，清空建議並重新顯示附近地點
            suggestions = []
            mapToilets = nearbyLocations.flatMap { $0.allToilets }
            return
        }
        
        // 顯示載入狀態
        isLoading = true
        
        // 使用真實資料搜尋，至少顯示兩秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            
            // 使用 ToiletDataManager 搜尋地點
            let searchResults = toiletDataManager.searchLocations(query: query)
            
            // 按距離排序搜尋結果（由小到大）
            if locationManager.location != nil {
                suggestions = searchResults.sorted { first, second in
                    let firstDistance = getRealDistanceForLocation(first)
                    let secondDistance = getRealDistanceForLocation(second)
                    return firstDistance < secondDistance
                }
            } else {
                // 如果沒有位置資訊，保持原始順序
                suggestions = searchResults
            }
            
            mapToilets = suggestions.flatMap { $0.allToilets }
        }
    }
    
    // 定位到目前位置
    private func locateCurrentPosition() {
        // 清空搜尋文字，顯示附近地點
        searchText = ""
        suggestions = []
        isSearchFieldFocused = false
        
        // 檢查權限狀態
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // 首次使用，請求權限
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            // 權限被拒絕，顯示提示
            break
        case .authorizedWhenInUse, .authorizedAlways:
            // 有權限，開始定位
            locationManager.getCurrentLocation()
        @unknown default:
            break
        }
    }
    
    
    // 計算真實距離（已優化，使用緩存）
    private func getRealDistance(for toilet: ToiletInfo) -> Int {
        // 先嘗試從緩存中找距離
        if let cachedDistance = nearbyLocationsWithDistance.flatMap({ locationWithDistance in
            locationWithDistance.0.allToilets.map { ($0, locationWithDistance.1) }
        }).first(where: { $0.0.id == toilet.id })?.1 {
            return cachedDistance
        }
        
        // 如果緩存中沒有，則計算
        guard let userLocation = locationManager.location else {
            return 999999 // 沒有位置時返回很大的數字
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: toilet)
    }
    
    // 示範距離計算（當沒有真實位置時使用）
    private func getDemoDistance(for toilet: ToiletInfo) -> Int {
        switch toilet.number {
        case "DEMO001": return 150  // 台北101最近
        case "DEMO002": return 280  // 台北車站
        case "DEMO003": return 350  // 大安森林公園
        case "DEMO004": return 420  // 中正紀念堂
        case "DEMO005": return 580  // 龍山寺
        case "DEMO006": return 680  // 松山機場
        case "DEMO007": return 200  // 西門町
        case "DEMO008": return 320  // 台北市政府
        case "DEMO009": return 450  // 信義威秀
        case "DEMO010": return 520  // 象山步道
        case "DEMO011": return 620  // 台北醫學大學
        case "DEMO012": return 380  // 松山文創園區
        default: return 500
        }
    }
    
    // 示範公廁資料
    private func getDemoToilets() -> [ToiletInfo] {
        return [
            ToiletInfo(
                county: "10001",
                city: "1000101",
                village: "信義區",
                number: "DEMO001",
                name: "台北101-女廁",
                address: "台北市信義區信義路五段7號",
                administration: "台北101",
                latitude: "25.0330",
                longitude: "121.5654",
                grade: "特優級",
                type2: "商業營業場所",
                type: "女廁所",
                exec: "台北101",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000101",
                village: "信義區",
                number: "DEMO002",
                name: "台北車站-男廁",
                address: "台北市中正區北平西路3號",
                administration: "台灣鐵路管理局",
                latitude: "25.0478",
                longitude: "121.5170",
                grade: "優級",
                type2: "交通運輸場站",
                type: "男廁所",
                exec: "台灣鐵路管理局",
                diaper: "0"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000102",
                village: "大安區",
                number: "DEMO003",
                name: "大安森林公園-親子廁所",
                address: "台北市大安區新生南路二段1號",
                administration: "台北市政府公園路燈工程管理處",
                latitude: "25.0264",
                longitude: "121.5361",
                grade: "特優級",
                type2: "觀光遊憩場所",
                type: "親子廁所",
                exec: "台北市政府",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000103",
                village: "中正區",
                number: "DEMO004",
                name: "中正紀念堂-無障礙廁所",
                address: "台北市中正區中山南路21號",
                administration: "國立中正紀念堂管理處",
                latitude: "25.0360",
                longitude: "121.5199",
                grade: "特優級",
                type2: "觀光遊憩場所",
                type: "無障礙廁所",
                exec: "國立中正紀念堂管理處",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000104",
                village: "萬華區",
                number: "DEMO005",
                name: "龍山寺-通用廁所",
                address: "台北市萬華區廣州街211號",
                administration: "龍山寺",
                latitude: "25.0371",
                longitude: "121.4995",
                grade: "優級",
                type2: "宗教禮儀場所",
                type: "通用廁所",
                exec: "龍山寺",
                diaper: "0"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000105",
                village: "松山區",
                number: "DEMO006",
                name: "松山機場-女廁",
                address: "台北市松山區敦化北路340之9號",
                administration: "交通部民用航空局",
                latitude: "25.0697",
                longitude: "121.5519",
                grade: "特優級",
                type2: "交通運輸場站",
                type: "女廁所",
                exec: "交通部民用航空局",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000106",
                village: "士林區",
                number: "DEMO007",
                name: "士林夜市-男廁",
                address: "台北市士林區基河路101號",
                administration: "台北市政府市場處",
                latitude: "25.0881",
                longitude: "121.5255",
                grade: "良級",
                type2: "商業營業場所",
                type: "男廁所",
                exec: "台北市政府市場處",
                diaper: "0"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000107",
                village: "北投區",
                number: "DEMO008",
                name: "北投溫泉博物館-親子廁所",
                address: "台北市北投區中山路2號",
                administration: "台北市政府文化局",
                latitude: "25.1364",
                longitude: "121.5085",
                grade: "特優級",
                type2: "觀光遊憩場所",
                type: "親子廁所",
                exec: "台北市政府文化局",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000108",
                village: "內湖區",
                number: "DEMO009",
                name: "內湖科技園區-通用廁所",
                address: "台北市內湖區瑞光路399號",
                administration: "內湖科技園區服務中心",
                latitude: "25.0797",
                longitude: "121.5752",
                grade: "優級",
                type2: "商業營業場所",
                type: "通用廁所",
                exec: "內湖科技園區服務中心",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000109",
                village: "文山區",
                number: "DEMO010",
                name: "貓空纜車站-無障礙廁所",
                address: "台北市文山區指南路三段38巷",
                administration: "台北大眾捷運股份有限公司",
                latitude: "24.9667",
                longitude: "121.5833",
                grade: "特優級",
                type2: "交通運輸場站",
                type: "無障礙廁所",
                exec: "台北大眾捷運股份有限公司",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000110",
                village: "南港區",
                number: "DEMO011",
                name: "南港展覽館-女廁",
                address: "台北市南港區經貿二路1號",
                administration: "台北市政府產業發展局",
                latitude: "25.0556",
                longitude: "121.6167",
                grade: "特優級",
                type2: "商業營業場所",
                type: "女廁所",
                exec: "台北市政府產業發展局",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000111",
                village: "大同區",
                number: "DEMO012",
                name: "迪化街-男廁",
                address: "台北市大同區迪化街一段",
                administration: "台北市政府商業處",
                latitude: "25.0583",
                longitude: "121.5083",
                grade: "良級",
                type2: "商業營業場所",
                type: "男廁所",
                exec: "台北市政府商業處",
                diaper: "0"
            )
        ].sorted { first, second in
            let firstDistance = getRealDistance(for: first)
            let secondDistance = getRealDistance(for: second)
            return firstDistance < secondDistance
        }
    }
    
    // 更新附近地點緩存（優化版本）
    private func updateNearbyToilets() {
        // 檢查權限狀態
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("權限不足，無法更新附近公廁")
            nearbyLocations = []
            nearbyLocationsWithDistance = []
            return
        }
        
        guard let userLocation = locationManager.location else {
            print("沒有位置資訊，無法更新附近公廁")
            nearbyLocations = []
            nearbyLocationsWithDistance = []
            return
        }
        
        print("更新附近公廁，位置：\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        
        // 使用 ToiletDataManager 的優化版本，一次計算得到地點和距離
        nearbyLocationsWithDistance = toiletDataManager.findNearbyLocationsWithDistance(userLocation: userLocation, radius: 1000)
        nearbyLocations = nearbyLocationsWithDistance.map { $0.0 }
        
        print("找到 \(nearbyLocations.count) 個附近地點")
    }
    
    // 取得附近地點
    private func getNearbyLocations() -> [ToiletLocation] {
        return nearbyLocations
    }
    
    // 計算地點的距離
    private func getRealDistanceForLocation(_ location: ToiletLocation) -> Int {
        guard let userLocation = locationManager.location else {
            return 999999 // 沒有位置時返回很大的數字
        }
        
        // 使用地點的第一個廁所來計算距離
        guard let firstToilet = location.allToilets.first else {
            return 999999
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: firstToilet)
    }
    
    // 格式化距離顯示
    static func formatDistance(_ distance: Int) -> String {
        if distance >= 1000 {
            let kilometers = Double(distance) / 1000.0
            if kilometers == Double(Int(kilometers)) {
                // 整數公里
                return "\(Int(kilometers))km"
            } else {
                // 小數公里，保留一位小數
                return String(format: "%.1fkm", kilometers)
            }
        } else {
            return "\(distance)m"
        }
    }
}

// 地點列表項目視圖
struct LocationRowView: View {
    let location: ToiletLocation
    let distance: Int
    
    // 預計算的屬性
    private let cleanName: String
    private let starCount: Int
    private let distanceTextColor: Color
    private let distanceBackgroundColor: Color
    private let availableTypes: [String]
    
    init(location: ToiletLocation, distance: Int) {
        self.location = location
        self.distance = distance
        
        // 預計算所有屬性
        self.cleanName = Self.getCleanLocationName(location.name)
        self.starCount = Self.getStarCount(for: location)
        self.distanceTextColor = Self.getDistanceTextColor(for: distance)
        self.distanceBackgroundColor = Self.getDistanceBackgroundColor(for: distance)
        self.availableTypes = Array(location.availableTypes)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 左邊的地點圖示
            Image(systemName: location.hasMultipleFloors ? "building.2.fill" : "toilet")
                .font(.title3Rounded())
                .foregroundColor(location.hasMultipleFloors ? .orange : .blue)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((location.hasMultipleFloors ? Color.orange : Color.blue).opacity(0.2))
                        .frame(width: 40, height: 40)
                )
            
            // 中間的資訊
            VStack(alignment: .leading, spacing: 4) {
                // 地點名稱
                Text(location.name)
                    .font(.headlineRounded(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // 評分（只顯示實心星星，不顯示空星星）
                if starCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<starCount, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.captionRounded(.medium))
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 右邊的距離和箭頭
            HStack(spacing: 8) {
                // 距離
                Text(CountryView.formatDistance(distance))
                    .font(.subheadlineRounded(.semibold))
                    .foregroundColor(distanceBackgroundColor) // 使用底色100%作為文字顏色
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(distanceBackgroundColor.opacity(0.2))
                    )
                
                // 箭頭
                Image(systemName: "chevron.right")
                    .font(.captionRounded())
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
    
    // 清理地點名稱（移除廁所類型及其前面的 -）
    private static func getCleanLocationName(_ name: String) -> String {
        let toiletTypes = ["-女廁", "-男廁", "-親子廁所", "-無障礙廁所", "-通用廁所", "-混合廁所", "-性別友善廁所"]
        
        var cleanName = name
        for type in toiletTypes {
            if cleanName.hasSuffix(type) {
                cleanName = String(cleanName.dropLast(type.count))
                break
            }
        }
        return cleanName.trimmingCharacters(in: .whitespaces)
    }
    
    // 計算星級評分（最多3顆星）
    private static func getStarCount(for location: ToiletLocation) -> Int {
        let allGrades = location.allToilets.map { $0.grade }
        let highestGrade = allGrades.max { grade1, grade2 in
            getGradeValue(grade1) < getGradeValue(grade2)
        } ?? "普通級"
        
        // 限制最多3顆星
        return min(getGradeValue(highestGrade), 3)
    }
    
    // 將等級轉換為數字（最多3顆星）
    private static func getGradeValue(_ grade: String) -> Int {
        switch grade {
        case "特優級": return 3
        case "優級": return 2
        case "良級": return 1
        case "普通級": return 1
        case "待改善": return 1
        default: return 1
        }
    }
    
    
    // 根據距離獲取文字顏色
    private static func getDistanceTextColor(for distance: Int) -> Color {
        switch distance {
        case 0..<200: return .white
        case 200..<500: return .white
        case 500..<1000: return .white
        default: return .white
        }
    }
    
    // 根據距離獲取背景顏色
    private static func getDistanceBackgroundColor(for distance: Int) -> Color {
        switch distance {
        case 0..<200: return .green
        case 200..<500: return .orange
        case 500..<1000: return .red
        default: return .gray
        }
    }
}

// 廁所列表項目視圖（優化版本）
struct ToiletRowView: View {
    let toilet: ToiletInfo
    let distance: Int
    
    // 預計算的屬性，避免重複計算
    private let cleanName: String
    private let typeIcon: String
    private let typeColor: Color
    private let type2Icon: String
    private let starCount: Int
    private let distanceTextColor: Color
    private let distanceBackgroundColor: Color
    
    init(toilet: ToiletInfo, distance: Int) {
        self.toilet = toilet
        self.distance = distance
        
        // 預計算所有屬性
        self.cleanName = Self.getCleanToiletName(toilet.name)
        self.typeIcon = toilet.typeIcon
        self.typeColor = toilet.typeColor
        self.type2Icon = toilet.type2Icon
        self.starCount = Self.getStarCount(for: toilet.grade)
        self.distanceTextColor = Self.getDistanceTextColor(for: distance)
        self.distanceBackgroundColor = Self.getDistanceBackgroundColor(for: distance)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 左邊的廁所圖示
            Image(systemName: typeIcon)
                .font(.title3Rounded())
                .foregroundColor(typeColor)
                .frame(width: 50, height: 50)
                .background(typeColor.opacity(0.2))
                .cornerRadius(10)
            
            // 中間 VStack
            VStack(alignment: .leading, spacing: 8) {
                // 廁所名稱
                Text(cleanName)
                    .font(.headlineRounded(.bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                // 三個小項目
                HStack(spacing: 8) {
                    // 星星評分（固定最小寬度）
                    HStack(spacing: 1) {
                        ForEach(0..<starCount, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2Rounded())
                                .foregroundColor(.yellow)
                        }
                        ForEach(0..<(3 - starCount), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2Rounded())
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 40, alignment: .leading)
                    
                    // 場所圖標（固定寬度）
                    Image(systemName: type2Icon)
                        .font(.caption2Rounded())
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .center)
                    
                    // 類型膠囊（彈性寬度，優先級最高）
                    Text(toilet.type)
                        .font(.caption2Rounded())
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            
            Spacer(minLength: 8)
            
            // 右邊距離徽章和箭頭
            HStack(spacing: 8) {
                // 距離徽章
                Text(CountryView.formatDistance(distance))
                    .font(.subheadlineRounded(.semibold))
                    .foregroundColor(distanceTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(distanceBackgroundColor)
                    .cornerRadius(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // 箭頭
                Image(systemName: "chevron.right")
                    .font(.captionRounded())
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)  // 增加左右 margin
        .padding(.vertical, 12)
    }
    
    // 清理廁所名稱，移除類型後綴
    private static func getCleanToiletName(_ name: String) -> String {
        let suffixes = ["-女廁", "-男廁", "-親子廁所", "-無障礙廁所", "-通用廁所"]
        var cleanName = name
        for suffix in suffixes {
            if cleanName.hasSuffix(suffix) {
                cleanName = String(cleanName.dropLast(suffix.count))
                break
            }
        }
        return cleanName
    }
    
    // 根據等級返回星級數量
    private static func getStarCount(for grade: String) -> Int {
        switch grade {
        case "特優級":
            return 3
        case "優級":
            return 2
        case "良級":
            return 1
        case "普級":
            return 1
        default:
            return 1
        }
    }
    
    // 根據距離返回文字顏色
    private static func getDistanceTextColor(for distance: Int) -> Color {
        if distance <= 200 {
            return .green
        } else if distance <= 500 {
            return .orange
        } else {
            return .gray
        }
    }
    
    // 根據距離返回背景顏色
    private static func getDistanceBackgroundColor(for distance: Int) -> Color {
        if distance <= 200 {
            return Color.green.opacity(0.2)
        } else if distance <= 500 {
            return Color.orange.opacity(0.2)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    // 廁所類型本地化
    private func getLocalizedToiletType(_ type: String) -> String {
        let currentLanguage = Locale.current.languageCode ?? "zh"
        
        if currentLanguage == "zh" {
            return type
        } else {
            // 非中文語言，使用本地化字串
            switch type {
            case "女廁所":
                return LocalizedStrings.toiletTypeFemale.localized
            case "男廁所":
                return LocalizedStrings.toiletTypeMale.localized
            case "親子廁所":
                return LocalizedStrings.toiletTypeFamily.localized
            case "無障礙廁所":
                return LocalizedStrings.toiletTypeAccessible.localized
            case "混合廁所":
                return LocalizedStrings.toiletTypeMixed.localized
            case "性別友善廁所":
                return LocalizedStrings.toiletTypeGenderFriendly.localized
            default:
                return type
            }
        }
    }
}

// 設定視圖
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 設定內容區域
                VStack(spacing: 16) {
                    // 位置權限設定
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStrings.locationPermission.localized)
                                .font(.headline)
                            Text(LocalizedStrings.locationPermissionDetail.localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // 通知設定
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStrings.notificationSettings.localized)
                                .font(.headline)
                            Text(LocalizedStrings.notificationDetail.localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // 關於應用程式
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStrings.aboutApp.localized)
                                .font(.headline)
                            Text(LocalizedStrings.version.localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(LocalizedStrings.settings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStrings.done.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CountryView(
        sheetPresented: .constant(true), 
        selectedDetent: .constant(.medium), 
        locationManager: LocationManager(), 
        mapToilets: .constant([]), 
    selectedToiletFromMap: .constant(nil), 
    selectedLocationFromMap: .constant(nil)
)
}

// MARK: - Custom Loading View
struct CustomLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Spacer()
            
            // 簡化的脈衝動畫（淺灰色，縮小尺寸）
            ZStack {
                // 外層脈衝圈
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .scaleEffect(isAnimating ? 1.3 : 0.8)
                    .opacity(isAnimating ? 0.0 : 0.6)
                    .animation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                // 中層脈衝圈
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 35, height: 35)
                    .scaleEffect(isAnimating ? 1.2 : 0.9)
                    .opacity(isAnimating ? 0.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: false)
                            .delay(0.2),
                        value: isAnimating
                    )
                
                // 內層核心圓圈
                Circle()
                    .fill(Color.gray)
                    .frame(width: 25, height: 25)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}
