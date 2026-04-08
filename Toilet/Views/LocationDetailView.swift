//
//  LocationDetailView.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

// 回報資料結構
struct LocationReport: Identifiable, Codable {
    let id: UUID
    let locationId: UUID // 關聯到地點
    let type: ReportType
    let rating: Int // 1-5 星
    let content: String? // 文字評論（可選）
    let tags: [String] // 新增：問題標籤
    let ratingDetails: [String: Int] // 新增：詳細評分 (1=好, 0=壞)
    let time: Date
    let userId: String // 匿名 ID
    var userNickname: String // 匿名暱稱 (現在可以變動)
    var userGender: UserGender? // 使用者性別 (從 Profile 撈取)
    
    // 新增：地點資訊備份
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    
    init(locationId: UUID, type: ReportType, rating: Int, content: String? = nil, userNickname: String, tags: [String] = [], ratingDetails: [String: Int] = [:], locationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = UUID()
        self.locationId = locationId
        self.type = type
        self.rating = rating
        self.content = content
        self.tags = tags
        self.ratingDetails = ratingDetails
        self.time = Date()
        self.userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.userNickname = userNickname
        self.userGender = nil
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
    }
    
    // 完整初始化
    init(id: UUID = UUID(), locationId: UUID = UUID(), type: ReportType, rating: Int, content: String? = nil, time: Date, userNickname: String, userId: String = "dummy_user", tags: [String] = [], ratingDetails: [String: Int] = [:], userGender: UserGender? = nil, locationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.locationId = locationId
        self.type = type
        self.rating = rating
        self.content = content
        self.tags = tags
        self.ratingDetails = ratingDetails
        self.time = time
        self.userId = userId
        self.userNickname = userNickname
        self.userGender = userGender
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
    }
    
    enum ReportType: String, Codable, CaseIterable {
        case clean = "乾淨舒適"
        case normal = "普通尚可"
        case dirty = "髒亂異味"
        case noPaper = "缺衛生紙"
        case maintenance = "維修中"
        case crowded = "排隊人多"
        
        var icon: String {
            switch self {
            case .clean: return "sparkles"
            case .normal: return "hand.thumbsup"
            case .dirty: return "exclamationmark.triangle"
            case .noPaper: return "scroll"
            case .maintenance: return "hammer"
            case .crowded: return "person.3.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .clean: return .green
            case .normal: return .blue
            case .dirty: return .brown
            case .noPaper: return .orange
            case .maintenance: return .red
            case .crowded: return .purple
            }
        }
        
        var defaultRating: Int {
            switch self {
            case .clean: return 5
            case .normal: return 3
            case .dirty: return 1
            case .noPaper: return 2
            case .maintenance: return 1
            case .crowded: return 2
            }
        }
    }
}

// 評論管理器 (串接 CloudKit)
class ReviewManager: ObservableObject {
    @Published var reviews: [UUID: [LocationReport]] = [:] // locationId -> reports
    @Published var isLoading = false
    @Published var existingReview: LocationReport? = nil // 使用者的現有評論
    @Published var errorMessage: String? = nil // 錯誤訊息
    
    func loadReviews(for locationId: UUID) {
        isLoading = true
        CloudKitManager.shared.fetchReviews(for: locationId) { [weak self] downloadedReviews in
            guard let self = self else { return }
            
            // 取得評論後，收集所有 User IDs 並抓取 Profiles
            let userIDs = downloadedReviews.map { $0.userId }
            
            CloudKitManager.shared.fetchUserProfiles(userIDs: userIDs) { profiles in
                DispatchQueue.main.async {
                    // 將 Profile 資訊合併到 Reviews
                    let enrichedReviews = downloadedReviews.map { report -> LocationReport in
                        var newReport = report
                        if let profile = profiles[report.userId] {
                            newReport.userNickname = profile.nickname
                            // 只有當評論沒有性別資訊時，才使用 Profile 的性別
                            if newReport.userGender == nil {
                                newReport.userGender = profile.gender
                            }
                        }
                        return newReport
                    }
                    
                    self.reviews[locationId] = enrichedReviews
                    self.isLoading = false
                }
            }
        }
    }
    
    // 檢查使用者是否已對該地點留過言
    func checkExistingReview(for locationId: UUID, completion: @escaping () -> Void) {
        CloudKitManager.shared.checkExistingReview(for: locationId) { [weak self] existingReport in
            DispatchQueue.main.async {
                self?.existingReview = existingReport
                completion()
            }
        }
    }
    
