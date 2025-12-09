//
//  HomeSheetView.swift
//  Toilet
//
//  主畫面 sheet，顯示初始選項
//

import SwiftUI
import CoreLocation
import Combine

struct HomeSheetView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    @Binding var selectedDetent: PresentationDetent
    @State private var showNearbyList: Bool = false
    @State private var nearbyListDetent: PresentationDetent = .medium
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var toiletDataManager: ToiletDataManager // 改為 ObservedObject，接收外部傳入的實例
    @Binding var mapToilets: [ToiletInfo]
    @Binding var mapLocations: [ToiletLocation]
    @Binding var selectedToiletFromMap: ToiletInfo?
    @Binding var selectedLocationFromMap: ToiletLocation?
    
    // 預先緩存的附近廁所數據
    @State private var cachedNearbyLocations: [ToiletLocation] = []
    @State private var cachedNearbyLocationsWithDistance: [(ToiletLocation, Int)] = []
    
    // 最近瀏覽
    @State private var recentlyViewedLocations: [ToiletLocation] = []
    
    // 搜尋相關狀態
    @State private var searchText: String = ""
    @State private var searchResults: [ToiletLocation] = []
    @State private var isSearching: Bool = false
    
    // 詳情 Sheet 狀態 (共用於搜尋結果和地圖點擊)
    @State private var selectedToiletForDetail: ToiletInfo? = nil
    @State private var toiletDetailDetent: PresentationDetent = .medium
    @State private var selectedLocationForDetail: ToiletLocation? = nil
    @State private var locationDetailDetent: PresentationDetent = .medium
    
    // 設定相關狀態
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !searchText.isEmpty {
                    // --- 搜尋結果模式 ---
                    Group {
                        if isSearching {
                            VStack {
                                Spacer()
                                ProgressView(LocalizedStrings.loadingToilets.localized) // 復用載入字串
                                    .font(.subheadlineRounded())
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else if searchResults.isEmpty {
                            VStack {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .font(.customRounded(50))
                                    .foregroundColor(.gray)
                                Text(LocalizedStrings.noToiletsFound.localized)
                                    .font(.headlineRounded())
                                    .padding(.top)
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(searchResults, id: \.id) { location in
                                    Button(action: {
                                        // 收起鍵盤
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        presentLocationDetail(location)
                                    }) {
                                        LocationRowView(location: location, distance: calculateDistanceForLocation(location))
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(selectedDetent == .height(200)) // 最小高度時禁用滾動
                        }
                    }
                    .transition(.opacity)
                } else {
                    // --- 預設首頁模式 ---
                    if !cachedNearbyLocationsWithDistance.isEmpty {
                        // 顯示最近 3 個廁所的預覽
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                // 標題（可點擊）
                                Button(action: {
                                    selectedDetent = .medium
                                    DispatchQueue.main.async {
                                        showNearbyList = true
                                    }
                                }) {
                                    HStack(spacing: 0) {
                                        HStack(spacing: 6) {
                                            Text("附近")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(.primary)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // 半透明灰色容器列表
                                VStack(spacing: 0) {
                                    ForEach(Array(cachedNearbyLocationsWithDistance.prefix(3).enumerated()), id: \.element.0.id) { index, locationWithDistance in
                                        Button(action: {
                                            presentLocationDetail(locationWithDistance.0)
                                        }) {
                                            HStack(spacing: 14) {
                                                // 左邊的地點圖示
                                                Image(systemName: locationWithDistance.0.hasMultipleFloors ? "building.2.fill" : "toilet")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(locationWithDistance.0.hasMultipleFloors ? .orange : .blue)
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 7)
                                                            .fill((locationWithDistance.0.hasMultipleFloors ? Color.orange : Color.blue).opacity(0.2))
                                                            .frame(width: 34, height: 34)
                                                    )
                                                
                                                // 中間的資訊
                                                VStack(alignment: .leading, spacing: 3) {
                                                    // 地點名稱
                                                    Text(locationWithDistance.0.name)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    
                                                    // 評分（只顯示實心星星，不顯示空星星）
                                                    if getStarCount(for: locationWithDistance.0) > 0 {
                                                        HStack(spacing: 1.5) {
                                                            ForEach(0..<getStarCount(for: locationWithDistance.0), id: \.self) { _ in
                                                                Image(systemName: "star.fill")
                                                                    .font(.system(size: 10, weight: .medium))
                                                                    .foregroundColor(.yellow)
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                // 右邊的距離和箭頭
                                                HStack(spacing: 6) {
                                                    // 距離
                                                    Text(formatDistance(locationWithDistance.1))
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(getDistanceBackgroundColor(for: locationWithDistance.1))
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 7)
                                                                .fill(getDistanceBackgroundColor(for: locationWithDistance.1).opacity(0.2))
                                                        )
                                                    
                                                    // 箭頭
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 16)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        // 分隔線（除了最後一個）
                                        if index < min(2, cachedNearbyLocationsWithDistance.count - 1) {
                                            Divider()
                                                .padding(.leading, 72)
                                        }
                                    }
                                }
                                .background(Color.black.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 20)
                                    
                                // 原生廣告獨立區塊
                                    if !premiumManager.isPremium {
                                        AdMobNativeCard()
                                            .environmentObject(premiumManager)
                                        .padding(.top, 16) // 與上方列表保持距離
                                    }
                                
                                // 最近瀏覽區塊（始終顯示）
                                RecentlyViewedSection(
                                    locations: recentlyViewedLocations,
                                    onLocationTap: presentLocationDetail,
                                    getStarCount: getStarCount
                                )
                                
                                Spacer(minLength: 20) // 底部留白
                            }
                        }
                        .scrollDisabled(selectedDetent == .height(200)) // 最小高度時禁用滾動
                        .scrollIndicators(.hidden)
                        .transition(.opacity)
                    } else {
                        // 無資料時顯示佔位符，保持佈局一致
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                // 標題（與有資料時一致）
                                HStack(spacing: 0) {
                                    HStack(spacing: 6) {
                                        Text("附近")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.primary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                                
                                // 佔位符卡片（skeleton）
                                VStack(spacing: 0) {
                                    ForEach(0..<3, id: \.self) { index in
                                        HStack(spacing: 14) {
                                            // 佔位符圖示
                                            RoundedRectangle(cornerRadius: 7)
                                                .fill(Color.gray.opacity(0.1))
                                                .frame(width: 34, height: 34)
                                            
                                            // 佔位符文字
                                            VStack(alignment: .leading, spacing: 6) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 120, height: 14)
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.05))
                                                    .frame(width: 60, height: 10)
                                            }
                                            
                                            Spacer()
                                            
                                            // 佔位符距離
                                            RoundedRectangle(cornerRadius: 7)
                                                .fill(Color.gray.opacity(0.05))
                                                .frame(width: 50, height: 24)
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 16)
                                        
                                        if index < 2 {
                                            Divider()
                                                .padding(.leading, 72)
                                        }
                                    }
                                }
                                .background(Color.black.opacity(0.03)) // 與一般列表背景一致
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 20)
                                
                                // 原生廣告區塊
                                AdMobNativeCard()
                                    .environmentObject(premiumManager)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                
                                // 最近瀏覽區塊（始終顯示）
                                RecentlyViewedSection(
                                    locations: recentlyViewedLocations,
                                    onLocationTap: presentLocationDetail,
                                    getStarCount: getStarCount
                                )
                                
                                Spacer(minLength: 20)
                            }
                        }
                        .scrollDisabled(selectedDetent == .height(200))
                        .scrollIndicators(.hidden)
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty) // 監聽切換模式
            .animation(.easeInOut(duration: 0.2), value: isSearching)      // 監聽搜尋狀態
            .animation(.easeInOut(duration: 0.2), value: cachedNearbyLocationsWithDistance.isEmpty) // 監聽資料載入
            .background(Color.clear)
            .navigationTitle(searchText.isEmpty ? LocalizedStrings.appTitle.localized : "搜尋結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleSettingsTap) {
                        Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "尋找廁所")
        // 使用 task(id:) 實作 debounce
        .task(id: searchText) {
            guard !searchText.isEmpty else {
                withAnimation {
                    searchResults = []
                    isSearching = false
                }
                return
            }
            
            // 延遲 0.5 秒 (Debounce)
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return // 如果 task 被取消 (使用者繼續打字)，就直接返回
            }
            
            withAnimation {
                isSearching = true
            }
            
            // 在背景執行搜尋
            let query = searchText
            let results = await performSearchAsync(query: query)
            
            await MainActor.run {
                withAnimation {
                    self.searchResults = results
                    self.isSearching = false
                }
                
                // 如果有搜尋結果，更新地圖上的點
                if !results.isEmpty {
                    self.mapLocations = results
                    self.mapToilets = results.flatMap { $0.allToilets }
                }
            }
        }
        .onAppear {
            // 如果權限已授權，主動觸發一次定位
            if locationManager.authorizationStatus == .authorizedWhenInUse || 
               locationManager.authorizationStatus == .authorizedAlways {
                locationManager.getCurrentLocation()
            }
            preloadNearbyToilets()
            loadRecentlyViewed()
        }
        .onChange(of: locationManager.location) { _ in
            preloadNearbyToilets()
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            // 如果獲得授權，確保開始定位
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if locationManager.location == nil {
                    locationManager.getCurrentLocation()
                }
                preloadNearbyToilets()
            }
        }
        // 附近列表 Sheet
        .sheet(isPresented: $showNearbyList) {
            NearbyListView(
                locationManager: locationManager,
                toiletDataManager: toiletDataManager,
                mapToilets: $mapToilets,
                mapLocations: $mapLocations,
                selectedToiletFromMap: $selectedToiletFromMap,
                selectedLocationFromMap: $selectedLocationFromMap,
                rootDetent: $selectedDetent,
                parentDetent: $nearbyListDetent,
                preloadedNearbyLocations: cachedNearbyLocations,
                preloadedNearbyLocationsWithDistance: cachedNearbyLocationsWithDistance
            )
            .environmentObject(premiumManager)
            .presentationDetents([.height(200), .medium, .large], selection: $nearbyListDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationDragIndicator(.hidden)
            .presentationCompactAdaptation(.sheet)
            .presentationContentInteraction(.scrolls)
            .presentationBackground {
                if #available(iOS 26.0, *) {
                    Color.white.opacity(0.2)
                } else {
                    ZStack {
                        Color.clear
                            .background(.ultraThinMaterial)
                        Color.white.opacity(0.8)
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        // 設定 Sheet
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(premiumManager)
                .interactiveDismissDisabled(true)
        }
        // 廁所詳情 Sheet
        .sheet(item: $selectedToiletForDetail) { toilet in
            ToiletDetailView(toilet: toilet, toiletDetailDetent: $toiletDetailDetent)
                .presentationDetents([.height(200), .medium, .large], selection: $toiletDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground {
                    if #available(iOS 26.0, *) {
                        Color.white.opacity(0.2)
                    } else {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            Color.white.opacity(0.8)
                        }
                    }
                }
                .onAppear {
                    toiletDetailDetent = .medium
                }
        }
        // 地點詳情 Sheet
        .sheet(item: $selectedLocationForDetail) { location in
            LocationDetailView(location: location, locationDetailDetent: $locationDetailDetent)
                .presentationDetents([.height(200), .medium, .large], selection: $locationDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground {
                    if #available(iOS 26.0, *) {
                        Color.white.opacity(0.2)
                    } else {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            Color.white.opacity(0.8)
                        }
                    }
                }
                .interactiveDismissDisabled()
                .onAppear {
                    locationDetailDetent = .medium
                    // 記錄到最近瀏覽
                    addToRecentlyViewed(location)
                }
        }
        // 監聽地圖點擊事件 (為了能在這裡處理 sheet)
        .onChange(of: selectedToiletFromMap) { newToilet in
            if let toilet = newToilet {
                presentToiletDetail(toilet)
                // 延遲清除以確保 sheet 能夠正確觸發
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedToiletFromMap = nil
                }
            }
        }
        .onChange(of: selectedLocationFromMap) { newLocation in
            if let location = newLocation {
                presentLocationDetail(location)
                // 延遲清除以確保 sheet 能夠正確觸發
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedLocationFromMap = nil
                }
            }
        }
    }
    
    // 處理設定按鈕點擊
    private func handleSettingsTap() {
        showingSettings = true
    }
    
    // 非同步搜尋邏輯
    private func performSearchAsync(query: String) async -> [ToiletLocation] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let results = self.toiletDataManager.searchLocations(query: query)
                
                let sortedResults: [ToiletLocation]
                if self.locationManager.location != nil {
                    sortedResults = results.sorted { first, second in
                        let firstDistance = self.calculateDistanceForLocation(first)
                        let secondDistance = self.calculateDistanceForLocation(second)
                        return firstDistance < secondDistance
                    }
                } else {
                    sortedResults = results
                }
                
                continuation.resume(returning: sortedResults)
            }
        }
    }
    
    // 計算地點的距離
    private func calculateDistanceForLocation(_ location: ToiletLocation) -> Int {
        guard let userLocation = locationManager.location else {
            return 999999
        }
        
        guard let firstToilet = location.allToilets.first else {
            return 999999
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: firstToilet)
    }
    
    // 預先載入附近廁所數據
    private func preloadNearbyToilets() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        
        guard let userLocation = locationManager.location else {
            return
        }
        
        // 在後台線程執行計算
        DispatchQueue.global(qos: .userInitiated).async {
            let locationsWithDistance = toiletDataManager.findNearbyLocationsWithDistance(userLocation: userLocation, radius: 1000)
            let locations = locationsWithDistance.map { $0.0 }
            
            // 回到主線程更新緩存
            DispatchQueue.main.async {
                self.cachedNearbyLocationsWithDistance = locationsWithDistance
                self.cachedNearbyLocations = locations
            }
        }
    }
    
    // MARK: - Sheet Presentation Helpers
    private func presentLocationDetail(_ location: ToiletLocation) {
        // 這裡不需要改變 rootDetent，保持現狀即可，或者根據需要調整
        selectedDetent = .medium 
        locationDetailDetent = .medium
        selectedLocationForDetail = nil
        DispatchQueue.main.async {
            selectedLocationForDetail = location
        }
    }
    
    private func presentToiletDetail(_ toilet: ToiletInfo) {
        selectedDetent = .medium
        toiletDetailDetent = .medium
        selectedToiletForDetail = nil
        DispatchQueue.main.async {
            selectedToiletForDetail = toilet
        }
    }
    
    // MARK: - 輔助函數
    
    // 計算星級評分（最多3顆星）
    private func getStarCount(for location: ToiletLocation) -> Int {
        let allGrades = location.allToilets.map { $0.grade }
        let highestGrade = allGrades.max { grade1, grade2 in
            getGradeValue(grade1) < getGradeValue(grade2)
        } ?? "普通級"
        
        return min(getGradeValue(highestGrade), 3)
    }
    
    // 將等級轉換為數字（最多3顆星）
    private func getGradeValue(_ grade: String) -> Int {
        switch grade {
        case "特優級": return 3
        case "優級": return 2
        case "良級": return 1
        case "普通級": return 1
        case "待改善": return 1
        default: return 1
        }
    }
    
    // 格式化距離顯示
    private func formatDistance(_ distance: Int) -> String {
        if distance >= 1000 {
            let kilometers = Double(distance) / 1000.0
            if kilometers == Double(Int(kilometers)) {
                return "\(Int(kilometers))km"
            } else {
                return String(format: "%.1fkm", kilometers)
            }
        } else {
            return "\(distance)m"
        }
    }
    
    // 根據距離獲取背景顏色
    private func getDistanceBackgroundColor(for distance: Int) -> Color {
        switch distance {
        case 0..<200: return .green
        case 200..<500: return .orange
        case 500..<1000: return .red
        default: return .gray
        }
    }
    
    // MARK: - 最近瀏覽管理
    
    // 添加到最近瀏覽
    private func addToRecentlyViewed(_ location: ToiletLocation) {
        // 移除已存在的相同地點（去重）
        recentlyViewedLocations.removeAll { $0.name == location.name && $0.address == location.address }
        
        // 插入到最前面
        recentlyViewedLocations.insert(location, at: 0)
        
        // 限制最多保存 3 個
        if recentlyViewedLocations.count > 3 {
            recentlyViewedLocations = Array(recentlyViewedLocations.prefix(3))
        }
        
        // 保存到 UserDefaults
        saveRecentlyViewed()
    }
    
    // 保存最近瀏覽到 UserDefaults
    private func saveRecentlyViewed() {
        // 保存地點的唯一標識（使用 name + address 組合）
        let locationKeys = recentlyViewedLocations.map { "\($0.name)|\($0.address)" }
        UserDefaults.standard.set(locationKeys, forKey: "recentlyViewedLocationKeys")
    }
    
    // 從 UserDefaults 讀取最近瀏覽
    private func loadRecentlyViewed() {
        guard let locationKeys = UserDefaults.standard.array(forKey: "recentlyViewedLocationKeys") as? [String] else {
            return
        }
        
        // 從 toiletDataManager 中找出對應的地點
        var loadedLocations: [ToiletLocation] = []
        for key in locationKeys {
            let components = key.components(separatedBy: "|")
            guard components.count == 2 else { continue }
            let name = components[0]
            let address = components[1]
            
            if let location = toiletDataManager.locations.first(where: { $0.name == name && $0.address == address }) {
                loadedLocations.append(location)
            }
        }
        
        recentlyViewedLocations = loadedLocations
    }
}

