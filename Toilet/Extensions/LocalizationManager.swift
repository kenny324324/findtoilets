//
//  LocalizationManager.swift
//  Toilet
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
    static let nearbyToiletsTitle = "nearby_toilets_title"
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
    static let language = "language"
    static let languageSetting = "language_setting"
    static let languageSettingDetail = "language_setting_detail"
    static let done = "done"
    static let profile = "profile"
    static let nickname = "nickname"
    static let notSet = "not_set"
    static let edit = "edit"
    static let gender = "gender"
    static let modifyNickname = "modify_nickname"
    static let enterNickname = "enter_nickname"
    static let confirm = "confirm"
    static let cancel = "cancel"
    static let nicknameNotice = "nickname_notice"
    static let setNicknameAlert = "set_nickname_alert"
    static let firstTimeNicknameNotice = "first_time_nickname_notice"
    
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
    
    // MARK: - 評論與回報
    static let reviews = "reviews"
    static let noReviewsYet = "no_reviews_yet"
    static let writeReview = "write_review"
    static let editReview = "edit_review"
    static let update = "update"
    static let submit = "submit"
    static let overallRating = "overall_rating"
    static let cleanliness = "cleanliness"
    static let convenience = "convenience"
    static let crowdStatus = "crowd_status"
    static let reportIssue = "report_issue"
    static let comment = "comment"
    static let shareExperience = "share_experience"
    static let fewPeople = "few_people"
    static let manyPeople = "many_people"
    static let clean = "clean"
    static let convenient = "convenient"
    
    // MARK: - 問題標籤
    static let issueNoPaper = "issue_no_paper"
    static let issueDirty = "issue_dirty"
    static let issueDamaged = "issue_damaged"
    static let issueMaintenance = "issue_maintenance"
    static let issueWetFloor = "issue_wet_floor"
    static let issueClogged = "issue_clogged"
    static let issueDimLight = "issue_dim_light"
    static let issueCrowded = "issue_crowded"
    
    // MARK: - 篩選與搜尋
    static let nearby = "nearby"
    static let nearbyOneKm = "nearby_one_km"
    static let filter = "filter"
    static let distanceRange = "distance_range"
    static let starRating = "star_rating"
    static let noLimit = "no_limit"
    static let lessThanMeters = "less_than_meters"
    static let clear = "clear"
    static let apply = "apply"
    static let noFilterResults = "no_filter_results"
    static let clearFilterConditions = "clear_filter_conditions"
    static let recentlyViewed = "recently_viewed"
    static let noRecentlyViewed = "no_recently_viewed"
    static let sortDistance = "sort_distance"
    static let sortRating = "sort_rating"
    static let allReviews = "all_reviews"
}
