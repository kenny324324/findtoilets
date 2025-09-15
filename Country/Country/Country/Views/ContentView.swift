//
//  ContentView.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @State private var sheetPresented: Bool = true // 控制 sheet 是否顯示
    @State private var selectedDetent: PresentationDetent = .medium // 預設 detent 尺寸
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654), // 台北101
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // 地圖縮放範圍（調整為台灣區域）
    )
    
    // 縮放限制常數
    private let minSpan: CLLocationDegrees = 0.001  // 最小範圍：約 100m
    private let maxSpan: CLLocationDegrees = 0.1    // 最大範圍：約 10km
    @State private var mapType: MKMapType = .standard // 地圖類型（默認為向量地圖）
    @StateObject private var locationManager = LocationManager()
    @State private var mapToilets: [ToiletInfo] = [] // 要在地圖上顯示的公廁
    @StateObject private var toiletDataManager = ToiletDataManager() // 公廁資料管理器
    @State private var regionUpdateTimer: Timer? = nil // 防抖動計時器
    @State private var shouldUpdateMapRegion: Bool = true // 控制是否應該更新地圖區域
    @State private var hasAutoLocated: Bool = false // 控制是否已經自動定位過
    @State private var isUserInteracting: Bool = false // 用戶是否正在手動操作地圖
    @State private var shouldJumpToLocation: Bool = false // 控制是否應該跳回位置
    @State private var isLoadingToilets: Bool = false // 是否正在載入公廁資料
    @State private var selectedToilet: ToiletInfo? = nil // 選中的公廁

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 地圖視圖
            MapView(region: $region, mapType: mapType, userLocation: locationManager.location, toilets: mapToilets, shouldJumpToLocation: $shouldJumpToLocation, onRegionChanged: { newRegion in
                // 地圖區域變化時動態載入公廁（但不會觸發跳回）
                updateToiletsForMapRegion(newRegion)
            }, shouldUpdateRegion: shouldUpdateMapRegion, onToiletSelected: { toilet in
                // 當公廁被選中時，傳遞給 CountryView 處理
                selectedToilet = toilet
            })
                .edgesIgnoringSafeArea(.all)

            // 左側按鈕組
            VStack(alignment: .leading, spacing: 12) {
                // 定位按鈕
                Button(action: {
                    // 直接處理定位，不依賴 onChange 監聽器
                    handleLocationButtonTap()
                }) {
                    Group {
                        if locationManager.isLocating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.customRounded(15, weight: .heavy))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(locationManager.isLocating ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
                }
                .disabled(locationManager.isLocating)
                
                // 切換地圖樣式的按鈕
                VStack(spacing: 0) {
                    Button(action: {
                        print("切換到標準地圖")
                        mapType = .standard // 切換到標準地圖
                    }) {
                        Image(systemName: "map") // 地圖圖示
                            .font(.customRounded(15, weight: .heavy)) // 改為較小的字體大小
                            .frame(width: 40, height: 40) // 調整按鈕大小
                            .background(Color.clear)
                            .clipShape(Circle())
                            .foregroundColor(mapType == .standard ? .black : .gray)
                    }

                    Button(action: {
                        print("切換到衛星地圖")
                        mapType = .satellite // 切換到衛星地圖
                    }) {
                        Image(systemName: "cloud") // 衛星圖圖示
                            .font(.customRounded(15, weight: .heavy)) // 改為較小的字體大小
                            .frame(width: 40, height: 40) // 調整按鈕大小
                            .background(mapType == .satellite ? Color.gray.opacity(0) : Color.clear)
                            .clipShape(Circle())
                            .foregroundColor(mapType == .satellite ? .black : .gray)
                    }
                }
            }
            .background(Color.white.opacity(0.9))
            .cornerRadius(15)
            .padding(.leading, 12) // 距離左邊的間距
            .padding(.top, 12) // 距離頂部的間距
            
            // 載入指示器
            if isLoadingToilets {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("載入公廁資料中...")
                                .font(.captionRounded())
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .shadow(radius: 2)
                        .padding(.trailing, 12)
                        .padding(.bottom, 100) // 避免被 sheet 遮住
                    }
                }
            }
        }
        .onAppear {
            // 強制設定為直向
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            
            // 打開 app 後自動定位到目前位置（只執行一次）
            if !hasAutoLocated {
                hasAutoLocated = true
                autoLocateCurrentPosition()
            }
        }
        .sheet(isPresented: $sheetPresented) {
            CountryView(sheetPresented: $sheetPresented, selectedDetent: $selectedDetent, locationManager: locationManager, mapToilets: $mapToilets, selectedToiletFromMap: $selectedToilet)
                .presentationDetents([.height(200), .medium, .fraction(0.95)], selection: $selectedDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(15)
                .interactiveDismissDisabled()
        }
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
        
        // 顯示載入指示器
        isLoadingToilets = true
        
        // 限制縮放範圍
        let clampedRegion = clampRegion(region)
        
        // 設置新的計時器，延遲 0.3 秒後執行更新（減少延遲提升響應速度）
        regionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                // 使用異步載入提升性能
                DispatchQueue.global(qos: .userInitiated).async {
                    // 使用 ToiletDataManager 根據地圖區域載入公廁（使用限制後的區域）
                    let newToilets = self.toiletDataManager.findToiletsInRegion(clampedRegion, maxCount: 500)
                    
                    DispatchQueue.main.async {
                        // 更新地圖標記
                        self.mapToilets = newToilets
                        
                        // 隱藏載入指示器
                        self.isLoadingToilets = false
                        
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

#Preview {
    ContentView()
}
