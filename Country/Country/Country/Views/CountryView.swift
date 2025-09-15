import SwiftUI
import CoreLocation

struct CountryView: View {
    @Binding var sheetPresented: Bool
    @Binding var selectedDetent: PresentationDetent
    @State private var searchText: String = ""
    @State private var suggestions: [ToiletInfo] = [] // 儲存建議公廁資訊
    @State private var selectedToilet: ToiletInfo?   // 儲存選中的公廁
    @FocusState private var isSearchFieldFocused: Bool // 控制鍵盤焦點
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var nearbyToilets: [ToiletInfo] = [] // 緩存附近公廁
    @State private var nearbyToiletsWithDistance: [(ToiletInfo, Int)] = [] // 緩存帶距離的附近公廁
    @ObservedObject var locationManager: LocationManager // 使用傳入的 LocationManager
    @StateObject private var toiletDataManager = ToiletDataManager() // 公廁資料管理器
    @Binding var mapToilets: [ToiletInfo] // 要在地圖上顯示的公廁
    @State private var showingSettings = false // 控制設定 sheet 顯示
    @State private var selectedToiletForDetail: ToiletInfo? = nil // 選中要顯示詳細資訊的公廁
    @State private var showingToiletDetail = false // 控制是否顯示公廁詳細頁面
    @Binding var selectedToiletFromMap: ToiletInfo? // 從地圖選中的公廁

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 固定的標題和搜尋區域
            VStack(spacing: 16) {
                // 標題 + 設定按鈕
                HStack {
                    Text("找廁所")
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
                        TextField("輸入您的位置", text: $searchText)
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
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "location.slash")
                                .font(.customRounded(50))
                                .foregroundColor(.gray)
                            Text("需要位置權限")
                                .font(.headlineRounded())
                                .padding(.top)
                            Text("請在設定中允許位置存取\n才能使用定位功能")
                                .font(.subheadlineRounded())
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button("前往設定") {
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
                                ForEach(suggestions, id: \.id) { suggestion in
                                    Button(action: {
                                        selectedToiletForDetail = suggestion
                                        showingToiletDetail = true
                                    }) {
                                        ToiletRowView(toilet: suggestion, distance: getRealDistance(for: suggestion))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .onAppear {
                            mapToilets = suggestions
                        }
                    } else if !searchText.isEmpty {
                        VStack {
                            Spacer()
                            Text("找不到相關公廁")
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
                                ProgressView("載入公廁資料中...")
                                    .font(.subheadlineRounded())
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if locationManager.isLocating {
                                VStack {
                                    Spacer()
                                    ProgressView("定位中...")
                                        .font(.subheadlineRounded())
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                if nearbyToilets.isEmpty {
                                    VStack {
                                        Spacer()
                                        Image(systemName: "location.slash")
                                            .font(.customRounded(50))
                                            .foregroundColor(.gray)
                                        Text("需要定位才能顯示附近公廁")
                                            .font(.headlineRounded())
                                            .padding(.top)
                                        Text("請按下定位按鈕或允許位置權限")
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
                                            ForEach(nearbyToiletsWithDistance, id: \.0.id) { toiletWithDistance in
                                                Button(action: {
                                                    selectedToiletForDetail = toiletWithDistance.0
                                                    showingToiletDetail = true
                                                }) {
                                                    ToiletRowView(toilet: toiletWithDistance.0, distance: toiletWithDistance.1)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .onAppear {
                                        mapToilets = nearbyToilets
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
            .onAppear {
                // 初始載入時更新附近公廁緩存
                updateNearbyToilets()
            }
            .onChange(of: selectedToiletFromMap) { newToilet in
                // 當從地圖選中公廁時，自動跳轉到詳細頁面
                if let toilet = newToilet {
                    // 使用 NavigationLink 的方式跳轉，就像點擊列表項目一樣
                    selectedToiletForDetail = toilet
                    showingToiletDetail = true
                    // 清空地圖選中的公廁，避免重複觸發
                    selectedToiletFromMap = nil
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .interactiveDismissDisabled(true)
            }
            .background(
                // 使用隱藏的 NavigationLink 來處理程式化的導航
                NavigationLink(
                    destination: selectedToiletForDetail.map { ToiletDetailView(toilet: $0) },
                    isActive: $showingToiletDetail
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }

    // 搜尋功能
    private func loadSuggestions(for query: String) {
        if query.isEmpty {
            // 清空搜尋文字時，清空建議並重新顯示附近公廁
            suggestions = []
            mapToilets = nearbyToilets
            return
        }
        
        // 顯示載入狀態
        isLoading = true
        
        // 使用真實資料搜尋
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // 減少延遲時間
            isLoading = false
            
            // 使用 ToiletDataManager 搜尋
            suggestions = toiletDataManager.searchToilets(query: query)
            mapToilets = suggestions
        }
    }
    
    // 定位到目前位置
    private func locateCurrentPosition() {
        // 清空搜尋文字，顯示附近公廁
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
        if let cachedDistance = nearbyToiletsWithDistance.first(where: { $0.0.id == toilet.id })?.1 {
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
    
    // 更新附近公廁緩存（優化版本）
    private func updateNearbyToilets() {
        guard let userLocation = locationManager.location else {
            nearbyToilets = []
            nearbyToiletsWithDistance = []
            return
        }
        
        // 使用 ToiletDataManager 的優化版本，一次計算得到公廁和距離
        nearbyToiletsWithDistance = toiletDataManager.findNearbyToiletsWithDistance(userLocation: userLocation, radius: 1000)
        nearbyToilets = nearbyToiletsWithDistance.map { $0.0 }
    }
    
    // 取得附近公廁
    private func getNearbyToilets() -> [ToiletInfo] {
        return nearbyToilets
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
                Text("\(distance)m")
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
                            Text("位置權限")
                                .font(.headline)
                            Text("允許應用程式存取您的位置以顯示附近公廁")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 通知設定
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("通知設定")
                                .font(.headline)
                            Text("接收公廁相關通知和更新")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 關於應用程式
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("關於應用程式")
                                .font(.headline)
                            Text("版本 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CountryView(sheetPresented: .constant(true), selectedDetent: .constant(.medium), locationManager: LocationManager(), mapToilets: .constant([]), selectedToiletFromMap: .constant(nil))
}