    func addReview(_ report: LocationReport) {
        // 1. 更新本地快取（如果是更新現有評論，需要移除舊的）
        if reviews[report.locationId] == nil {
            reviews[report.locationId] = []
        }
        
        // 移除舊評論（如果有）
        // 關鍵修正：如果有 existingReview，直接移除它（因為這是從 CloudKit 確認的使用者評論）
        if let existingReview = existingReview,
           let existingIndex = reviews[report.locationId]?.firstIndex(where: { $0.id == existingReview.id }) {
            print("🔄 [ReviewManager] 找到現有評論，移除舊的: \(existingReview.id)")
            reviews[report.locationId]?.remove(at: existingIndex)
        } else {
            // 備用方案：如果沒有 existingReview，用 CloudKit User ID 比對
            if let currentUserID = CloudKitManager.shared.currentUserID?.recordName,
               let existingIndex = reviews[report.locationId]?.firstIndex(where: { $0.userId == currentUserID }) {
                print("🔄 [ReviewManager] 用 UserID 找到現有評論，移除舊的")
                reviews[report.locationId]?.remove(at: existingIndex)
            } else {
                print("➕ [ReviewManager] 沒有找到現有評論，這是新增")
            }
        }
        
        // 插入新評論在最前面
        reviews[report.locationId]?.insert(report, at: 0)
        
        // 更新 existingReview
        existingReview = report
        
        // 2. 背景上傳到 CloudKit
        CloudKitManager.shared.saveReview(report: report) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ [ReviewManager] 評論同步至雲端成功")
                case .failure(let error):
                    print("❌ [ReviewManager] 評論同步失敗: \(error.localizedDescription)")
                    // 將技術錯誤轉換為友善訊息
                    let friendlyMessage: String
                    let errorDescription = error.localizedDescription.lowercased()
                    
                    if errorDescription.contains("network") || errorDescription.contains("internet") {
                        friendlyMessage = "網路連線不穩定，請稍後再試"
                    } else if errorDescription.contains("not authenticated") || errorDescription.contains("icloud") {
                        friendlyMessage = "請確認已登入 iCloud 帳號"
                    } else if errorDescription.contains("permission") || errorDescription.contains("denied") {
                        friendlyMessage = "權限不足，請稍後再試"
                    } else if errorDescription.contains("quota") || errorDescription.contains("limit") {
                        friendlyMessage = "儲存空間已滿，請聯繫客服"
                    } else {
                        friendlyMessage = "評論上傳失敗，請稍後再試"
                    }
                    
                    self?.errorMessage = friendlyMessage
                }
            }
        }
    }
    
    func getReviews(for locationId: UUID) -> [LocationReport] {
        return reviews[locationId] ?? []
    }
}

struct LocationDetailView: View {
    let location: ToiletLocation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var reviewManager = ReviewManager() // 引入評論管理器
    @StateObject private var businessHoursManager = BusinessHoursManager()
    @State private var walkingTimeMinutes: Int = 0
    @State private var isCalculatingDistance: Bool = false
    @State private var showingMapOptions = false
    @State private var selectedFloor: String = "" // 選中的樓層
    @State private var selectedToilet: ToiletInfo? = nil // 選中的廁所
    @Binding var locationDetailDetent: PresentationDetent // 接收 detent binding
    
    // 回報相關 State
    @State private var showingReportSheet = false
    
    // 評論輸入相關 State
    @State private var showingReviewInput = false
    @State private var userNickname: String = UserDefaults.standard.string(forKey: "UserNickname") ?? "熱心路人"
    
