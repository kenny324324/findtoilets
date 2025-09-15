//
//  ToiletDetailView.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import MapKit
import CoreLocation

struct ToiletDetailView: View {
    let toilet: ToiletInfo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var walkingTimeMinutes: Int = 0
    @State private var isCalculatingDistance: Bool = false
    @State private var showingMapOptions = false
    
    // 格式化步行時間顯示
    private func formatWalkingTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分鐘"
        } else if minutes < 1440 { // 少於24小時
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)小時"
            } else {
                return "\(hours)小時\(remainingMinutes)分鐘"
            }
        } else { // 超過24小時
            let days = minutes / 1440
            let remainingHours = (minutes % 1440) / 60
            let remainingMinutes = minutes % 60
            
            if remainingHours == 0 && remainingMinutes == 0 {
                return "\(days)天"
            } else if remainingMinutes == 0 {
                return "\(days)天\(remainingHours)小時"
            } else {
                return "\(days)天\(remainingHours)小時\(remainingMinutes)分鐘"
            }
        }
    }
    
    // 計算走路時間（使用更準確的算法）
    private func calculateWalkingTime() {
        guard let userLocation = locationManager.location else {
            // 如果沒有用戶位置，嘗試獲取位置
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.getCurrentLocation()
            }
            return
        }
        
        let toiletLocation = CLLocation(
            latitude: toilet.latitudeDouble,
            longitude: toilet.longitudeDouble
        )
        
        let straightDistance = userLocation.distance(from: toiletLocation) // 直線距離（公尺）
        
        // 考慮實際道路情況的修正係數
        // 直線距離通常比實際道路距離短 1.2-1.5 倍
        let roadDistanceMultiplier: Double = 1.3
        let estimatedRoadDistance = straightDistance * roadDistanceMultiplier
        
        // 根據距離調整步行速度
        let walkingSpeedKmh: Double
        if estimatedRoadDistance < 200 {
            walkingSpeedKmh = 4.0 // 短距離較慢（可能有很多轉彎）
        } else if estimatedRoadDistance < 500 {
            walkingSpeedKmh = 4.5 // 中短距離
        } else if estimatedRoadDistance < 1000 {
            walkingSpeedKmh = 5.0 // 中等距離
        } else {
            walkingSpeedKmh = 5.5 // 長距離較快（主要道路）
        }
        
        let walkingSpeedMs: Double = walkingSpeedKmh * 1000 / 3600 // 轉換為 m/s
        let walkingTimeSeconds = estimatedRoadDistance / walkingSpeedMs
        
        // 添加額外的時間緩衝（紅綠燈、過馬路等）
        let bufferTime: Double = max(1, estimatedRoadDistance / 1000) // 每公里加1分鐘緩衝
        let totalTimeSeconds = walkingTimeSeconds + (bufferTime * 60)
        
        let walkingTimeMinutes = Int(ceil(totalTimeSeconds / 60)) // 向上取整到分鐘
        
        DispatchQueue.main.async {
            self.walkingTimeMinutes = max(1, walkingTimeMinutes) // 最少1分鐘
            self.isCalculatingDistance = false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 導航欄
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                        .clipShape(Capsule())
                        .symbolRenderingMode(.hierarchical)
                }
                
                Spacer()
                
                Button(action: shareToilet) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                        .clipShape(Capsule())
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // 主要內容
            ScrollView {
                VStack(spacing: 0) {
                    // 主要標題區域 (類似 Apple Maps 的 Place Card)
                    VStack(spacing: 16) {
                        // 標題區域
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(getCleanToiletName(toilet.name))
                                    .font(.titleRounded(.bold))
                                    .multilineTextAlignment(.leading)
                                
                                // 評級標籤
                                HStack(spacing: 4) {
                                    ForEach(0..<getStarCount(from: toilet.grade), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                            .font(.captionRounded())
                                        .foregroundColor(.yellow)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            Spacer()
                        }
                        
                        // 導航按鈕 - 顯示走路時間
                        Button(action: { showingMapOptions = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                    .font(.subheadlineRounded())
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                
                                if isCalculatingDistance {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else if walkingTimeMinutes > 0 {
                                    Text(formatWalkingTime(walkingTimeMinutes))
                                        .font(.captionRounded(.semibold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("計算中...")
                                        .font(.captionRounded(.semibold))
                                    .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // 詳細資訊標題
                    HStack {
                        Text("詳細資訊")
                            .font(.title3Rounded(.semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // 資訊列表區域
                    VStack(spacing: 0) {
                        // 地址資訊
                        HStack(alignment: .center) {
                            Text("地址")
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Spacer()
                            
                            Text(toilet.address)
                                .font(.bodyRounded())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                                // 廁所類型
                        HStack(alignment: .center) {
                                        Text("類型")
                                .font(.calloutRounded())
                                            .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                                    
                                    Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: toilet.typeIcon)
                                    .font(.customRounded(16))
                                    .foregroundColor(toilet.typeColor)
                                
                                Text(toilet.type)
                                    .font(.bodyRounded())
                                    .foregroundColor(toilet.typeColor)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(toilet.typeColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                                
                                Divider()
                            .padding(.horizontal, 20)
                                
                                // 尿布台
                        HStack(alignment: .center) {
                                        Text("尿布台")
                                .font(.calloutRounded())
                                            .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                                    
                                    Spacer()
                            
                            Image(systemName: toilet.hasDiaperStation ? "checkmark.circle.fill" : "x.circle.fill")
                                .font(.title2Rounded())
                                .foregroundColor(toilet.hasDiaperStation ? .green : .red)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 場所類型
                        HStack(alignment: .center) {
                            Text("場所類型")
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Spacer()
                            
                                        Text(toilet.type2)
                                .font(.bodyRounded())
                                            .foregroundColor(.primary)
                                    }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                                
                                Divider()
                            .padding(.horizontal, 20)
                                
                                // 管理單位
                        HStack(alignment: .center) {
                                        Text("管理單位")
                                .font(.calloutRounded())
                                            .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                                    
                                    Spacer()
                            
                            Text(toilet.administration)
                                .font(.bodyRounded())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear {
            // 頁面載入時開始計算走路時間
            isCalculatingDistance = true
            calculateWalkingTime()
        }
        .onChange(of: locationManager.location) { _ in
            // 當位置更新時重新計算走路時間
            if isCalculatingDistance {
                calculateWalkingTime()
            }
        }
        .alert("選擇地圖應用程式", isPresented: $showingMapOptions) {
            Button("Apple Maps") {
                openInAppleMaps()
            }
            Button("Google Maps") {
                openInGoogleMaps()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("請選擇要使用的地圖應用程式進行導航")
        }
    }
    
    // 開啟 Apple Maps 導航
    private func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(
            latitude: toilet.latitudeDouble,
            longitude: toilet.longitudeDouble
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = toilet.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // 開啟 Google Maps 導航
    private func openInGoogleMaps() {
        let coordinate = CLLocationCoordinate2D(
            latitude: toilet.latitudeDouble,
            longitude: toilet.longitudeDouble
        )
        
        // 檢查是否已安裝 Google Maps
        if let url = URL(string: "comgooglemaps://") {
            if UIApplication.shared.canOpenURL(url) {
                // 使用 Google Maps 應用程式
                let googleMapsURL = "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving"
                if let url = URL(string: googleMapsURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                // 如果沒有安裝 Google Maps，使用網頁版
                let webURL = "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)&travelmode=driving"
                if let url = URL(string: webURL) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    // 分享公廁資訊
    private func shareToilet() {
        let text = "\(toilet.name)\n\(toilet.address)\n評級：\(toilet.grade)\n類型：\(toilet.type)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    // 清理廁所名稱，移除類型後綴
    private func getCleanToiletName(_ name: String) -> String {
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
    
    // 根據評級文字返回星星數量
    private func getStarCount(from grade: String) -> Int {
        switch grade {
        case "特優級":
            return 5
        case "優級":
            return 4
        case "良級":
            return 3
        case "普通級":
            return 2
        case "待改善":
            return 1
        default:
            return 3 // 預設值
        }
    }
}

#Preview {
    ToiletDetailView(toilet: ToiletInfo(
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
    ))
}
