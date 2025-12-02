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
    let time: Date
    let userId: String // 匿名 ID
    let userNickname: String // 匿名暱稱
    
    init(locationId: UUID, type: ReportType, rating: Int, content: String? = nil, userNickname: String) {
        self.id = UUID()
        self.locationId = locationId
        self.type = type
        self.rating = rating
        self.content = content
        self.time = Date()
        self.userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.userNickname = userNickname
    }
    
    // 用於假資料
    init(id: UUID = UUID(), locationId: UUID = UUID(), type: ReportType, rating: Int, content: String? = nil, time: Date, userNickname: String) {
        self.id = id
        self.locationId = locationId
        self.type = type
        self.rating = rating
        self.content = content
        self.time = time
        self.userId = "dummy_user"
        self.userNickname = userNickname
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

// 評論管理器 (模擬後端)
class ReviewManager: ObservableObject {
    @Published var reviews: [UUID: [LocationReport]] = [:] // locationId -> reports
    
    init() {
        // 載入一些假資料
        loadDummyData()
    }
    
    func addReview(_ report: LocationReport) {
        if reviews[report.locationId] == nil {
            reviews[report.locationId] = []
        }
        reviews[report.locationId]?.insert(report, at: 0)
    }
    
    func getReviews(for locationId: UUID) -> [LocationReport] {
        return reviews[locationId] ?? []
    }
    
    private func loadDummyData() {
        // 這裡之後可以接真實 API
    }
}

struct LocationDetailView: View {
    let location: ToiletLocation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var reviewManager = ReviewManager() // 引入評論管理器
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
                        
                        // 導航與回報按鈕區域
                        HStack(spacing: 12) {
                            // 1. 導航按鈕
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
                                .frame(height: 56)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            // 2. 回報按鈕 (舊版) -> 改為快速評分入口
                            Button(action: { showingReviewInput = true }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "star.bubble.fill")
                                        .font(.subheadlineRounded())
                                        .foregroundColor(.white)
                                        .frame(width: 16, height: 16)
                                    
                                    Text("評論打分")
                                        .font(.captionRounded(.semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                        reviews: reviewManager.getReviews(for: location.id),
                        onAddReview: { showingReviewInput = true }
                    )
                    .padding(.bottom, 20) // 縮小外部底部間距 (原 40)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(locationDetailDetent == .height(200)) // 最小高度時禁用滾動
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 如果當前是最小高度，返回時調整到中高度
                        if locationDetailDetent == .height(200) {
                            locationDetailDetent = .medium
                        }
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .background(Color.clear)
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
        // 評論輸入 Sheet
        .sheet(isPresented: $showingReviewInput) {
            ReviewInputView(locationName: location.name, userNickname: $userNickname) { reportType, content, nickname in
                // 儲存暱稱
                userNickname = nickname
                UserDefaults.standard.set(nickname, forKey: "UserNickname")
                
                // 新增評論
                let newReview = LocationReport(
                    locationId: location.id,
                    type: reportType,
                    rating: reportType.defaultRating,
                    content: content.isEmpty ? nil : content,
                    userNickname: nickname
                )
                
                withAnimation {
                    reviewManager.addReview(newReview)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.white.opacity(0.5))
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
    let reviews: [LocationReport]
    let onAddReview: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題與新增按鈕
            HStack {
                Text("社群評論")
                    .font(.title3Rounded(.bold))
                
                Spacer()
                
                Button(action: onAddReview) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.bubble")
                        Text("撰寫評論")
                    }
                    .font(.subheadlineRounded(.semibold))
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            
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
                // 評論列表
                VStack(spacing: 16) {
                    ForEach(reviews) { review in
                        ReviewRow(review: review)
                        
                        if review.id != reviews.last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ReviewRow: View {
    let review: LocationReport
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 頭像 (使用狀態圖示)
            ZStack {
                Circle()
                    .fill(review.type.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: review.type.icon)
                    .foregroundColor(review.type.color)
                    .font(.system(size: 18))
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
                        Image(systemName: index < review.rating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(index < review.rating ? .yellow : .gray.opacity(0.3))
                    }
                    
                    Text("• \(review.type.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let content = review.content {
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

// MARK: - 評論輸入視窗

struct ReviewInputView: View {
    let locationName: String
    @Binding var userNickname: String
    let onSubmit: (LocationReport.ReportType, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // 評分維度狀態 (true = 👍, false = 👎, nil = 未評)
    @State private var ratingOverall: Bool? = nil
    @State private var ratingCleanliness: Bool? = nil
    @State private var ratingConvenience: Bool? = nil
    @State private var ratingCrowd: Bool? = nil // true = 人少(好), false = 人多(壞)
    
    // 負面狀況多選
    @State private var selectedIssues: Set<String> = []
    
    @State private var comment: String = ""
    
    let issueTags = ["缺衛生紙", "髒亂異味", "設備損壞", "維修中", "地面濕滑", "馬桶堵塞", "照明不足"]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // 1. 多維度評分區塊
                    VStack(spacing: 12) { // 縮小垂直間距 (原 20)
                        RatingRow(title: "整體評價", selection: $ratingOverall)
                        Divider()
                        RatingRow(title: "乾淨度", selection: $ratingCleanliness)
                        Divider()
                        RatingRow(title: "方便度", selection: $ratingConvenience)
                        Divider()
                        RatingRow(title: "人潮狀況", selection: $ratingCrowd, positiveText: "少", negativeText: "多")
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal, 20) // 補回 padding
                    
                    // 2. 負面狀況回報 (多選, 橫向捲動)
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
                    
                    // 3. 留言輸入
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
                    
                    // 4. 暱稱設定
                    VStack(alignment: .leading, spacing: 12) {
                        Text("您的暱稱")
                            .font(.headline)
                        
                        TextField("暱稱", text: $userNickname)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20) // 補回 padding
                    
                    Spacer()
                }
                .padding(.vertical, 20) // 移除水平 padding，只保留垂直
                // 原本 .padding(20) 改為 .padding(.vertical, 20)
                .frame(maxWidth: .infinity) // 確保點擊區域涵蓋全寬
                .contentShape(Rectangle()) // 讓空白區域也可點擊
                .onTapGesture {
                    // 點擊空白處關閉鍵盤，不影響 Scroll位置
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .scrollDismissesKeyboard(.interactively) // 滑動時關閉鍵盤
            .navigationTitle("撰寫評論")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    let submitButton = Button("送出") {
                        handleSubmit()
                    }
                    
                    if #available(iOS 26.0, *) {
                        submitButton
                            .buttonStyle(.glassProminent)
                            .tint(.blue)
                            .disabled(ratingOverall == nil)
                    } else {
                        submitButton
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ratingOverall == nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .disabled(ratingOverall == nil)
                    }
                }
            }
        }
    }
    
    // 處理送出邏輯
    private func handleSubmit() {
        if userNickname.isEmpty { userNickname = "熱心路人" }
        
        // 決定主要類型 (ReportType)
        // 邏輯：如果有選負面標籤，優先顯示負面類型；否則根據整體評價決定
        let finalType: LocationReport.ReportType
        if !selectedIssues.isEmpty {
            if selectedIssues.contains("缺衛生紙") { finalType = .noPaper }
            else if selectedIssues.contains("維修中") || selectedIssues.contains("設備損壞") { finalType = .maintenance }
            else if selectedIssues.contains("人潮擁擠") { finalType = .crowded }
            else { finalType = .dirty } // 其他問題歸類為髒亂/問題
        } else {
            // 沒選問題，看整體評價
            if ratingOverall == true {
                finalType = .clean // 好評預設
            } else {
                finalType = .normal // 差評但沒說原因，暫歸普通或待改善
            }
        }
        
        // 組合詳細評分內容到 comment 中 (因為目前 Model 沒欄位存)
        var details = ""
        if let r = ratingCleanliness { details += "乾淨度:\(r ? "👍" : "👎") " }
        if let r = ratingConvenience { details += "方便度:\(r ? "👍" : "👎") " }
        if let r = ratingCrowd { details += "人潮:\(r ? "少" : "多") " }
        if !selectedIssues.isEmpty { details += "\n問題: " + selectedIssues.joined(separator: ", ") }
        
        let finalComment = (comment.isEmpty ? "" : comment + "\n") + details
        
        onSubmit(finalType, finalComment.trimmingCharacters(in: .whitespacesAndNewlines), userNickname)
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