    // 初始化選中的樓層
    init(location: ToiletLocation, locationDetailDetent: Binding<PresentationDetent>) {
        self.location = location
        self._locationDetailDetent = locationDetailDetent
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
    
    // 時間顯示輔助
    private func timeAgoDisplay(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
    
    // 獲取當前樓層的區域分組
    private var currentFloorAreas: [(area: String, toilets: [ToiletInfo])] {
        let grouped = Dictionary(grouping: currentFloorToilets) { toilet in
            ToiletLocation.extractAreaName(from: toilet.name)
        }
        
        return grouped.map { (area: $0.key, toilets: $0.value) }
            .sorted { area1, area2 in
                // 空區域排最後
                if area1.area.isEmpty { return false }
                if area2.area.isEmpty { return true }
                return area1.area < area2.area
            }
    }
    
    // 根據評級文字返回星星數量（與 ToiletView 完全一致）
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
    
    // 將評級轉換為數值用於比較（與 ToiletView 完全一致）
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
        NavigationStack {
            ScrollView(showsIndicators: false) {
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
                        
                        // 導航按鈕區域
                        HStack(spacing: 12) {
                            // 導航按鈕
                            if #available(iOS 26.0, *) {
                                Button(action: { showingMapOptions = true }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 16, weight: .semibold))
                                        
                                        if isCalculatingDistance {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else if walkingTimeMinutes > 0 {
                                            Text(formatWalkingTime(walkingTimeMinutes))
                                                .font(.system(size: 12, weight: .semibold))
                                        } else {
                                            Text(LocalizedStrings.calculating.localized)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 0)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(.blue)
                            } else {
                                Button(action: { showingMapOptions = true }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        if isCalculatingDistance {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else if walkingTimeMinutes > 0 {
                                            Text(formatWalkingTime(walkingTimeMinutes))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                        } else {
                                            Text(LocalizedStrings.calculating.localized)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    
                    // 多樓層選擇器 (優化版：膠囊樣式)
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
                                HStack(spacing: 8) { // 減少間距
                                    ForEach(location.toiletsByFloor.sorted(by: { $0.floorOrder < $1.floorOrder }), id: \.floorName) { floorInfo in
                                        Button(action: {
                                            selectedFloor = floorInfo.floorName
                                            selectedToilet = nil
                                        }) {
                                            // 膠囊樣式
                                            Text(floorInfo.floorName)
                                                .font(.subheadlineRounded(.bold))
                                                .foregroundColor(selectedFloor == floorInfo.floorName ? .blue : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8) // 減少垂直 padding
                                                .background(selectedFloor == floorInfo.floorName ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                                .clipShape(Capsule()) // 改為圓形膠囊
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // 廁所類型展示 (優化版：圖示標籤)
                    VStack(spacing: 12) {
                        HStack {
                            Text(LocalizedStrings.availableTypes.localized)
                            .font(.title3Rounded(.semibold))
                            .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20) // 標題補上 padding
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { // 減少間距
                                ForEach(availableTypes, id: \.self) { type in
                                    HStack(spacing: 4) { // 內容更緊湊
                                        Image(systemName: getIconName(for: type))
                                            .font(.customRounded(14))
                                            .foregroundColor(getColor(for: type))
                                        
                                        Text(getLocalizedTypeName(for: type))
                                            .font(.customRounded(14))
                                            .foregroundColor(.primary)
                                        
                                        Text("\(currentFloorToilets.filter { $0.type == type }.count)間") // 改為顯示 "x間"
                                            .font(.customRounded(12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(getColor(for: type).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8)) // 稍微方一點的圓角
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                    // 移除外層的 .padding(.horizontal, 20)
                    
                    // 該樓層區域 (優化版：文字標籤)
                    if currentFloorAreas.count > 1 || (currentFloorAreas.count == 1 && !currentFloorAreas[0].area.isEmpty) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("該樓層區域")
                                    .font(.title3Rounded(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20) // 標題補上 padding
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(currentFloorAreas, id: \.area) { areaGroup in
                                        HStack(spacing: 6) {
                                            Text(areaGroup.area.isEmpty ? "主區" : areaGroup.area)
                                                .font(.subheadlineRounded(.semibold))
                                                .foregroundColor(.primary)
                                            
                                            Text("\(areaGroup.toilets.count)間")
                                                .font(.captionRounded())
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.purple.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 20)
                        // 移除外層的 .padding(.horizontal, 20)
                    }
                    
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

                        // 營業時間
                        HStack(alignment: .center) {
                            Text("營業時間")
                                .font(.calloutRounded())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, alignment: .leading)
                                .lineLimit(1)

                            Spacer()

                            if businessHoursManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let hours = businessHoursManager.businessHours {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(hours.isOpenNow ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(hours.isOpenNow ? "營業中" : "已關閉")
                                        .font(.bodyRounded(.semibold))
                                        .foregroundColor(hours.isOpenNow ? .green : .red)
                                    Text(hours.todayHoursText)
                                        .font(.bodyRounded())
                                        .foregroundColor(.primary)
                                }
                            } else if location.isLikelyOpen24H {
                                Text("可能 24H 開放")
                                    .font(.bodyRounded())
                                    .foregroundColor(.green)
                            } else {
                                Text("可能有營業時間限制")
                                    .font(.bodyRounded())
                                    .foregroundColor(.orange)
                            }
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
                    
                    // --- 社群評論區 (新增) ---
                    CommunityReviewSection(
                        locationName: location.name,
                        reviews: reviewManager.getReviews(for: location.id),
                        hasExistingReview: reviewManager.existingReview != nil,
                        onAddReview: { 
                            reviewManager.checkExistingReview(for: location.id) {
                                showingReviewInput = true
                            }
                        }
                    )
                    .padding(.bottom, 20) // 縮小外部底部間距 (原 40)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(locationDetailDetent == .height(120)) // 最小高度時禁用滾動
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 如果當前是最小高度，返回時調整到中高度
                        if locationDetailDetent == .height(120) {
                            locationDetailDetent = .medium
                        }
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(action: { 
                            // 檢查是否已有評論
                            reviewManager.checkExistingReview(for: location.id) {
                                showingReviewInput = true
                            }
                        }) {
                            Image(systemName: reviewManager.existingReview != nil ? "pencil" : "plus.message.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.orange)
                    } else {
                        Button(action: { 
                            // 檢查是否已有評論
                            reviewManager.checkExistingReview(for: location.id) {
                                showingReviewInput = true
                            }
                        }) {
                            Image(systemName: reviewManager.existingReview != nil ? "pencil" : "plus.message.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            isCalculatingDistance = true
            calculateWalkingTime()
            reviewManager.loadReviews(for: location.id) // 下載該地點的評論
            reviewManager.checkExistingReview(for: location.id) { } // 檢查使用者是否已留言
            businessHoursManager.loadHours(for: location) // 查詢營業時間
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
        // 評論輸入 Sheet
        .sheet(isPresented: $showingReviewInput) {
            ReviewInputView(
                locationName: location.name, 
                userNickname: $userNickname,
                existingReview: reviewManager.existingReview
            ) { reportType, rating, content, nickname, tags, ratingDetails, gender in
                // 儲存暱稱到 UserDefaults
                userNickname = nickname
                UserDefaults.standard.set(nickname, forKey: "UserNickname")
                
                // 只在暱稱改變時更新 UserProfile，但保持原有的性別設定
                if let currentProfile = CloudKitManager.shared.currentUserProfile {
                    // 如果已有 Profile，只更新暱稱，性別保持不變
                    if currentProfile.nickname != nickname {
                        CloudKitManager.shared.saveUserProfile(nickname: nickname, gender: currentProfile.gender) { _ in }
                    }
                } else {
                    // 如果沒有 Profile，創建一個（使用預設性別）
                    CloudKitManager.shared.saveUserProfile(nickname: nickname, gender: .secret) { _ in }
                }
                
                // 新增評論
                // 關鍵修正：使用 CloudKit User ID 而非設備 ID
                let userId = CloudKitManager.shared.currentUserID?.recordName ?? "Unknown"
                var newReview = LocationReport(
                    id: UUID(),
                    locationId: location.id,
                    type: reportType,
                    rating: rating, // 使用使用者點的星星數
                    content: content.isEmpty ? nil : content,
                    time: Date(),
                    userNickname: nickname,
                    userId: userId, // 使用 CloudKit User ID
                    tags: tags,
                    ratingDetails: ratingDetails,
                    userGender: gender, // 直接傳入性別
                    locationName: location.name,
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                
                withAnimation {
                    reviewManager.addReview(newReview)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground {
                if #available(iOS 26.0, *) {
                    Color.white.opacity(0.5)
                } else {
                    ZStack {
                        Color.clear
                            .background(.thinMaterial)
                        Color.white.opacity(0.55)
                    }
                }
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { reviewManager.errorMessage != nil },
            set: { if !$0 { reviewManager.errorMessage = nil } }
        )) {
            Alert(
                title: Text("無法上傳評論"),
                message: Text(reviewManager.errorMessage ?? ""),
                dismissButton: .default(Text("好"))
            )
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

// MARK: - 社群評論區組件

struct CommunityReviewSection: View {
    let locationName: String
    let reviews: [LocationReport]
    let hasExistingReview: Bool // 新增：使用者是否已留言
    let onAddReview: () -> Void
    @State private var showingAllReviews: Bool = false // 控制顯示所有評論的 sheet
    
    // 固定只顯示最新3筆
    private var displayedReviews: [LocationReport] {
        return Array(reviews.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題與箭頭按鈕
            // 只有超過3筆評論時，整個標題區域才可點擊
            if reviews.count > 3 {
                Button(action: {
                    showingAllReviews = true
                }) {
                    HStack {
                        HStack(spacing: 8) {
                            Text("評論")
                                .font(.title3Rounded(.bold))
                                .foregroundColor(.primary)
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadlineRounded(.semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle()) // 確保整個區域都可點擊
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // 評論少於等於3筆時，只顯示標題不可點擊
                HStack {
                    Text("評論")
                        .font(.title3Rounded(.bold))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            if reviews.isEmpty {
                // 無評論狀態
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("還沒有人評論過，成為第一個吧！")
                        .font(.subheadlineRounded())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20) // 縮小內部垂直間距 (原 30)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(16)
                .padding(.horizontal, 20)
            } else {
                // 評論列表（固定顯示最新3筆）
                VStack(spacing: 16) {
                    ForEach(displayedReviews) { review in
                        ReviewRow(review: review)
                        
                        if review.id != displayedReviews.last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showingAllReviews) {
            AllReviewsSheet(locationName: locationName, reviews: reviews, hasExistingReview: hasExistingReview, onAddReview: onAddReview)
        }
    }
}

struct ReviewRow: View {
    let review: LocationReport
    
    // 計算顯示的顏色
    private var genderColor: Color {
        if let gender = review.userGender {
            return gender.color
        }
        // 如果沒有性別資訊，預設灰色
        return .gray
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 頭像 - 根據性別顯示顏色
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "person.fill")
                    .foregroundColor(genderColor)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(review.userNickname)
                        .font(.subheadline.bold())
                    
                    Spacer()
                    Text(timeAgoDisplay(date: review.time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: "star.fill") // 全部都用實心星星
                            .font(.caption2)
                            .foregroundColor(index < review.rating ? .yellow : Color.gray.opacity(0.2))
                    }
                }
                
                // 顯示標籤 (問題列表) - 灰色圖示+文字
                if !review.tags.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(review.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }
                
                // 顯示詳細評分 (用圖示而非彩色背景)
                if !review.ratingDetails.isEmpty {
                    HStack(spacing: 8) {
                        if let cleanliness = review.ratingDetails["cleanliness"] {
                            HStack(spacing: 2) {
                                Image(systemName: cleanliness == 1 ? "hand.thumbsup" : "hand.thumbsdown")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("乾淨")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let convenience = review.ratingDetails["convenience"] {
                            HStack(spacing: 2) {
                                Image(systemName: convenience == 1 ? "hand.thumbsup" : "hand.thumbsdown")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("方便")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let crowd = review.ratingDetails["crowd"] {
                            HStack(spacing: 2) {
                                Image(systemName: "person.2")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(crowd == 1 ? "人少" : "人多")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                if let content = review.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
            }
        }
    }
    
    private func timeAgoDisplay(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 所有評論 Sheet

struct AllReviewsSheet: View {
    let locationName: String
    let reviews: [LocationReport]
    let hasExistingReview: Bool // 新增：使用者是否已留言
    let onAddReview: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // 排序狀態
    @State private var sortOption: SortOption = .newest
    
    enum SortOption: String, CaseIterable {
        case newest = "最新"
        case oldest = "最舊"
        case highestRating = "評分最高"
        case lowestRating = "評分最低"
    }
    
    // 計算平均評分
    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let sum = reviews.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(reviews.count)
    }
    
    // 計算每個星級的數量
    private func countForStars(_ starCount: Int) -> Int {
        return reviews.filter { $0.rating == starCount }.count
    }
    
    // 計算每個星級的百分比
    private func percentageForStars(_ starCount: Int) -> Double {
        guard !reviews.isEmpty else { return 0 }
        let count = countForStars(starCount)
        return Double(count) / Double(reviews.count)
    }
    
    // 排序後的評論
    private var sortedReviews: [LocationReport] {
        switch sortOption {
        case .newest:
            return reviews.sorted { $0.time > $1.time }
        case .oldest:
            return reviews.sorted { $0.time < $1.time }
        case .highestRating:
            return reviews.sorted { $0.rating > $1.rating }
        case .lowestRating:
            return reviews.sorted { $0.rating < $1.rating }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 評分統計卡片
                    HStack(alignment: .top, spacing: 24) {
                        // 左側：評分數字和星星
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%.1f", averageRating))
                                .font(.customRounded(40, weight: .bold))
                                .foregroundColor(.primary)
                            
                            // 星星顯示
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { index in
                                    let starFill = getStarFillAmount(for: index, average: averageRating)
                                    ZStack {
                                        // 背景空星
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(Color.gray.opacity(0.15))
                                        
                                        // 實心部分
                                        if starFill > 0 {
                                            GeometryReader { geometry in
                                                Image(systemName: "star.fill")
                                                    .font(.caption)
                                                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
                                                    .mask(
                                                        Rectangle()
                                                            .size(width: geometry.size.width * starFill, height: geometry.size.height)
                                                    )
                                            }
                                        }
                                    }
                                    .frame(width: 16, height: 16)
                                }
                            }
                            
                            Text("(\(reviews.count))")
                                .font(.subheadlineRounded())
                                .foregroundColor(.secondary)
                        }
                        
                        // 右側：星級分布條形圖
                        VStack(spacing: 0) {
                            ForEach((1...5).reversed(), id: \.self) { starLevel in
                                // 條形圖
                                ZStack(alignment: .leading) {
                                    // 背景條
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.15))
                                    
                                    // 填充條
                                    GeometryReader { geometry in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(red: 1.0, green: 0.8, blue: 0.0))
                                            .frame(width: geometry.size.width * percentageForStars(starLevel))
                                    }
                                }
                                .frame(height: 10)
                                
                                if starLevel > 1 {
                                    Spacer()
                                        .frame(height: 4)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    // 排序菜單
                    HStack {
                        Text("所有評論")
                            .font(.title3Rounded(.bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if #available(iOS 26.0, *) {
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        sortOption = option
                                    }) {
                                        HStack {
                                            Text(option.rawValue)
                                            if sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(sortOption.rawValue)
                                        .font(.subheadlineRounded(.semibold))
                                        .foregroundColor(Color.black.opacity(0.8))
                                        .frame(minWidth: 55, alignment: .center)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(Color.black.opacity(0.8))
                                }
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.clear)
                        } else {
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        sortOption = option
                                    }) {
                                        HStack {
                                            Text(option.rawValue)
                                            if sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(sortOption.rawValue)
                                        .font(.subheadlineRounded(.semibold))
                                        .foregroundColor(.primary)
                                        .frame(minWidth: 55, alignment: .center)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // 評論列表
                    VStack(spacing: 16) {
                        ForEach(sortedReviews) { review in
                            ReviewRow(review: review)
                                .padding(.horizontal, 20)
                            
                            if review.id != sortedReviews.last?.id {
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(locationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(action: {
                            dismiss()
                            onAddReview()
                        }) {
                            Image(systemName: hasExistingReview ? "pencil" : "plus.message.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.orange)
                    } else {
                        Button(action: {
                            dismiss()
                            onAddReview()
                        }) {
                            Image(systemName: hasExistingReview ? "pencil" : "plus.message.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
    }
    
    // 計算每顆星星的填充量（支持半星）
    private func getStarFillAmount(for starIndex: Int, average: Double) -> CGFloat {
        if average >= Double(starIndex) {
            return 1.0 // 完全填充
        } else if average > Double(starIndex - 1) {
            return CGFloat(average - Double(starIndex - 1)) // 部分填充
        } else {
            return 0.0 // 不填充
        }
    }
}

// MARK: - 評論輸入視窗

struct ReviewInputView: View {
    let locationName: String
    @Binding var userNickname: String
    let existingReview: LocationReport? // 新增：如果有值代表是編輯模式
    // 更新：加上 rating 參數 (星星數) 和 性別
    let onSubmit: (LocationReport.ReportType, Int, String, String, [String], [String: Int], UserGender) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // 評分維度狀態
    @State private var starRating: Int = 0 // 改為星星評分 (0-5，0代表未評)
    @State private var ratingCleanliness: Bool? = nil
    @State private var ratingConvenience: Bool? = nil
    @State private var ratingCrowd: Bool? = nil // true = 人少(好), false = 人多(壞)
    
    // 負面狀況多選
    @State private var selectedIssues: Set<String> = []
    
    @State private var comment: String = ""
    
    // 性別與 Profile 相關
    @State private var gender: UserGender = .secret
    @State private var isLoadingProfile = true
    @State private var showingNameInputAlert = false // 控制暱稱輸入彈窗
    
    let issueTags = ["缺衛生紙", "髒亂異味", "設備損壞", "維修中", "地面濕滑", "馬桶堵塞", "照明不足"]
    
    // 是否為編輯模式
    private var isEditMode: Bool {
        existingReview != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // 1. 性別選擇 (用於頭像顏色)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("性別")
                            .font(.headline)
                        
                        Picker("性別", selection: $gender) {
                            ForEach(UserGender.allCases) { gender in
                                Text(gender.title).tag(gender)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(gender.color)
                    }
                    .padding(.horizontal, 20)
                    
                    // 2. 整體評價 (星星評分)
                    VStack(spacing: 12) {
                        HStack {
                            Text("整體評價")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // 5 顆星星可點選
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { index in
                                    Button(action: {
                                        starRating = index
                                    }) {
                                        Image(systemName: "star.fill") // 全部都用實心星星
                                            .font(.title3)
                                            .foregroundColor(index <= starRating ? .yellow : Color.gray.opacity(0.2)) // 未選中用淺灰色
                                    }
                                    .animation(.none, value: starRating) // 禁用動畫，直接切換顏色
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                        
                        // 3. 其他維度評分
                        VStack(spacing: 12) {
                            RatingRow(title: "乾淨度", selection: $ratingCleanliness)
                            Divider()
                            RatingRow(title: "方便度", selection: $ratingConvenience)
                            Divider()
                            RatingRow(title: "人潮狀況", selection: $ratingCrowd, positiveText: "少", negativeText: "多")
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    
                    // 4. 負面狀況回報 (多選, 橫向捲動)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("回報問題")
                            .font(.headline)
                            .padding(.horizontal, 20) // 標題保留 padding
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(issueTags, id: \.self) { tag in
                                    let isSelected = selectedIssues.contains(tag)
                                    Button(action: {
                                        var transaction = Transaction(animation: .none)
                                        transaction.disablesAnimations = true
                                        withTransaction(transaction) {
                                            if isSelected {
                                                selectedIssues.remove(tag)
                                            } else {
                                                selectedIssues.insert(tag)
                                            }
                                        }
                                    }) {
                                        Text(tag)
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .foregroundColor(isSelected ? .red : .primary)
                                            .background(isSelected ? Color.red.opacity(0.2) : Color.gray.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 20) // 內容內縮 padding
                        }
                        // 移除遮罩與 ZStack
                    }
                    
                    // 5. 留言輸入
                    VStack(alignment: .leading, spacing: 12) {
                        Text("留言")
                            .font(.headline)
                        
                        TextField("分享你的使用經驗", text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20) // 補回 padding
                    
                    Spacer()
                }
                .padding(.vertical, 20) // 移除水平 padding，只保留垂直
                .frame(maxWidth: .infinity) // 確保點擊區域涵蓋全寬
                .contentShape(Rectangle()) // 讓空白區域也可點擊
                .onTapGesture {
                    // 點擊空白處關閉鍵盤，不影響 Scroll位置
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .scrollDismissesKeyboard(.interactively) // 滑動時關閉鍵盤
            .navigationTitle(isEditMode ? "修改評論" : "撰寫評論")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    let submitButton = Button(isEditMode ? "更新" : "送出") {
                        if userNickname.isEmpty {
                            // 如果沒暱稱，跳出輸入框
                            showingNameInputAlert = true
                        } else {
                            // 有暱稱直接送出
                            handleSubmit()
                        }
                    }
                    
                    if #available(iOS 26.0, *) {
                        submitButton
                            .buttonStyle(.glassProminent)
                            .tint(.blue)
                            .disabled(starRating == 0) // 移除 userNickname.isEmpty 檢查，改為點擊後檢查
                    } else {
                        submitButton
                            .fontWeight(.bold)
                            .foregroundColor(starRating == 0 ? .gray : .blue)
                            .disabled(starRating == 0)
                    }
                }
            }
            .alert("請設定暱稱", isPresented: $showingNameInputAlert) {
                TextField("輸入您的暱稱", text: $userNickname)
                Button("確定", action: handleSubmit)
                Button("取消", role: .cancel) { }
            } message: {
                Text("第一次留言請設定暱稱，之後可至「設定」頁面修改。")
            }
        }
        .onAppear {
            // 嘗試載入現有的個人檔案
            loadUserProfile()
            // 如果是編輯模式，預填現有評論內容
            if let existing = existingReview {
                loadExistingReviewData(existing)
            }
        }
    }
    
    private func loadUserProfile() {
        if let profile = CloudKitManager.shared.currentUserProfile {
            // 如果已經有載入過的 Profile，直接使用
            self.userNickname = profile.nickname
            self.gender = profile.gender
            self.isLoadingProfile = false
        } else {
            // 否則，使用 UserDefaults 裡的暱稱 (相容舊版)
            // 性別預設為不透露
        }
    }
    
    // 載入現有評論資料
    private func loadExistingReviewData(_ review: LocationReport) {
        // 評分
        self.starRating = review.rating
        
        // 問題標籤
        self.selectedIssues = Set(review.tags)
        
        // 留言內容
        self.comment = review.content ?? ""
        
        // 詳細評分
        if let cleanliness = review.ratingDetails["cleanliness"] {
            self.ratingCleanliness = cleanliness == 1
        }
        if let convenience = review.ratingDetails["convenience"] {
            self.ratingConvenience = convenience == 1
        }
        if let crowd = review.ratingDetails["crowd"] {
            self.ratingCrowd = crowd == 1
        }
        
        // 性別
        if let reviewGender = review.userGender {
            self.gender = reviewGender
        }
        
        print("✏️ [編輯模式] 已載入現有評論資料")
    }
    
    // 處理送出邏輯
    private func handleSubmit() {
        let finalNickname = userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalNickname.isEmpty { return } // 理論上被 disabled 擋住了
        
        // 注意：這裡不更新性別到資料庫，只用於本次評論
        // 只有在設定頁面修改性別時才會更新到資料庫
        
        // 準備評論資料
        
        // 決定主要類型 (ReportType)
        // 根據星星數和選中的問題標籤來決定
        let finalType: LocationReport.ReportType
        if !selectedIssues.isEmpty {
            if selectedIssues.contains("缺衛生紙") { finalType = .noPaper }
            else if selectedIssues.contains("維修中") || selectedIssues.contains("設備損壞") { finalType = .maintenance }
            else if selectedIssues.contains("人潮擁擠") { finalType = .crowded }
            else { finalType = .dirty } // 其他問題歸類為髒亂/問題
        } else {
            // 沒選問題，看星星數
            if starRating >= 4 {
                finalType = .clean // 4-5星視為好評
            } else if starRating >= 3 {
                finalType = .normal // 3星視為普通
            } else {
                finalType = .dirty // 1-2星視為差評
            }
        }
        
        // 收集詳細評分
        var details: [String: Int] = [:]
        if let r = ratingCleanliness { details["cleanliness"] = r ? 1 : 0 }
        if let r = ratingConvenience { details["convenience"] = r ? 1 : 0 }
        if let r = ratingCrowd { details["crowd"] = r ? 1 : 0 } // 1=少(好), 0=多(壞)
        
        // 更新：加上星星數參數
        onSubmit(finalType, starRating, comment.trimmingCharacters(in: .whitespacesAndNewlines), finalNickname, Array(selectedIssues), details, gender)
        dismiss()
    }
}


// 評分列組件
struct RatingRow: View {
    let title: String
    @Binding var selection: Bool?
    var positiveText: String? = nil // 如果有值，顯示文字而非圖示
    var negativeText: String? = nil
    
    // 動畫狀態
    @State private var isThumbsUpAnimating = false
    @State private var isThumbsDownAnimating = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                // 正評按鈕 (左邊) - 文字模式或圖示模式
                if let posText = positiveText {
                    // 文字模式 (人少，對應 true/讚)
                    Button(action: {
                        selection = true
                    }) {
                        Text(posText)
                            .font(.subheadline.bold())
                            .foregroundColor(selection == true ? .white : .gray)
                            .frame(width: 36, height: 36) // 改為正方形，與圖示按鈕一致
                            .background(selection == true ? Color.blue : Color.gray.opacity(0.15))
                            .clipShape(Circle()) // 改為圓形
                            .animation(.none, value: selection) // 禁用所有動畫
                    }
                } else {
                    // 圖示模式 (👍) - 分離背景和 Icon
                    Button(action: {
                        selection = true
                        
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                            isThumbsUpAnimating = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                                isThumbsUpAnimating = false
                            }
                        }
                    }) {
                        ZStack {
                            // 背景圓圈（不旋轉）
                            Circle()
                                .fill(selection == true ? Color.blue : Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .animation(.none, value: selection) // 禁用顏色動畫
                            
                            // Icon（會旋轉）
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 16))
                                .foregroundColor(selection == true ? .white : .gray)
                                .rotationEffect(.degrees(isThumbsUpAnimating ? -20 : 0), anchor: .bottomLeading)
                                .animation(.none, value: selection) // 禁用顏色動畫
                        }
                    }
                }
                
                // 負評按鈕 (右邊) - 文字模式或圖示模式
                if let negText = negativeText {
                    // 文字模式 (人多，對應 false/倒讚)
                    Button(action: {
                        selection = false
                    }) {
                        Text(negText)
                            .font(.subheadline.bold())
                            .foregroundColor(selection == false ? .white : .gray)
                            .frame(width: 36, height: 36) // 改為正方形
                            .background(selection == false ? Color.red : Color.gray.opacity(0.15))
                            .clipShape(Circle()) // 改為圓形
                            .animation(.none, value: selection) // 禁用所有動畫
                    }
                } else {
                    // 圖示模式 (👎) - 分離背景和 Icon
                    Button(action: {
                        selection = false
                        
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                            isThumbsDownAnimating = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                                isThumbsDownAnimating = false
                            }
                        }
                    }) {
                        ZStack {
                            // 背景圓圈（不旋轉）
                            Circle()
                                .fill(selection == false ? Color.red : Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .animation(.none, value: selection) // 禁用顏色動畫
                            
                            // Icon（會旋轉）
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.system(size: 16))
                                .foregroundColor(selection == false ? .white : .gray)
                                .rotationEffect(.degrees(isThumbsDownAnimating ? 20 : 0), anchor: .topTrailing)
                                .animation(.none, value: selection) // 禁用顏色動畫
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    LocationDetailView(
        location: ToiletLocation(
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
        ),
        locationDetailDetent: .constant(.medium)
    )
}