// 附近列表視圖
struct NearbyListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var toiletDataManager: ToiletDataManager // 接收共享的數據管理器
    @Binding var mapToilets: [ToiletInfo]
    @Binding var mapLocations: [ToiletLocation]
    @Binding var selectedToiletFromMap: ToiletInfo?
    @Binding var selectedLocationFromMap: ToiletLocation?
    @Binding var rootDetent: PresentationDetent
    @Binding var parentDetent: PresentationDetent
    
    // 接收預先載入的數據
    let preloadedNearbyLocations: [ToiletLocation]
    let preloadedNearbyLocationsWithDistance: [(ToiletLocation, Int)]
    
    @State private var nearbyLocations: [ToiletLocation] = []
    @State private var nearbyLocationsWithDistance: [(ToiletLocation, Int)] = []
    @State private var isCalculating: Bool = false // 新增：正在計算距離的狀態
    @State private var sortOption: NearbySortOption = .distance
    @State private var showFilterSheet: Bool = false
    @State private var filterOptions = NearbyFilterOptions()
    @State private var selectedToiletForDetail: ToiletInfo? = nil
    @State private var toiletDetailDetent: PresentationDetent = .medium
    @State private var selectedLocationForDetail: ToiletLocation? = nil
    @State private var locationDetailDetent: PresentationDetent = .medium // 補上遺漏的變數
    // 智慧篩選狀態
    @State private var selectedFilterTag: String? = nil
    
    // 智慧篩選標籤定義
    private let filterTags: [(name: String, icon: String, keywords: [String])] = [
        ("車站", "tram.fill", ["車站", "捷運", "MRT", "火車", "高鐵", "客運", "轉運"]),
        ("百貨公司", "bag.fill", ["百貨", "商場", "購物中心", "MALL"]),
        ("餐廳", "fork.knife", ["餐廳", "麥當勞", "肯德基", "星巴克", "cafe", "咖啡"]),
        ("加油站", "fuelpump.fill", ["加油站", "中油"]),
        ("公園", "tree.fill", ["公園", "Park"]),
        ("市場", "cart.fill", ["市場", "夜市", "Market"]),
        ("圖書館", "book.fill", ["圖書館"]),
        ("運動中心", "figure.run", ["運動中心", "體育館", "球場"]),
        ("停車場", "parkingsign", ["停車場"])
    ]
    
    private var filteredAndSortedLocations: [(ToiletLocation, Int)] {
        // 1. 先進行快速篩選（標籤）
        var filtered = nearbyLocationsWithDistance
        
        if let tag = selectedFilterTag, 
           let filterInfo = filterTags.first(where: { $0.name == tag }) {
            let keywords = filterInfo.keywords
            filtered = filtered.filter { (location, _) in
                let name = location.name.lowercased()
                let type = location.placeType.lowercased()
                return keywords.contains { keyword in 
                    name.contains(keyword.lowercased()) || type.contains(keyword.lowercased())
                }
            }
        }
        
        // 2. 再進行進階篩選（距離、星級等）
        filtered = filtered.filter { locationWithDistance in
            let location = locationWithDistance.0
            let distance = locationWithDistance.1
            let stars = starCount(for: location)
            return filterOptions.matches(location: location, distance: distance, starCount: stars)
        }
        
        // 3. 最後排序
        switch sortOption {
        case .distance:
            return filtered.sorted { $0.1 < $1.1 }
        case .rating:
            return filtered.sorted {
                let lhsStars = starCount(for: $0.0)
                let rhsStars = starCount(for: $1.0)
                return lhsStars == rhsStars ? $0.1 < $1.1 : lhsStars > rhsStars
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContentView
                .navigationTitle("附近一公里")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        trailingToolbarItems
                    }
                }
        }
        // 以下是 NavigationStack 的 modifiers
        .onChange(of: locationManager.location) { _ in
            updateNearbyToilets()
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if locationManager.location == nil {
                    locationManager.getCurrentLocation()
                }
                updateNearbyToilets()
            } else if status == .denied || status == .restricted {
                nearbyLocations = []
                nearbyLocationsWithDistance = []
            }
        }
        .onChange(of: selectedToiletFromMap) { newToilet in
            if let toilet = newToilet {
                presentToiletDetail(toilet)
                selectedToiletFromMap = nil
            }
        }
        .onChange(of: selectedLocationFromMap) { newLocation in
            if let location = newLocation {
                presentLocationDetail(location)
                selectedLocationFromMap = nil
            }
        }
        .onAppear {
            onAppearAction()
        }
        .sheet(isPresented: $showFilterSheet) {
            NearbyFilterSheet(filterOptions: $filterOptions)
                .presentationDetents([.height(460)])
                .presentationDragIndicator(.hidden)
                .presentationBackground {
                    if #available(iOS 26.0, *) {
                        Color.white.opacity(0.5)
                    } else {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            Color.white.opacity(0.8)
                        }
                    }
                }
        }
        .sheet(item: $selectedToiletForDetail) { toilet in
            ToiletDetailView(toilet: toilet, toiletDetailDetent: $toiletDetailDetent)
                .presentationDetents([.height(200), .medium, .large], selection: $toiletDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground {
                    if #available(iOS 26.0, *) {
                        Color.white.opacity(0.2)
                    } else {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            Color.white.opacity(0.8)
                        }
                    }
                }
                .onAppear {
                    // 確保打開時是 medium 高度
                    toiletDetailDetent = .medium
                }
        }
        .sheet(item: $selectedLocationForDetail) { location in
            LocationDetailView(location: location, locationDetailDetent: $locationDetailDetent)
                .presentationDetents([.height(200), .medium, .large], selection: $locationDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground {
                    if #available(iOS 26.0, *) {
                        Color.white.opacity(0.2)
                    } else {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            Color.white.opacity(0.8)
                        }
                    }
                }
                .interactiveDismissDisabled()
                .onAppear {
                    // 確保打開時是 medium 高度
                    locationDetailDetent = .medium
                    // 記錄到最近瀏覽
                    addToRecentlyViewedInNearbyList(location)
                }
        }
    }
    
    // MARK: - Subviews & Helpers
    
    @ViewBuilder
    private var mainContentView: some View {
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            permissionDeniedView
        } else if toiletDataManager.isLoading || isCalculating {
            loadingView
        } else if locationManager.isLocating {
            locatingView
        } else if nearbyLocations.isEmpty {
            if locationManager.location == nil {
                locatingViewWithRetry
            } else {
                noToiletsFoundView
            }
        } else {
            nearbyListContent
        }
    }
    
    private var permissionDeniedView: some View {
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
    }
    
    private var loadingView: some View {
                        VStack {
                            Spacer()
                            ProgressView(LocalizedStrings.loadingToilets.localized)
                                .font(.subheadlineRounded())
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var locatingView: some View {
                            VStack {
                                Spacer()
                                ProgressView(LocalizedStrings.locating.localized)
                                    .font(.subheadlineRounded())
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var locatingViewWithRetry: some View {
                                    VStack {
                                        Spacer()
                                        ProgressView(LocalizedStrings.locating.localized)
                                            .font(.subheadlineRounded())
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .onAppear {
                                        if !locationManager.isLocating {
                                            locationManager.getCurrentLocation()
                                        }
                                    }
    }
    
    private var noToiletsFoundView: some View {
                                    VStack {
                                        Spacer()
            Image(systemName: "mappin.slash")
                                            .font(.customRounded(50))
                                            .foregroundColor(.gray)
            Text(LocalizedStrings.noToiletsFound.localized)
                                            .font(.headlineRounded())
                                            .padding(.top)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
    
    private var nearbyListContent: some View {
                                let results = filteredAndSortedLocations
                                
        return ZStack(alignment: .top) {
                                if results.isEmpty {
                emptyFilteredResultView
                    .padding(.top, 60) // 避開上方的篩選列
            } else {
                locationListView(results: results)
            }
            
            // 智慧篩選列 - 懸浮在上方
            filterBar
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "全部" 按鈕
                if #available(iOS 26.0, *) {
                    if selectedFilterTag == nil {
                        Button("全部") {
                            selectedFilterTag = nil
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    } else {
                        Button {
                            selectedFilterTag = nil
                        } label: {
                            Text("全部")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.black.opacity(0.05))
                    }
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilterTag = nil
                        }
                    }) {
                        Text("全部")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedFilterTag == nil ? .white : .primary)
                            .background(
                                Group {
                                    if selectedFilterTag == nil {
                                        Color.blue
                                    } else {
                                        ZStack {
                                            Color.white.opacity(0.2)
                                            Rectangle().fill(.ultraThinMaterial).opacity(0.5)
                                        }
                                    }
                                }
                                .clipShape(Capsule())
                            )
                    }
                }
                
                // 各類別標籤
                ForEach(filterTags, id: \.name) { tag in
                    if #available(iOS 26.0, *) {
                        if selectedFilterTag == tag.name {
                            Button(action: {
                                selectedFilterTag = nil
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: tag.icon)
                                        .font(.caption)
                                    Text(tag.name)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.blue)
                        } else {
                            Button {
                                selectedFilterTag = tag.name
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tag.icon)
                                        .font(.caption)
                                        .foregroundColor(.black)
                                    Text(tag.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color.black.opacity(0.05))
                        }
                    } else {
                        Button(action: {
                            if selectedFilterTag == tag.name {
                                selectedFilterTag = nil
                            } else {
                                selectedFilterTag = tag.name
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tag.icon)
                                    .font(.caption)
                                Text(tag.name)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedFilterTag == tag.name ? .white : .primary)
                            .background(
                                Group {
                                    if selectedFilterTag == tag.name {
                                        Color.blue
                                    } else {
                                        ZStack {
                                            Color.white.opacity(0.2)
                                            Rectangle().fill(.ultraThinMaterial).opacity(0.5)
                                        }
                                    }
                                }
                                .clipShape(Capsule())
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.1), lineWidth: selectedFilterTag == tag.name ? 0 : 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private var emptyFilteredResultView: some View {
                                    VStack(spacing: 16) {
                                        Image(systemName: "line.3.horizontal.decrease.circle")
                                            .font(.system(size: 40, weight: .semibold))
                                            .foregroundColor(.gray.opacity(0.7))
            Text(filterOptions.isEmpty && selectedFilterTag == nil ? LocalizedStrings.noToiletsFound.localized : "目前沒有符合條件的結果")
                                            .font(.headlineRounded())
                                            .foregroundColor(.gray)
            if !filterOptions.isEmpty || selectedFilterTag != nil {
                                            Button("清除篩選條件") {
                                                withAnimation {
                                                    filterOptions = NearbyFilterOptions()
                        selectedFilterTag = nil
                                                }
                                            }
                                            .font(.captionRounded(.semibold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.15))
                                            .clipShape(Capsule())
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func locationListView(results: [(ToiletLocation, Int)]) -> some View {
                                    ScrollView(showsIndicators: false) {
                                        LazyVStack(spacing: 0) {
                // 頂部留白，給懸浮篩選列空間
                Color.clear.frame(height: 60)
                
                                            ForEach(Array(results.enumerated()), id: \.element.0.id) { index, locationWithDistance in
                                                Button(action: {
                                                    presentLocationDetail(locationWithDistance.0)
                                                }) {
                                                    LocationRowView(location: locationWithDistance.0, distance: locationWithDistance.1)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                
                                                // 在第 5 個項目（index == 4）後插入廣告
                                                if index == 4 && !premiumManager.isPremium {
                                                    VStack(spacing: 0) {
                                                        Divider()
                                                            .padding(.leading, 20)
                                                        
                            AdMobNativeCard(showBackground: false)
                                                            .environmentObject(premiumManager)
                                                            .padding(.horizontal, 20)
                                                            .padding(.vertical, 16)
                                                        
                                                        Divider()
                                                            .padding(.leading, 20)
                                                    }
                                                }
                                            }
                                        }
                                    }
        .scrollDisabled(parentDetent == .height(200))
                                    .background(Color.clear)
                                    .onAppear {
                                        mapToilets = nearbyLocations.flatMap { $0.allToilets }
                                        mapLocations = nearbyLocations
        }
    }
    
    private var trailingToolbarItems: some View {
                    HStack(spacing: 0) {
                        Button(action: {
                            showFilterSheet = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary.opacity(0.7))
                                    .frame(width: 28, height: 28)
                                
                                if filterOptions.activeCount > 0 {
                                    Text("\(filterOptions.activeCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -6)
                                }
                            }
                        }
                        .accessibilityLabel(filterOptions.isEmpty ? "篩選" : "篩選 \(filterOptions.activeCount) 個條件")
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(width: 1, height: 16)
                            .padding(.horizontal, 6)
                        
                        Menu {
                            ForEach(NearbySortOption.allCases) { option in
                                Button(action: {
                                    sortOption = option
                                }) {
                                    HStack {
                                        Text(option.displayName)
                                        if option == sortOption {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
    
    private func onAppearAction() {
            if locationManager.authorizationStatus == .authorizedWhenInUse || 
               locationManager.authorizationStatus == .authorizedAlways {
                
                if locationManager.location == nil {
                    locationManager.getCurrentLocation()
                }
                
                if preloadedNearbyLocations.isEmpty && locationManager.location != nil {
                    updateNearbyToilets()
                }
            }

            if !preloadedNearbyLocations.isEmpty {
                nearbyLocations = preloadedNearbyLocations
                nearbyLocationsWithDistance = preloadedNearbyLocationsWithDistance
                
                mapToilets = nearbyLocations.flatMap { $0.allToilets }
                mapLocations = nearbyLocations
        }
    }
    
    // MARK: - 最近瀏覽管理（NearbyListView）
    
    // 添加到最近瀏覽（在 NearbyListView 中使用）
    private func addToRecentlyViewedInNearbyList(_ location: ToiletLocation) {
        // 保存地點的唯一標識（使用 name + address 組合）
        var recentKeys = UserDefaults.standard.array(forKey: "recentlyViewedLocationKeys") as? [String] ?? []
        
        let locationKey = "\(location.name)|\(location.address)"
        
        // 移除已存在的相同地點（去重）
        recentKeys.removeAll { $0 == locationKey }
        
        // 插入到最前面
        recentKeys.insert(locationKey, at: 0)
        
        // 限制最多保存 3 個
        if recentKeys.count > 3 {
            recentKeys = Array(recentKeys.prefix(3))
        }
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(recentKeys, forKey: "recentlyViewedLocationKeys")
    }
    
    // 更新附近地點緩存（優化版本，在後台線程執行）
    private func updateNearbyToilets() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            nearbyLocations = []
            nearbyLocationsWithDistance = []
            return
        }
        
        guard let userLocation = locationManager.location else {
            nearbyLocations = []
            nearbyLocationsWithDistance = []
            return
        }
        
        // 開始計算
        isCalculating = true
        
        // 在後台線程執行計算
        DispatchQueue.global(qos: .userInitiated).async {
            let locationsWithDistance = self.toiletDataManager.findNearbyLocationsWithDistance(userLocation: userLocation, radius: 1000)
            let locations = locationsWithDistance.map { $0.0 }
            
            // 回到主線程更新 UI
            DispatchQueue.main.async {
                self.nearbyLocationsWithDistance = locationsWithDistance
                self.nearbyLocations = locations
                
                self.mapToilets = self.nearbyLocations.flatMap { $0.allToilets }
                self.mapLocations = self.nearbyLocations
                
                // 計算完成
                self.isCalculating = false
            }
        }
    }
    
    private func starCount(for location: ToiletLocation) -> Int {
        let grades = location.allToilets.map { $0.grade }
        let highest = grades.max { gradeValue($0) < gradeValue($1) } ?? "普通級"
        return min(gradeValue(highest), 3)
    }
    
    private func gradeValue(_ grade: String) -> Int {
        switch grade {
        case "特優級": return 3
        case "優級": return 2
        case "良級": return 1
        case "普通級": return 1
        case "待改善": return 1
        default: return 1
        }
    }
    
    // 計算地點的距離
    private func getRealDistanceForLocation(_ location: ToiletLocation) -> Int {
        guard let userLocation = locationManager.location else {
            return 999999
        }
        
        guard let firstToilet = location.allToilets.first else {
            return 999999
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: firstToilet)
    }
    
    // MARK: - Sheet Presentation Helpers
    private func presentLocationDetail(_ location: ToiletLocation) {
        rootDetent = .medium
        parentDetent = .medium
        locationDetailDetent = .medium
        selectedLocationForDetail = nil
        DispatchQueue.main.async {
            selectedLocationForDetail = location
        }
    }
    
    private func presentToiletDetail(_ toilet: ToiletInfo) {
        rootDetent = .medium
        parentDetent = .medium
        toiletDetailDetent = .medium
        selectedToiletForDetail = nil
        DispatchQueue.main.async {
            selectedToiletForDetail = toilet
        }
    }
}

// MARK: - Sort & Filter Support

private enum NearbySortOption: String, CaseIterable, Identifiable {
    case distance
    case rating
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .distance: return "距離最短"
        case .rating: return "星級最高"
        }
    }
    
    var shortLabel: String {
        switch self {
        case .distance: return "距離"
        case .rating: return "星級"
        }
    }
}

private struct NearbyFilterOptions: Equatable {
    var maxDistance: Int? = nil
    var starRatings: Set<Int> = []
    var toiletTypes: Set<ToiletTypeFilter> = []
    
    var isEmpty: Bool {
        maxDistance == nil && starRatings.isEmpty && toiletTypes.isEmpty
    }
    
    var activeCount: Int {
        (maxDistance == nil ? 0 : 1) + starRatings.count + toiletTypes.count
    }
    
    mutating func clear() {
        self = NearbyFilterOptions()
    }
    
    func matches(location: ToiletLocation, distance: Int, starCount: Int) -> Bool {
        let distanceMatch = maxDistance == nil || distance <= maxDistance!
        let starMatch = starRatings.isEmpty || starRatings.contains(starCount)
        let typeMatch = toiletTypes.isEmpty || toiletTypes.contains(where: { $0.matches(location: location) })
        return distanceMatch && starMatch && typeMatch
    }
}

private enum StarRatingFilter: Int, CaseIterable, Identifiable {
    case one = 1
    case two
    case three
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .one: return "★☆☆"
        case .two: return "★★☆"
        case .three: return "★★★"
        }
    }
}

private enum ToiletTypeFilter: String, CaseIterable, Identifiable {
    case male
    case female
    case family
    case accessible
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .male: return "男廁"
        case .female: return "女廁"
        case .family: return "親子"
        case .accessible: return "無障礙"
        }
    }
    
    private var keywords: [String] {
        switch self {
        case .male: return ["男廁所", "男廁"]
        case .female: return ["女廁所", "女廁"]
        case .family: return ["親子廁所", "親子"]
        case .accessible: return ["無障礙廁所", "無障礙"]
        }
    }
    
    func matches(location: ToiletLocation) -> Bool {
        let types = location.allToilets.map { $0.type }
        return types.contains(where: { type in
            keywords.contains(where: { keyword in type.contains(keyword) })
        })
    }
}

// MARK: - Filter Sheet

private struct NearbyFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterOptions: NearbyFilterOptions
    @State private var draft: NearbyFilterOptions
    @State private var distanceStopIndex: Double
    
    private let distanceStops: [Int] = [0, 200, 500, 1000]
    
    init(filterOptions: Binding<NearbyFilterOptions>) {
        _filterOptions = filterOptions
        let initialDraft = filterOptions.wrappedValue
        _draft = State(initialValue: initialDraft)
        let initialDistance = initialDraft.maxDistance ?? 0
        let index = Double(distanceStops.firstIndex(of: initialDistance) ?? 0)
        _distanceStopIndex = State(initialValue: index)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    FilterSection(title: "距離範圍", trailingText: distanceLabelText) {
                        VStack(alignment: .leading, spacing: 12) {
                            Slider(
                                value: $distanceStopIndex,
                                in: 0...Double(distanceStops.count - 1),
                                step: 1
                            )
                            .tint(.blue)
                            .onChange(of: distanceStopIndex) { _ in
                                updateDraftDistance()
                            }
                            
                            HStack {
                                ForEach(distanceStops, id: \.self) { stop in
                                    Text(stop == 0 ? "不限" : "\(stop)m")
                                        .font(.caption2)
                                        .foregroundColor(selectedDistance == stop ? .blue : .secondary)
                                    if stop != distanceStops.last {
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    FilterSection(title: "星級") {
                        chipGrid(
                            columns: 3,
                            items: StarRatingFilter.allCases,
                            isSelected: { draft.starRatings.contains($0.rawValue) },
                            action: { rating in
                                if draft.starRatings.contains(rating.rawValue) {
                                    draft.starRatings.remove(rating.rawValue)
                                } else {
                                    draft.starRatings.insert(rating.rawValue)
                                }
                            },
                            label: { $0.label }
                        )
                    }
                    
                    FilterSection(title: "廁所類型") {
                        chipGrid(
                            columns: 2,
                            items: ToiletTypeFilter.allCases,
                            isSelected: { draft.toiletTypes.contains($0) },
                            action: { type in
                                if draft.toiletTypes.contains(type) {
                                    draft.toiletTypes.remove(type)
                                } else {
                                    draft.toiletTypes.insert(type)
                                }
                            },
                            label: { $0.displayName }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("篩選")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("清除") {
                        draft.clear()
                        distanceStopIndex = 0
                        updateDraftDistance()
                    }
                    .disabled(draft.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if #available(iOS 26.0, *) {
                    Button("套用") {
                        filterOptions = draft
                        dismiss()
                    }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    } else {
                        Button("套用") {
                            filterOptions = draft
                            dismiss()
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            draft = filterOptions
            distanceStopIndex = Double(distanceStops.firstIndex(of: filterOptions.maxDistance ?? 0) ?? 0)
            updateDraftDistance()
        }
    }
    
    @ViewBuilder
    private func chipGrid<T: Identifiable>(columns: Int, items: [T], isSelected: @escaping (T) -> Bool, action: @escaping (T) -> Void, label: @escaping (T) -> String) -> some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
        LazyVGrid(columns: gridItems, spacing: 12) {
            ForEach(items) { item in
                FilterChip(label: label(item), isSelected: isSelected(item))
                    .onTapGesture {
                        action(item)
                    }
            }
        }
    }
    
    private var selectedDistance: Int {
        let index = min(max(Int(distanceStopIndex.rounded()), 0), distanceStops.count - 1)
        return distanceStops[index]
    }
    
    private var distanceLabelText: String {
        let value = selectedDistance
        return value == 0 ? "不限距離" : "小於 \(value) 公尺內"
    }
    
    private func updateDraftDistance() {
        let value = selectedDistance
        draft.maxDistance = value == 0 ? nil : value
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    var trailingText: String? = nil
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headlineRounded(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                if let trailingText {
                    Text(trailingText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    
    var body: some View {
        Text(label)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 最近瀏覽區塊組件
struct RecentlyViewedSection: View {
    let locations: [ToiletLocation]
    let onLocationTap: (ToiletLocation) -> Void
    let getStarCount: (ToiletLocation) -> Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 標題
            HStack(spacing: 0) {
                Text("最近瀏覽")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // 內容區域
            if locations.isEmpty {
                // 沒有記錄時顯示提示
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("沒有最近瀏覽")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            } else {
                // 半透明灰色容器列表（跟附近一樣的樣式）
                VStack(spacing: 0) {
                    ForEach(Array(locations.prefix(3).enumerated()), id: \.element.id) { index, location in
                        Button(action: {
                            onLocationTap(location)
                        }) {
                            HStack(spacing: 14) {
                                // 左邊的地點圖示
                                Image(systemName: location.hasMultipleFloors ? "building.2.fill" : "toilet")
                                    .font(.system(size: 16))
                                    .foregroundColor(location.hasMultipleFloors ? .orange : .blue)
                                    .frame(width: 20, height: 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill((location.hasMultipleFloors ? Color.orange : Color.blue).opacity(0.2))
                                            .frame(width: 34, height: 34)
                                    )
                                
                                // 中間的資訊
                                VStack(alignment: .leading, spacing: 3) {
                                    // 地點名稱
                                    Text(location.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    // 評分（只顯示實心星星，不顯示空星星）
                                    if getStarCount(location) > 0 {
                                        HStack(spacing: 1.5) {
                                            ForEach(0..<getStarCount(location), id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // 右邊只有箭頭（不顯示距離）
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 分隔線（除了最後一個）
                        if index < min(2, locations.count - 1) {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    HomeSheetView(
        selectedDetent: .constant(.medium),
        locationManager: LocationManager(),
        toiletDataManager: ToiletDataManager(),
        mapToilets: .constant([]),
        mapLocations: .constant([]),
        selectedToiletFromMap: .constant(nil),
        selectedLocationFromMap: .constant(nil)
    )
    .environmentObject(PremiumManager())
}
