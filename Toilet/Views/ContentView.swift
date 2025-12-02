//
//  ContentView.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    // 接收 PremiumManager
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var sheetPresented: Bool = false // 預設為 false，讓 sheet 延後彈出
    @State private var selectedDetent: PresentationDetent = .medium // 預設 detent 尺寸
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654), // 台北101
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // 地圖縮放範圍（調整為台灣區域）
    )
    
    // 縮放限制常數
    private let minSpan: CLLocationDegrees = 0.001  // 最小範圍：約 100m
    private let maxSpan: CLLocationDegrees = 5.0    // 最大範圍：約 550km，允許查看全台
    @State private var mapType: MKMapType = .standard // 地圖類型（默認為向量地圖）
    @StateObject private var locationManager = LocationManager()
    @State private var mapToilets: [ToiletInfo] = [] // 要在地圖上顯示的公廁
    @State private var mapLocations: [ToiletLocation] = [] // 要在地圖上顯示的地點
    @StateObject private var toiletDataManager = ToiletDataManager() // 公廁資料管理器
    @State private var regionUpdateTimer: Timer? = nil // 防抖動計時器
    @State private var shouldUpdateMapRegion: Bool = true // 控制是否應該更新地圖區域
    @State private var hasAutoLocated: Bool = false // 控制是否已經自動定位過
    @State private var isUserInteracting: Bool = false // 用戶是否正在手動操作地圖
    @State private var shouldJumpToLocation: Bool = false // 控制是否應該跳回位置
    @State private var selectedToilet: ToiletInfo? = nil // 選中的公廁
    @State private var selectedLocation: ToiletLocation? = nil // 選中的地點
    @State private var shouldEnableClustering: Bool = true // 根據地圖縮放動態啟用標記聚合
    @State private var isFirstLaunch: Bool = true // 控制初始啟動狀態

    var body: some View {
        ZStack {
            if isFirstLaunch || toiletDataManager.isLoading {
                LoadingView()
                    .transition(.opacity)
                    .zIndex(10) // 確保在最上層
            } else {
                NavigationStack {
                    ZStack(alignment: .topLeading) {
                    // 地圖視圖
                    MapView(region: $region, mapType: mapType, userLocation: locationManager.location, toilets: mapToilets, locations: mapLocations, shouldJumpToLocation: $shouldJumpToLocation, onRegionChanged: { newRegion in
                        // 地圖區域變化時動態載入公廁（但不會觸發跳回）
                        updateToiletsForMapRegion(newRegion)
                    }, shouldUpdateRegion: shouldUpdateMapRegion, onToiletSelected: { toilet in
                        // 當公廁被選中時，傳遞給 ToiletView 處理
                        selectedToilet = toilet
                    }, onLocationSelected: { location in
                        // 當地點被選中時，直接選擇地點
                        selectedLocation = location
                        selectedToilet = nil // 清空廁所選擇
                    }, shouldEnableClustering: shouldEnableClustering)
                        .edgesIgnoringSafeArea(.all)
        
                    // 頂部漸層模糊
                    VStack(spacing: 0) {
                        navigationBarGradientOverlay
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .ignoresSafeArea(edges: .top)
                        Spacer()
                    }
                    .allowsHitTesting(false)
        
                    // 左側按鈕組
                    VStack(alignment: .leading, spacing: 12) {
                        // 測試按鈕已隱藏
                        // Button(action: {
                        //     toiletDataManager.quickTest()
                        // }) {
                        //     Image(systemName: "testtube.2")
                        //         .font(.title2)
                        //         .foregroundColor(.white)
                        //         .frame(width: 44, height: 44)
                        //         .background(Color.blue)
                        //         .clipShape(Circle())
                        //         .shadow(radius: 4)
                        // }
                        
                        // 定位按鈕
                        Button(action: {
                            // 直接處理定位，不依賴 onChange 監聽器
                            handleLocationButtonTap()
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.customRounded(15, weight: .heavy))
                                .frame(width: 40, height: 40)
                        }
                        
                        // 地圖樣式切換（暫時不限制 Premium）
                        Button(action: {
                            mapType = (mapType == .standard) ? .satellite : .standard
                        }) {
                            let isSatellite = mapType == .satellite
                            Image(systemName: isSatellite ? "globe.asia.australia.fill" : "map.fill")
                            .font(.customRounded(16, weight: .heavy))
                                .frame(width: 40, height: 40)
                                .foregroundColor(.black)
                        }
                        
                    }
                    .background(mapControlsGlassBackground)
                    .cornerRadius(15)
                    .padding(.leading, 12) // 距離左邊的間距
                    .padding(.top, 40) // 距離頂部的間距
                    
                }
                .onAppear {
                    // 強制設定為直向
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                    
                    // 初始載入時根據目前地圖範圍更新廁所和聚類狀態
                    updateToiletsForMapRegion(region)
                    
                    // 打開 app 後自動定位到目前位置（只執行一次）
                    if !hasAutoLocated {
                        hasAutoLocated = true
                        autoLocateCurrentPosition()
                    }
                }
                .sheet(isPresented: $sheetPresented) {
                    HomeSheetView(
                        selectedDetent: $selectedDetent,
                        locationManager: locationManager,
                        toiletDataManager: toiletDataManager, // 傳遞已載入資料的 manager
                        mapToilets: $mapToilets,
                        mapLocations: $mapLocations,
                        selectedToiletFromMap: $selectedToilet,
                        selectedLocationFromMap: $selectedLocation
                    )
                    .environmentObject(premiumManager)
                    .presentationDetents([.height(200), .medium, .large], selection: $selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.hidden)
                    .presentationCompactAdaptation(.sheet)
                    .presentationContentInteraction(.scrolls)
                    .presentationBackground(Color.white.opacity(0.2))
                    .interactiveDismissDisabled()
                }
                }
                .zIndex(1)
            }
        }
        .onAppear {
            // 啟動時開始載入資料
            toiletDataManager.loadToiletData()
            
            // 稍微延遲一點再切換狀態，確保 LoadingView 有時間顯示
            // 或者依賴 toiletDataManager.isLoading 的變化
            // 這裡我們確保至少在開始載入後，isFirstLaunch 才變 false
            // 但更好的方式是讓 toiletDataManager 載入完成後通知，不過這裡我們配合 isLoading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFirstLaunch = false
            }
        }
        .onChange(of: toiletDataManager.isLoading) { isLoading in
            // 當載入完成後，延遲彈出 Sheet
            if !isLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring()) {
                        sheetPresented = true
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: toiletDataManager.isLoading)
        .animation(.easeInOut(duration: 0.5), value: isFirstLaunch)
    }
    
    // 自動定位到目前位置（app 啟動時）
    private func autoLocateCurrentPosition() {
        // 檢查權限狀態
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // 首次使用，請求權限
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            // 權限被拒絕，不進行定位
            break
        case .authorizedWhenInUse, .authorizedAlways:
            // 有權限，使用快速定位
            locationManager.getQuickLocation()
            
            // 監聽位置更新並更新地圖（僅在 app 啟動時）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let location = self.locationManager.location {
                    self.jumpToUserLocation()
                } else {
                    // 如果1秒後還沒有位置，再等2秒
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if let location = self.locationManager.location {
                            self.jumpToUserLocation()
                        }
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    // 處理定位按鈕點擊
    private func handleLocationButtonTap() {
        // 檢查權限狀態
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // 首次使用，請求權限
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            // 權限被拒絕，顯示提示
            break
        case .authorizedWhenInUse, .authorizedAlways:
            // 有權限，使用快速定位
            locationManager.getQuickLocation()
            
            // 監聽位置更新，只在定位按鈕觸發時跳回
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let location = self.locationManager.location {
                    self.jumpToUserLocation()
                }
            }
        @unknown default:
            break
        }
    }
    
    
    // 跳回用戶位置（僅在 app 啟動和按定位按鈕時使用）
    private func jumpToUserLocation() {
        guard let userLocation = locationManager.location else { 
            return 
        }
        
        // 確保坐標有效
        let validCoordinate = CLLocationCoordinate2D(
            latitude: max(-90, min(90, userLocation.coordinate.latitude)),
            longitude: max(-180, min(180, userLocation.coordinate.longitude))
        )
        
        // 更新 region 用於顯示（限制縮放範圍）
        let clampedSpan = MKCoordinateSpan(
            latitudeDelta: max(minSpan, min(maxSpan, 0.01)),
            longitudeDelta: max(minSpan, min(maxSpan, 0.01))
        )
        
        region = MKCoordinateRegion(center: validCoordinate, span: clampedSpan)
        
        // 觸發跳回動畫
        shouldJumpToLocation = true
    }
    
    // 限制縮放範圍的輔助方法
    private func clampRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let clampedSpan = MKCoordinateSpan(
            latitudeDelta: max(minSpan, min(maxSpan, region.span.latitudeDelta)),
            longitudeDelta: max(minSpan, min(maxSpan, region.span.longitudeDelta))
        )
        
        return MKCoordinateRegion(center: region.center, span: clampedSpan)
    }
    
    // 根據地圖區域動態載入公廁（優化版本，含縮放限制）
    private func updateToiletsForMapRegion(_ region: MKCoordinateRegion) {
        // 標記用戶正在手動操作地圖
        isUserInteracting = true
        
        // 取消之前的計時器
        regionUpdateTimer?.invalidate()
        
        
        // 限制縮放範圍
        let clampedRegion = clampRegion(region)
        
        // 設置新的計時器，延遲 0.3 秒後執行更新（減少延遲提升響應速度）
        regionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                // 使用異步載入提升性能
                DispatchQueue.global(qos: .userInitiated).async {
                    // 使用 ToiletDataManager 根據地圖區域載入公廁（使用限制後的區域）
                    let newToilets = self.toiletDataManager.findToiletsInRegion(clampedRegion, maxCount: 500)
                    let toiletIds = Set(newToilets.map { $0.id })
                    let newLocations = self.toiletDataManager.locations.filter { location in
                        location.allToilets.contains { toiletIds.contains($0.id) }
                    }
                    
                    DispatchQueue.main.async {
                        // 永遠顯示地點標記，不展開成個別廁所
                        // 只有在詳細頁面才顯示該地點的所有廁所
                        self.mapToilets = []
                        self.mapLocations = newLocations
                        
                        // 根據地圖縮放級別動態啟用聚合
                        // latitudeDelta 越大表示地圖範圍越大（越縮小）
                        // 當 latitudeDelta > 0.05 時（約5公里範圍），啟用聚合以減少標記數量
                        // 當 latitudeDelta <= 0.05 時（較近距離），禁用聚合以顯示詳細位置
                        // 這樣放大後，同一地點多間廁所會顯示為 🏢 圖標而不是聚類數字
                        let shouldCluster = clampedRegion.span.latitudeDelta > 0.05
                        self.shouldEnableClustering = shouldCluster
                        
                        // 延遲重置手動操作標記
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.isUserInteracting = false
                        }
                    }
                }
            }
        }
    }
    
}

private extension ContentView {
    @ViewBuilder
    var mapControlsGlassBackground: some View {
        let baseShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        
        if #available(iOS 26.0, *) {
            baseShape
                .fill(Color.clear)
                .glassEffect(.regular.interactive())
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .blendMode(.overlay)
                )
        } else {
            baseShape
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .blendMode(.overlay)
                )
        }
    }
    
    var navigationBarGradientOverlay: some View {
        Rectangle()
            .fill(Color.clear)
            .background(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

#Preview {
    ContentView()
        .environmentObject(PremiumManager())
}
