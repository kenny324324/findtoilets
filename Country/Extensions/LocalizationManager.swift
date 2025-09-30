//
//  LocalizationManager.swift
//  Country
//
//  Created by AI Assistant on 2024/09/16.
//

import Foundation

/// 本地化管理器 - 使用系統本地化
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    private init() {
        // 不需要手動管理語言，使用系統本地化
    }
    
    /// 獲取本地化字串
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        
        if arguments.isEmpty {
            return localizedString
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }
}

/// 本地化字串擴展
extension String {
    /// 本地化字串
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    /// 帶參數的本地化字串
    func localized(_ arguments: CVarArg...) -> String {
        return LocalizationManager.shared.localizedString(for: self, arguments: arguments)
    }
}

/// 常用本地化字串常數
struct LocalizedStrings {
    // MARK: - 主要功能
    static let appTitle = "app_title"
    static let searchPlaceholder = "search_placeholder"
    static let locationPermissionRequired = "location_permission_required"
    static let locationPermissionDescription = "location_permission_description"
    static let goToSettings = "go_to_settings"
    static let noToiletsFound = "no_toilets_found"
    static let loadingToilets = "loading_toilets"
    static let locating = "locating"
    static let needLocationForNearby = "need_location_for_nearby"
    static let pressLocationButton = "press_location_button"
    
    // MARK: - 設定頁面
    static let settings = "settings"
    static let locationPermission = "location_permission"
    static let locationPermissionDetail = "location_permission_detail"
    static let notificationSettings = "notification_settings"
    static let notificationDetail = "notification_detail"
    static let aboutApp = "about_app"
    static let version = "version"
    static let done = "done"
    
    // MARK: - 廁所類型
    static let toiletTypeFemale = "toilet_type_female"
    static let toiletTypeMale = "toilet_type_male"
    static let toiletTypeFamily = "toilet_type_family"
    static let toiletTypeAccessible = "toilet_type_accessible"
    static let toiletTypeUniversal = "toilet_type_universal"
    static let toiletTypeMixed = "toilet_type_mixed"
    static let toiletTypeGenderFriendly = "toilet_type_gender_friendly"
    
    // MARK: - 廁所等級
    static let gradeExcellent = "grade_excellent"
    static let gradeGood = "grade_good"
    static let gradeFair = "grade_fair"
    static let gradeNormal = "grade_normal"
    static let gradePoor = "grade_poor"
    
    // MARK: - 場所類型
    static let venueTypeCommercial = "venue_type_commercial"
    static let venueTypeTransportation = "venue_type_transportation"
    static let venueTypeTourism = "venue_type_tourism"
    static let venueTypeReligious = "venue_type_religious"
    static let venueTypeGovernment = "venue_type_government"
    static let venueTypeEducation = "venue_type_education"
    static let venueTypeHealthcare = "venue_type_healthcare"
    
    // MARK: - 地點詳情
    static let toiletCount = "toilet_count"
    static let floorCount = "floor_count"
    static let calculating = "calculating"
    static let selectFloor = "select_floor"
    static let availableTypes = "available_types"
    static let details = "details"
    static let address = "address"
    static let diaperStation = "diaper_station"
    static let venueType = "venue_type"
    static let administration = "administration"
    
    // MARK: - 地圖功能
    static let mapAppSelection = "map_app_selection"
    static let mapSelectionDescription = "map_selection_description"
    static let cancel = "cancel"
    
    // MARK: - 時間相關
    static let minutes = "minutes"
    static let hours = "hours"
    static let hoursMinutes = "hours_minutes"
    static let days = "days"
    static let daysHours = "days_hours"
    static let daysHoursMinutes = "days_hours_minutes"
    
    // MARK: - 錯誤訊息
    static let locationTimeout = "location_timeout"
    static let locationFailed = "location_failed"
    static let dataLoadFailed = "data_load_failed"
    static let fileNotFound = "file_not_found"
}
