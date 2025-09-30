//
//  LocationDetailView.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct LocationDetailView: View {
    let location: ToiletLocation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var walkingTimeMinutes: Int = 0
    @State private var isCalculatingDistance: Bool = false
    @State private var showingMapOptions = false
    @State private var selectedFloor: String = "" // 選中的樓層
    @State private var selectedToilet: ToiletInfo? = nil // 選中的廁所
    
    // 初始化選中的樓層
    init(location: ToiletLocation) {
        self.location = location
        if location.hasMultipleFloors {
            // 預設選擇最低樓層（floorOrder 最小的）
            self._selectedFloor = State(initialValue: location.toiletsByFloor.sorted(by: { $0.floorOrder < $1.floorOrder }).first?.floorName ?? "")
        }
    }
    
    // 格式化步行時間顯示
    private func formatWalkingTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return LocalizedStrings.minutes.localized(minutes)
        } else if minutes < 1440 { // 少於24小時
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return LocalizedStrings.hours.localized(hours)
            } else {
                return LocalizedStrings.hoursMinutes.localized(hours, remainingMinutes)
            }
        } else { // 超過24小時
            let days = minutes / 1440
            let remainingHours = (minutes % 1440) / 60
            let remainingMinutes = minutes % 60
            
            if remainingHours == 0 && remainingMinutes == 0 {
                return LocalizedStrings.days.localized(days)
            } else if remainingMinutes == 0 {
                return LocalizedStrings.daysHours.localized(days, remainingHours)
            } else {
                return LocalizedStrings.daysHoursMinutes.localized(days, remainingHours, remainingMinutes)
            }
        }
    }
    
    // 計算走路時間
    private func calculateWalkingTime() {
        guard let userLocation = locationManager.location else {
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.getCurrentLocation()
            }
            return
        }
        
        let locationCoordinate = CLLocation(
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        let straightDistance = userLocation.distance(from: locationCoordinate)
        let roadDistanceMultiplier: Double = 1.3
        let estimatedRoadDistance = straightDistance * roadDistanceMultiplier
        
        let walkingSpeedKmh: Double
        if estimatedRoadDistance < 200 {
            walkingSpeedKmh = 4.0
        } else if estimatedRoadDistance < 500 {
            walkingSpeedKmh = 4.5
        } else if estimatedRoadDistance < 1000 {
            walkingSpeedKmh = 5.0
        } else {
            walkingSpeedKmh = 5.5
        }
        
        let walkingSpeedMs: Double = walkingSpeedKmh * 1000 / 3600
        let walkingTimeSeconds = estimatedRoadDistance / walkingSpeedMs
        let bufferTime: Double = max(1, estimatedRoadDistance / 1000)
        let totalTimeSeconds = walkingTimeSeconds + (bufferTime * 60)
        let walkingTimeMinutes = Int(ceil(totalTimeSeconds / 60))
        
        DispatchQueue.main.async {
            self.walkingTimeMinutes = max(1, walkingTimeMinutes)
            self.isCalculatingDistance = false
        }
    }
    
    // 獲取當前樓層的廁所
    private var currentFloorToilets: [ToiletInfo] {
        if location.hasMultipleFloors && !selectedFloor.isEmpty {
            return location.toiletsByFloor.first { $0.floorName == selectedFloor }?.toilets ?? []
        }
        return location.allToilets
    }
    
    // 獲取當前樓層的可用廁所類型
    private var availableTypes: [String] {
        Array(Set(currentFloorToilets.map { $0.type })).sorted()
    }
    
    // 根據評級文字返回星星數量（與 CountryView 完全一致）
    private func getStarCount(for floorName: String) -> Int {
        // 如果沒有多樓層或樓層名稱為空，使用所有廁所
        let floorToilets: [ToiletInfo]
        if location.hasMultipleFloors && !floorName.isEmpty {
            floorToilets = location.toiletsByFloor.first { $0.floorName == floorName }?.toilets ?? []
        } else {
            floorToilets = location.allToilets
        }
        
        guard !floorToilets.isEmpty else { return 1 } // 預設值
        
        // 取該層廁所中最高的評級
        let allGrades = floorToilets.map { $0.grade }
        let highestGrade = allGrades.max { grade1, grade2 in
            getGradeValue(grade1) < getGradeValue(grade2)
        } ?? LocalizedStrings.gradeNormal.localized
        
        // 限制最多3顆星
        return min(getGradeValue(highestGrade), 3)
    }
    
    // 將評級轉換為數值用於比較（與 CountryView 完全一致）
    private func getGradeValue(_ grade: String) -> Int {
        // 先檢查原始中文評級
        switch grade {
        case "特優級", LocalizedStrings.gradeExcellent.localized: return 3
        case "優級", LocalizedStrings.gradeGood.localized: return 2
        case "良級", LocalizedStrings.gradeFair.localized: return 1
        case "普通級", LocalizedStrings.gradeNormal.localized: return 1
        case "待改善", LocalizedStrings.gradePoor.localized: return 1
        default: return 1
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
                
                Button(action: shareLocation) {
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
                    // 地點概覽區域
                    VStack(spacing: 16) {
                        // 標題區域
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(location.name)
                                    .font(.titleRounded(.bold))
                                    .multilineTextAlignment(.leading)
                                
                                // 星級評分和地點資訊標籤
                                HStack(spacing: 8) {
                                    // 星級評分（只顯示實心星星，不顯示空星星）
                                    HStack(spacing: 2) {
                                        ForEach(0..<getStarCount(for: selectedFloor), id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.captionRounded())
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                    .frame(height: 24)
                                    .padding(.horizontal, 8)
                                    .background(Color.yellow.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    // 廁所數量標籤
                                    HStack(spacing: 4) {
                                        Image(systemName: "toilet")
                                            .font(.captionRounded())
                                        Text(LocalizedStrings.toiletCount.localized(location.totalToiletCount))
                                            .font(.captionRounded(.semibold))
                                    }
                                    .frame(height: 24)
                                    .padding(.horizontal, 8)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    // 多樓層標籤
                                    if location.hasMultipleFloors {
                                        HStack(spacing: 4) {
                                            Image(systemName: "building.2.fill")
                                                .font(.captionRounded())
                                            Text(LocalizedStrings.floorCount.localized(location.floorCount))
                                                .font(.captionRounded(.semibold))
                                        }
                                        .frame(height: 24)
                                        .padding(.horizontal, 8)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // 導航按鈕
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
                                    Text(LocalizedStrings.calculating.localized)
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
                    
                    // 多樓層選擇器
                    if location.hasMultipleFloors {
                        VStack(spacing: 12) {
                            HStack {
                                Text(LocalizedStrings.selectFloor.localized)
                                    .font(.headlineRounded(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(.leading, 20)
                                Spacer()
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(location.toiletsByFloor.sorted(by: { $0.floorOrder < $1.floorOrder }), id: \.floorName) { floorInfo in
                                        Button(action: {
                                            selectedFloor = floorInfo.floorName
                                            selectedToilet = nil
                                        }) {
                                            VStack(spacing: 4) {
                                                Text(floorInfo.floorName)
                                                    .font(.headlineRounded(.semibold))
                                                    .foregroundColor(selectedFloor == floorInfo.floorName ? .blue : .primary)
                                                
                                                Text(LocalizedStrings.toiletCount.localized(floorInfo.toiletCount))
                                                    .font(.captionRounded())
                                                    .foregroundColor(selectedFloor == floorInfo.floorName ? .blue.opacity(0.8) : .secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(selectedFloor == floorInfo.floorName ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // 廁所類型展示
                    VStack(spacing: 12) {
                        HStack {
                            Text(LocalizedStrings.availableTypes.localized)
                                .font(.title3Rounded(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        if availableTypes.count > 4 {
                            // 超過4個類型時使用滾動
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(availableTypes, id: \.self) { type in
                                        HStack(spacing: 6) {
                                            Image(systemName: getIconName(for: type))
                                                .font(.customRounded(16))
                                                .foregroundColor(getColor(for: type))
                                            
                                            Text(getLocalizedTypeName(for: type))
                                                .font(.customRounded(16))
                                                .foregroundColor(.primary)
                                            
                                            Text("\(currentFloorToilets.filter { $0.type == type }.count)")
                                                .font(.customRounded(12))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(getColor(for: type).opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(.horizontal, 0)
                            }
                        } else {
                            // 4個或以下時使用橫向排列
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(availableTypes, id: \.self) { type in
                                        HStack(spacing: 6) {
                                            Image(systemName: getIconName(for: type))
                                                .font(.customRounded(16))
                                                .foregroundColor(getColor(for: type))
                                            
                                            Text(getLocalizedTypeName(for: type))
                                                .font(.customRounded(16))
                                                .foregroundColor(.primary)
                                            
                                            Text("\(currentFloorToilets.filter { $0.type == type }.count)")
                                                .font(.customRounded(12))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(getColor(for: type).opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(.horizontal, 0)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // 詳細資訊標題
                    HStack {
                        Text(LocalizedStrings.details.localized)
                            .font(.title3Rounded(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 0)
                    
                    // 資訊列表區域
                    VStack(spacing: 0) {
                        // 地址資訊
                        HStack(alignment: .center) {
                            Text(LocalizedStrings.address.localized)
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, alignment: .leading)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(location.address)
                                .font(.bodyRounded())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        
                        // 尿布台
                        HStack(alignment: .center) {
                            Text(LocalizedStrings.diaperStation.localized)
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, alignment: .leading)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: location.hasDiaperStation ? "checkmark.circle.fill" : "x.circle.fill")
                                .font(.title2Rounded())
                                .foregroundColor(location.hasDiaperStation ? .green : .red)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 場所類型
                        HStack(alignment: .center) {
                            Text(LocalizedStrings.venueType.localized)
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, alignment: .leading)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(location.placeType)
                                .font(.bodyRounded())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 管理單位
                        HStack(alignment: .center) {
                            Text(LocalizedStrings.administration.localized)
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, alignment: .leading)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(location.administration)
                                .font(.bodyRounded())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear {
            isCalculatingDistance = true
            calculateWalkingTime()
        }
        .onChange(of: locationManager.location) { _ in
            if isCalculatingDistance {
                calculateWalkingTime()
            }
        }
        .alert(LocalizedStrings.mapAppSelection.localized, isPresented: $showingMapOptions) {
            Button("Apple Maps") {
                openInAppleMaps()
            }
            Button("Google Maps") {
                openInGoogleMaps()
            }
            Button(LocalizedStrings.cancel.localized, role: .cancel) { }
        } message: {
            Text(LocalizedStrings.mapSelectionDescription.localized)
        }
    }
    
    // 根據廁所類型獲取圖示名稱
    private func getIconName(for type: String) -> String {
        // 先檢查原始中文類型
        switch type {
        case "女廁所", LocalizedStrings.toiletTypeFemale.localized:
            return "figure.stand"
        case "男廁所", LocalizedStrings.toiletTypeMale.localized:
            return "figure.stand"
        case "親子廁所", LocalizedStrings.toiletTypeFamily.localized:
            return "figure.and.child.holdinghands"
        case "無障礙廁所", LocalizedStrings.toiletTypeAccessible.localized:
            return "figure.roll"
        case "混合廁所", LocalizedStrings.toiletTypeMixed.localized:
            return "toilet"
        case "性別友善廁所", LocalizedStrings.toiletTypeGenderFriendly.localized:
            return "person.2.fill"
        default:
            return "figure.stand"
        }
    }
    
    // 根據廁所類型獲取顏色
    private func getColor(for type: String) -> Color {
        // 先檢查原始中文類型
        switch type {
        case "女廁所", LocalizedStrings.toiletTypeFemale.localized:
            return .red
        case "男廁所", LocalizedStrings.toiletTypeMale.localized:
            return .blue
        case "親子廁所", LocalizedStrings.toiletTypeFamily.localized:
            return .green
        case "無障礙廁所", LocalizedStrings.toiletTypeAccessible.localized:
            return .gray
        case "混合廁所", LocalizedStrings.toiletTypeMixed.localized:
            return .orange
        case "性別友善廁所", LocalizedStrings.toiletTypeGenderFriendly.localized:
            return .purple
        default:
            return .blue
        }
    }
    
    // 將原始中文類型轉換為本地化文字
    private func getLocalizedTypeName(for type: String) -> String {
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
            return type // 如果沒有對應的本地化，返回原始文字
        }
    }
    
    // 開啟 Apple Maps 導航
    private func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // 開啟 Google Maps 導航
    private func openInGoogleMaps() {
        let coordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        if let url = URL(string: "comgooglemaps://") {
            if UIApplication.shared.canOpenURL(url) {
                let googleMapsURL = "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving"
                if let url = URL(string: googleMapsURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                let webURL = "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)&travelmode=driving"
                if let url = URL(string: webURL) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    // 分享地點資訊
    private func shareLocation() {
        let text = "\(location.name)\n\(location.address)\n共\(location.totalToiletCount)間廁所\n可用類型：\(availableTypes.joined(separator: "、"))"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

#Preview {
    LocationDetailView(location: ToiletLocation(
        name: "測試地點",
        address: "測試地址",
        latitude: 25.0330,
        longitude: 121.5654,
        administration: "測試管理單位",
        toiletsByFloor: [
            FloorInfo(
                floorName: "1F",
                floorOrder: 1,
                toilets: [
                    ToiletInfo(
                        county: "10001",
                        city: "1000101",
                        village: "信義區",
                        number: "TEST001",
                        name: "測試地點1F-男廁",
                        address: "測試地址",
                        administration: "測試管理單位",
                        latitude: "25.0330",
                        longitude: "121.5654",
                        grade: "特優級",
                        type2: "商業營業場所",
                        type: "男廁所",
                        exec: "測試",
                        diaper: "1"
                    )
                ]
            )
        ]
    ))
}
